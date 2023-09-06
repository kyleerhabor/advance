//
//  Seq.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/24/23.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

// For some reason, conforming to Transferable and declaring the support for UTType.image is not enough to support .dropDestination(...)
struct SeqImage: Identifiable {
  let id: UUID
  var url: URL
  let size: Size
  var type: UTType?
  var fileSize: Int?
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

  func delete(_ urls: SequenceView.Selection) {
    bookmarks.removeAll { urls.contains($0.id) }
    update()
  }

  func urls(from ids: SequenceView.Selection) -> [URL] {
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
