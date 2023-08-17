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

class Bookmark: Codable {
  var data: Data
  var url: URL?

  init(data: Data, url: URL? = nil) {
    self.data = data
    self.url = url
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.data = try container.decode(Data.self)
  }

  func resolved() throws -> (Bool, URL) {
    var stale = false
    let resolved = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)

    return (stale, resolved)
  }

  func resolve() throws -> URL {
    // Interesting findings in Instruments:
    // - Resolving bookmarks is slow
    // - Extracting the width and height from an image can be slow, but relative to resolving bookmarks, not by much.
    //
    // I tried refactoring SeqImage to only load the URL when a view appears, but this involved making SeqImage
    // a class and adding a resolve method. To put it shortly, @Observable kept complaining about modifying the layout
    // engine from concurrent threads, and I couldn't be bothered to figure out exactly why. It wasn't exactly in zero
    // vain, however, since `bookmarks` is now directly an Array of bookmarks (rather than a wrapped class) and the
    // aspect ratio is directly derived (since no view actually uses its separate values).
    var (stale, url) = try resolved()

    if stale {
      data = try url.scoped { try url.bookmark() }
      url = try resolved().1
    }

    self.url = url

    return url
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    try container.encode(data)
  }
}

extension Bookmark: Hashable {
  static func ==(lhs: Bookmark, rhs: Bookmark) -> Bool {
    lhs.data == rhs.data
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(data)
  }
}

// For some reason, conforming to Transferable and declaring the support for UTType.image is not enough to support .dropDestination(...)
struct SeqImage: Codable {
  var url: URL
  let width: Double
  let height: Double

  init?(url: URL) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      return nil
    }

    let index = CGImageSourceGetPrimaryImageIndex(source)

    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? Dictionary<CFString, Any> else {
      return nil
    }

    self.url = url
    self.width = Double(properties[kCGImagePropertyPixelWidth] as! Int)
    self.height = Double(properties[kCGImagePropertyPixelHeight] as! Int)
  }
}

@Observable
class Seq: Codable {
  // TODO: Try collapsing these two into one SeqImage
  //
  // The point would be to support users who move their files while the app is still open. It may also simplify the
  // data model, since I won't need to sync two separate data structures. It won't be possible to, however, not have
  // two separate properties, since one needs to be materialized to derive the width and height for aspect ratio
  // measuring beforehand. To get around this, using Combine to stream new values may be possible.
  var images = [SeqImage]()
  var bookmarks: [Bookmark]

  init(urls: [URL]) throws {
    self.bookmarks = try urls.map { url in
      .init(data: try url.bookmark())
    }
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.bookmarks = try container.decode([Bookmark].self)
  }

  func load() {
    bookmarks = bookmarks.filter { bookmark in
      do {
        _ = try bookmark.resolve()

        return true
      } catch {
        Logger.model.info("Could not resolve bookmark \"\(bookmark.data)\": \(error)")

        return false
      }
    }

    do {
      images = try bookmarks.compactMap { bookmark in
        let url = bookmark.url!

        return try url.scoped {
          SeqImage(url: url)
        }
      }
    } catch {
      Logger.model.error("Could not load images from bookmarks: \(error)")
    }
  }

  func move(from source: IndexSet, to destination: Int) {
    bookmarks.move(fromOffsets: source, toOffset: destination)
    images.move(fromOffsets: source, toOffset: destination)
  }

  func inserted(url: URL) throws -> (Bookmark, SeqImage)? {
    let data = try url.bookmark()
    let bookmark = Bookmark(data: data)

    guard let image = SeqImage(url: try bookmark.resolve()) else {
      return nil
    }

    return (bookmark, image)
  }

  func insert(_ urls: [URL], at offset: Int, scoped: Bool) -> Bool {
    do {
      let results = try urls.compactMap { url in
        return try if scoped {
          url.scoped { try inserted(url: url) }
        } else {
          inserted(url: url)
        }
      }

      bookmarks.insert(contentsOf: results.map(\.0), at: offset)
      images.insert(contentsOf: results.map(\.1), at: offset)

      return true
    } catch {
      Logger.ui.error("Could not insert new images: \(error)")

      return false
    }
  }

  func delete(_ urls: Set<URL>) {
    bookmarks.removeAll { bookmark in
      guard let url = bookmark.url else {
        return false
      }

      return urls.contains(url)
    }

    images.removeAll { urls.contains($0.url) }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(bookmarks)
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
