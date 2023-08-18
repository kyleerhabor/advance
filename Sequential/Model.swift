//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import ImageIO
import OSLog
import SwiftUI

enum ImageError: Error {
  case undecodable
}

// For some reason, conforming to Transferable and declaring the support for UTType.image is not enough to support .dropDestination(...)
struct SeqImage {
  let id: UUID
  var url: URL
  var width: Double
  var height: Double
}

struct SeqResolvedBookmark {
  let url: URL
  let stale: Bool
}

struct SeqBookmark: Codable, Hashable {
  let id: UUID
  var data: Data
  var url: URL?
  var width: Double?
  var height: Double?

  init(
    id: UUID = .init(),
    data: Data,
    url: URL? = nil,
    width: Double? = nil,
    height: Double? = nil
  ) {
    self.id = id
    self.data = data
    self.url = url
    self.width = width
    self.height = height
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(data: try container.decode(Data.self, forKey: .data))
  }

  func resolved() throws -> SeqResolvedBookmark {
    var stale = false
    let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)

    return .init(url: url, stale: stale)
  }

  func resolve() throws -> Self {
    var this = self
    var resolved = try this.resolved()

    if resolved.stale {
      let url = resolved.url
      this.data = try url.scoped { try url.bookmark() }
      resolved = try this.resolved()
    }

    this.url = resolved.url

    return this
  }

  func image() throws -> Self? {
    guard let url else {
      return nil
    }

    return try url.scoped {
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        return nil
      }

      let index = CGImageSourceGetPrimaryImageIndex(source)

      guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? Dictionary<CFString, Any> else {
        return nil
      }

      var this = self
      this.width = Double(properties[kCGImagePropertyPixelWidth] as! Int)
      this.height = Double(properties[kCGImagePropertyPixelHeight] as! Int)

      return this
    }
  }

  enum CodingKeys: CodingKey {
    case data
  }
}

@Observable
class Seq: Codable {
  var images = [SeqImage]()
  var bookmarks: [SeqBookmark]

  init(urls: [URL]) throws {
    self.bookmarks = try urls.map { url in
      .init(data: try url.bookmark())
    }
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.bookmarks = try container.decode([SeqBookmark].self, forKey: .bookmarks)
  }

  func update() {
    images = bookmarks.compactMap { bookmark in
      guard let url = bookmark.url,
            let width = bookmark.width,
            let height = bookmark.height else {
        return nil
      }

      return .init(
        id: bookmark.id,
        url: url,
        width: width,
        height: height
      )
    }
  }

  func store(bookmarks: [SeqBookmark]) {
    let index = self.bookmarks.enumerated().reduce(into: [:]) { partialResult, pair in
      partialResult[pair.1.id] = pair.0
    }

    bookmarks.forEach { bookmark in
      guard let key = index[bookmark.id] else {
        self.bookmarks.append(bookmark)

        return
      }

      self.bookmarks[key] = bookmark
    }

    update()
  }

  func store(bookmarks: [SeqBookmark], at offset: Int) {
    self.bookmarks.insert(contentsOf: bookmarks, at: offset)

    // We could speed this up with some indexes (I just don't want to think about it right now).
    self.bookmarks = self.bookmarks.filter { bookmark in
      !bookmarks.contains { $0.url == bookmark.url && $0.id != bookmark.id }
    }

    update()
  }

  func load() async -> [SeqBookmark] {
    var bookmarks = [SeqBookmark]()

    await self.bookmarks.forEach(concurrently: 8) { bookmark in
      do {
        guard let bookmark = try bookmark.resolve().image() else {
          return
        }

        bookmarks.append(bookmark)
      } catch {
        Logger.model.info("Could not resolve bookmark \"\(bookmark.data)\": \(error)")
      }
    }

    return bookmarks.ordered(\.id, by: self.bookmarks)
  }

  func move(from source: IndexSet, to destination: Int) {
    bookmarks.move(fromOffsets: source, toOffset: destination)
    update()
  }

  func inserted(url: URL) throws -> SeqBookmark? {
    let data = try url.bookmark()

    return try SeqBookmark(data: data).resolve().image()
  }

  func insert(_ urls: [URL], scoped: Bool) async -> [SeqBookmark] {
    var bookmarks = [SeqBookmark]()

    do {
      bookmarks = try urls.compactMap { url in
        try if scoped {
          url.scoped { try inserted(url: url) }
        } else {
          inserted(url: url)
        }
      }
    } catch {
      Logger.ui.error("Could not insert new bookmarks: \(error)")
    }

    return bookmarks
  }

  func delete(_ urls: Set<URL>) {
    bookmarks.removeAll { bookmark in
      guard let url = bookmark.url else {
        return false
      }

      return urls.contains(url)
    }

    update()
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(bookmarks, forKey: .bookmarks)
  }

  enum CodingKeys: CodingKey {
    case bookmarks
  }
}

extension Seq: Hashable {
  static func ==(lhs: Seq, rhs: Seq) -> Bool {
    lhs.bookmarks == rhs.bookmarks
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(bookmarks)
  }
}

extension NavigationSplitViewVisibility: RawRepresentable {
  public typealias RawValue = Int

  public init?(rawValue: RawValue) {
    switch rawValue {
      case 0: self = .all
      case 1: self = .detailOnly
      default: return nil
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .all: 0
      case .detailOnly: 1
      default: -1
    }
  }
}

func resampleImage(at url: URL, forSize size: CGSize) async throws -> Image? {
  let options: [CFString : Any] = [
    // We're not going to use kCGImageSourceShouldAllowFloat since the sizes can get very precise.
    kCGImageSourceShouldCacheImmediately: true,
    // For some reason, resizing images with kCGImageSourceCreateThumbnailFromImageIfAbsent sometimes uses a
    // significantly smaller pixel size than specified with kCGImageSourceThumbnailMaxPixelSize. For example, I have a
    // copy of Mikuni Shimokaway's album "all the way" (https://musicbrainz.org/release/19a73c6d-8a11-4851-bb3b-632bcd6f1adc)
    // with scanned images. Even though the first image's size is 800x677 and I set the max pixel size to 802 (since
    // it's based on the view's size), it sometimes returns 160x135. This is made even worse by how the view refuses to
    // update to the next created image. This behavior seems to be predicated on the given max pixel size, since a
    // larger image did not trigger the behavior (but did in one odd case).
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceThumbnailMaxPixelSize: size.length(),
    kCGImageSourceCreateThumbnailWithTransform: true
  ]

  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
    return nil
  }

  let index = CGImageSourceGetPrimaryImageIndex(source)

  guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else {
    return nil
  }

  try Task.checkCancellation()

  Logger.model.info("Created a resampled image from \"\(url)\" at dimensions \(thumbnail.width.description)x\(thumbnail.height.description) for size \(size.width) / \(size.height)")

  return Image(nsImage: .init(cgImage: thumbnail, size: size))
}

enum URLError: Error {
  case inaccessibleSecurityScope
}

struct Keys {
  static let margin = Item("margin", 1)
  static let sidebar = Item("sidebar", NavigationSplitViewVisibility.all)
  static let appearance = Item("appearance", nil as SettingsView.Scheme)

  struct Item<Key, Value> {
    let key: Key
    let value: Value

    init(_ key: Key, _ value: Value) {
      self.key = key
      self.value = value
    }
  }
}
