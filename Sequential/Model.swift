//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import ImageIO
import OSLog
import SwiftUI
import UniformTypeIdentifiers

enum ImageError: Error {
  case undecodable
}

struct Size: Hashable {
  let width: Int
  let height: Int

  func aspectRatio() -> Double {
    let width = Double(width)
    let height = Double(height)

    return width / height
  }

  func field() -> Int {
    width * height
  }
}

func reversedImage(properties: Dictionary<CFString, Any>) -> Bool? {
  guard let raw = properties[kCGImagePropertyOrientation] as? UInt32,
        let orientation = CGImagePropertyOrientation(rawValue: raw) else {
    return nil
  }

  // TODO: Cover other orientations.
  return orientation == .right
}

struct SeqBookmark: Codable {
  let id: UUID
  var data: Data
  var url: URL?
  var size: Size?
  var type: UTType?
  var fileSize: Int?

  init(
    id: UUID = .init(),
    data: Data,
    url: URL? = nil,
    size: Size? = nil,
    type: UTType? = nil,
    fileSize: Int? = nil
  ) {
    self.id = id
    self.data = data
    self.url = url
    self.size = size
    self.type = type
    self.fileSize = fileSize
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(data: try container.decode(Data.self, forKey: .data))
  }

  func resolve() throws -> Self {
    var this = self
    var resolved = try ResolvedBookmark(from: data)

    if resolved.stale {
      let url = resolved.url
      this.data = try url.scoped { try url.bookmark() }
      resolved = try ResolvedBookmark(from: data)
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
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int else {
        return nil
      }

      let reversed = reversedImage(properties: properties) == true

      var this = self
      this.size = .init(
        width: reversed ? height : width,
        height: reversed ? width : height
      )

      // These are not necessary to perform immediately, but are still useful for later.

      if let type = CGImageSourceGetType(source),
         let type = UTType(type as String) {
        this.type = type
      }

      if let container = CGImageSourceCopyProperties(source, nil) as? Dictionary<CFString, Any>,
         let size = container[kCGImagePropertyFileSize] as? Int {
        this.fileSize = size
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
            let size = bookmark.size else {
        return nil
      }

      return .init(
        id: bookmark.id,
        url: url,
        size: size,
        type: bookmark.type,
        fileSize: bookmark.fileSize
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
    images.filter(in: ids, by: \.id).map(\.url)
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

enum ExecutionError: Error {
  case interrupt
}

struct CopyDepotBookmark: Codable {
  let data: Data
  let url: URL
  let resolved: Bool

  init(data: Data, url: URL, resolved: Bool = false) {
    self.data = data
    self.url = url
    self.resolved = resolved
  }

  func resolve() throws -> Self {
    var data = data
    var resolved = try ResolvedBookmark(from: data)

    if resolved.stale {
      let url = resolved.url
      data = try url.scoped { try url.bookmark(options: .withSecurityScope) }
      resolved = try ResolvedBookmark(from: data)
    }

    return .init(data: data, url: resolved.url, resolved: true)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(
      data: try container.decode(Data.self, forKey: .data),
      url: try container.decode(URL.self, forKey: .url)
    )
  }

  enum CodingKeys: CodingKey {
    case data, url
  }
}

struct CopyDepotURL {
  let url: URL
  let path: AttributedString
}

@Observable
// I tried writing a @DataStorage property wrapper to act like @AppStorage but specifically for storing Data types
// automatically (via Codable conformance), but had trouble reflecting changes across scenes. In addition, changes
// would only get communicated to the property wrapper on direct assignment (making internal mutation not simple)
class CopyDepot {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var bookmarks = [CopyDepotBookmark]()
  var resolved = [CopyDepotURL]()
  var unresolved = [CopyDepotURL]()

  func resolve() {
    guard let data = UserDefaults.standard.data(forKey: "copyDestinations") else {
      Logger.model.info("No data for copy destinations found in user defaults")

      return
    }

    do {
      self.bookmarks = try decoder
        .decode([CopyDepotBookmark].self, from: data)
        .map { bookmark in
          do {
            return try bookmark.resolve()
          } catch {
            guard let err = error as? CocoaError,
                  err.code == .fileNoSuchFile || err.code == .fileReadCorruptFile else {
              Logger.model.error("Bookmark for copy destination \"\(bookmark.url)\" (\(bookmark.data)) could not be resolved: \(error)")

              return bookmark
            }

            Logger.model.info("Bookmark for copy destination \"\(bookmark.url)\" (\(bookmark.data)) could not be resolved. Is it temporarily unavailable?")

            return bookmark
          }
        }

      update()
    } catch {
      Logger.model.error("\(error)")
    }
  }

  func urls(from urls: [URL]) -> [CopyDepotURL] {
    let index = Set(urls)

    return urls.map { url in
      var index = index
      index.remove(url)

      let path = path(
        of: url,
        considering: Array(index)
      ).joined(separator: " 􀰇 ")

      var attr = AttributedString(path)

      if let range = attr.range(of: "􀰇") {
        attr[range].foregroundColor = .tertiaryLabel
      }

      return .init(
        url: url,
        path: attr
      )
    }
  }

  func update() {
    resolved = urls(from: bookmarks.filter(\.resolved).map(\.url))
    unresolved = urls(from: bookmarks.filter { !$0.resolved }.map(\.url))
  }

  func store() {
    do {
      let data = try encoder.encode(bookmarks)

      UserDefaults.standard.set(data, forKey: "copyDestinations")
    } catch {
      Logger.model.error("\(error)")
    }
  }

  private func path(of url: URL, considering urls: [URL]) -> [String] {
    let components = url.pathComponents
    let paths = Array(components.reversed())
    var remaining = urls.map { $0.pathComponents.dropLast(0) }
    var result = [String]()

    // Very crude, but works.
    for path in paths {
      if remaining.isEmpty {
        // If, on an e.g. removable volume, the path refers to a URL in the user-separated trash (e.g. "/Volumes/T7/.Trashes/<uid>/Three Days of Happiness"),
        // rewrite that segment to be more user-friendly.
        if Int(result.last!) != nil && path == ".Trashes" {
          result.removeLast()
          result.append("Trash")
        }

        return result.reversed()
      }

      remaining = remaining
        .filter { $0.last == path }
        .map { $0.dropLast() }

      result.append(path)
    }

    return result.reversed()
  }
}
