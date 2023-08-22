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
struct SeqImage: Identifiable {
  let id: UUID
  var url: URL
  var ratio: Double
}

struct SeqResolvedBookmark {
  let url: URL
  let stale: Bool
}

struct SeqBookmark: Codable {
  let id: UUID
  var data: Data
  var url: URL?
  var ratio: Double?

  init(
    id: UUID = .init(),
    data: Data,
    url: URL? = nil,
    ratio: Double? = nil
  ) {
    self.id = id
    self.data = data
    self.url = url
    self.ratio = ratio
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

      guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? Dictionary<CFString, Any>,
            let pWidth = properties[kCGImagePropertyPixelWidth] as? Int,
            let pHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
        return nil
      }

      let width = Double(pWidth)
      let height = Double(pHeight)
      var this = self

      if let raw = properties[kCGImagePropertyOrientation] as? UInt32,
         let orientation = CGImagePropertyOrientation(rawValue: raw),
         // TODO: Cover other orientations.
         orientation == .right {
        this.ratio = height / width
      } else {
        this.ratio = width / height
      }

      return this
    }
  }

  enum CodingKeys: CodingKey {
    case data
  }
}

extension SeqBookmark: Hashable {
  static func ==(lhs: SeqBookmark, rhs: SeqBookmark) -> Bool {
    lhs.data == rhs.data
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

  func load() async -> [SeqBookmark] {
    var bookmarks = [SeqBookmark]()

    await self.bookmarks.perform { bookmark in
      do {
        guard let bookmark = try bookmark.resolve().image() else {
          return
        }

        bookmarks.append(bookmark)
      } catch {
        Logger.model.info("Could not resolve bookmark \"\(bookmark.data)\": \(error)")
      }
    }

    return bookmarks.ordered(by: self.bookmarks, for: \.id)
  }

  func update() {
    images = bookmarks.compactMap { bookmark in
      guard let url = bookmark.url,
            let ratio = bookmark.ratio else {
        return nil
      }

      return .init(
        id: bookmark.id,
        url: url,
        ratio: ratio
      )
    }
  }

  func store(bookmarks: [SeqBookmark], at offset: Int) {
    self.bookmarks.insert(contentsOf: bookmarks, at: offset)

    // We could speed this up with some indexes (I just don't want to think about it right now).
    self.bookmarks = self.bookmarks.filter { bookmark in
      !bookmarks.contains { $0.url == bookmark.url && $0.id != bookmark.id }
    }

    update()
  }

  func move(from source: IndexSet, to destination: Int) {
    bookmarks.move(fromOffsets: source, toOffset: destination)
    update()
  }

  func inserted(bookmark: SeqBookmark, url: URL) throws -> SeqBookmark? {
    var bookmark = bookmark
    bookmark.data = try url.bookmark()

    return try bookmark.resolve().image()
  }

  func insert(_ urls: [URL], scoped: Bool) async -> [SeqBookmark] {
    // Note that the data property gets replaced later.
    let bookmarks = urls.map { SeqBookmark(id: .init(), data: .init(), url: $0) }

    do {
      var results = [SeqBookmark]()

      try await bookmarks.perform { bookmark in
        let url = bookmark.url!

        let bookmark = try if scoped {
          url.scoped { try self.inserted(bookmark: bookmark, url: url) }
        } else {
          self.inserted(bookmark: bookmark, url: url)
        }

        guard let bookmark else {
          return
        }

        results.append(bookmark)
      }

      return results.ordered(by: bookmarks, for: \.id)
    } catch {
      Logger.ui.error("Could not insert bookmarks: \(error)")

      return []
    }
  }

  func delete(_ urls: Set<SeqImage.ID>) {
    bookmarks.removeAll { urls.contains($0.id) }
    update()
  }

  func urls(from ids: Set<SeqImage.ID>) -> [URL] {
    images.filter { ids.contains($0.id) }.map(\.url)
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

enum URLError: Error {
  case inaccessibleSecurityScope
}

struct Keys {
  static let margin = Item("margin", 1)
  static let sidebar = Item("sidebar", NavigationSplitViewVisibility.all)
  static let appearance = Item("appearance", nil as SettingsView.Scheme)
  // I think enabling Live Text by default but disabling the icons strikes a nice compromise between convenience (e.g.
  // being able to right click and copy an image) and UI simplicity (having the buttons not get in the way).
  static let liveText = Item("liveText", true)
  static let liveTextIcon = Item("liveTextIcon", false)

  struct Item<Key, Value> {
    let key: Key
    let value: Value

    init(_ key: Key, _ value: Value) {
      self.key = key
      self.value = value
    }
  }
}
