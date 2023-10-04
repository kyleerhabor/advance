//
//  ImageCollection.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/17/23.
//

import Foundation
import ImageIO
import OSLog
import VisionKit

struct ImageProperties {
  let width: Double
  let height: Double
  let orientation: CGImagePropertyOrientation

  init?(at url: URL) {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      return nil
    }

    let primary = CGImageSourceGetPrimaryImageIndex(source)

    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, primary, nil) as? Dictionary<CFString, Any>,
          let size = pixelSizeOfImageProperties(properties) else {
      return nil
    }

    let orientation = if
      let o = properties[kCGImagePropertyOrientation] as? UInt32,
      let or = CGImagePropertyOrientation(rawValue: o) {
      or
    } else {
      CGImagePropertyOrientation.up
    }

    self.width = orientation == .right ? size.height : size.width
    self.height = orientation == .right ? size.width : size.height
    self.orientation = orientation
  }
}

@Observable
class ImageCollectionItem {
  var url: URL
  unowned var bookmark: ImageCollectionBookmark
  var aspectRatio: Double
  var bookmarked: Bool {
    get { bookmark.item.bookmarked }
    set { bookmark.item.bookmarked = newValue }
  }

  // Live Text
  var orientation: CGImagePropertyOrientation
  var analysis: ImageAnalysis?

  init(url: URL, bookmark: ImageCollectionBookmark, aspectRatio: Double, orientation: CGImagePropertyOrientation) {
    self.url = url
    self.aspectRatio = aspectRatio
    self.bookmark = bookmark
    self.orientation = orientation
    self.analysis = nil
  }

  convenience init(url: URL, bookmark: ImageCollectionBookmark, properties: ImageProperties) {
    self.init(
      url: url,
      bookmark: bookmark,
      aspectRatio: properties.width / properties.height,
      orientation: properties.orientation
    )
  }

  func update(bookmark: Bookmark, properties: ImageProperties) {
    url = bookmark.url
    aspectRatio = properties.width / properties.height
    orientation = properties.orientation
    analysis = nil
    self.bookmark.data = bookmark.data
  }
}

extension ImageCollectionItem: Identifiable, Equatable {
  var id: URL { url }

  static func ==(lhs: ImageCollectionItem, rhs: ImageCollectionItem) -> Bool {
    lhs.url == rhs.url
  }
}

@Observable
class ImageCollectionBookmarkItem: Codable {
  var bookmarked: Bool

  init(bookmarked: Bool = false) {
    self.bookmarked = bookmarked
  }

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.bookmarked = try container.decode(Bool.self, forKey: .bookmarked)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(bookmarked, forKey: .bookmarked)
  }

  enum CodingKeys: CodingKey {
    case bookmarked
  }
}

class ImageCollectionBookmark: Codable {
  var data: Data
  let url: URL?
  var item: ImageCollectionBookmarkItem
  var image: ImageCollectionItem?

  init(data: Data, url: URL?, item: ImageCollectionBookmarkItem) {
    self.data = data
    self.url = url
    self.item = item
  }

  func resolve() throws -> Bookmark {
    try .init(data: data, resolving: .withSecurityScope) { url in
      try url.scoped {
        try url.bookmark()
      }
    }
  }

  // Codable conformance

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.data = try container.decode(Data.self, forKey: .data)
    self.url = nil
    self.item = try container.decode(ImageCollectionBookmarkItem.self, forKey: .item)
    self.image = nil
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(data, forKey: .data)
    try container.encode(item, forKey: .item)
  }

  enum CodingKeys: CodingKey {
    case data, item
  }
}

extension ImageCollectionBookmark: Hashable {
  static func ==(lhs: ImageCollectionBookmark, rhs: ImageCollectionBookmark) -> Bool {
    lhs.data == rhs.data
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(data)
  }
}

@Observable
class ImageCollection: Codable {
  // The "source of truth".
  var bookmarks: [ImageCollectionBookmark]

  // The materialized state useful for the UI.
  var images = [ImageCollectionItem]()
  var bookmarked = [ImageCollectionItem]()
  var bookmarkedIndex = ImageCollectionView.Selection()
  var visible = [ImageCollectionItem]()
  var currentImage: ImageCollectionItem? {
    visible.last
  }

  init() {
    self.bookmarks = []
  }

  init(urls: [URL]) throws {
    self.bookmarks = try urls.map { url in
      .init(
        // I haven't researched whether or not creating bookmarks is expensive.
        data: try url.bookmark(),
        url: url,
        item: .init()
      )
    }
  }

  func load() async -> [ImageCollectionBookmark] {
    await withThrowingTaskGroup(of: Offset<ImageCollectionBookmark>.self) { group in
      for (offset, bookmark) in bookmarks.enumerated() {
        group.addTask {
          let data: Data
          let url: URL

          if let bURL = bookmark.url {
            data = bookmark.data
            url = bURL
          } else {
            let resolved = try bookmark.resolve()

            data = resolved.data
            url = resolved.url
          }

          let mark = ImageCollectionBookmark(data: data, url: url, item: bookmark.item)

          guard let properties = url.scoped({ ImageProperties(at: url) }) else {
            throw ImageError.undecodable
          }

          mark.image = .init(url: url, bookmark: mark, properties: properties)

          return (offset, mark)
        }
      }

      var results = [Offset<ImageCollectionBookmark>]()

      while let result = await group.nextResult() {
        switch result {
          case .success(let bookmark): results.append(bookmark)
          case .failure(let err):
            Logger.model.error("Could not load bookmark: \(err)")
        }
      }

      return results.ordered()
    }
  }

  func updateImages() {
    images = bookmarks.compactMap(\.image)
  }

  func updateBookmarks() {
    bookmarked = images.filter { $0.bookmarked }
    bookmarkedIndex = Set(bookmarked.map(\.id))
  }

  // Codable conformance

  required init(from decoder: Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()

      self.bookmarks = try container.decode([ImageCollectionBookmark].self)
    } catch {
      Logger.model.error("Could not decode image collection for scene restoration.")

      self.bookmarks = []
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()

    try container.encode(bookmarks)
  }
}

extension ImageCollection: Hashable {
  static func ==(lhs: ImageCollection, rhs: ImageCollection) -> Bool {
    return lhs.bookmarks == rhs.bookmarks
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(bookmarks)
  }
}
