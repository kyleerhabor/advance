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

  init?(at url: URL) async {
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
  var id: URL {
    url
  }

  static func ==(lhs: ImageCollectionItem, rhs: ImageCollectionItem) -> Bool {
    lhs.url == rhs.url
  }
}

struct Bookmark {
  let data: Data
  let url: URL
}

@Observable
class ImageCollectionBookmark: Codable {
  var data: Data
  let url: URL?
  let scoped: Bool
  var image: ImageCollectionItem?
  var bookmarked: Bool

  init(data: Data, url: URL?, scoped: Bool, bookmarked: Bool) {
    self.data = data
    self.url = url
    self.scoped = scoped
    self.bookmarked = bookmarked
  }

  func bookmark(url: URL) throws -> Data {
    try if scoped {
      url.scoped { try url.bookmark() }
    } else {
      url.bookmark()
    }
  }

  func resolve() async throws -> Bookmark {
    var data = data
    var stale = false
    var url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)

    if stale {
      data = try bookmark(url: url)
      url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)
    }

    return .init(data: data, url: url)
  }

  // Codable conformance

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.data = try container.decode(Data.self, forKey: .data)
    self.url = nil
    self.scoped = true
    self.image = nil
    self.bookmarked = try container.decode(Bool.self, forKey: .bookmarked)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(data, forKey: .data)
    try container.encode(bookmarked, forKey: .bookmarked)
  }

  enum CodingKeys: CodingKey {
    case data, bookmarked
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
        data: try url.bookmark(),
        url: url,
        scoped: true,
        bookmarked: false
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
            let resolved = try await bookmark.resolve()
            data = resolved.data
            url = resolved.url
          }

          return try await url.scoped {
            let bookmark = ImageCollectionBookmark(
              data: data,
              url: url,
              scoped: true,
              bookmarked: bookmark.bookmarked
            )

            guard let properties = await ImageProperties(at: url) else {
              throw ImageError.undecodable
            }

            bookmark.image = .init(url: url, bookmark: bookmark, properties: properties)

            return (offset, bookmark)
          }
        }
      }

      var results = [Offset<ImageCollectionBookmark>]()

      while let result = await group.nextResult() {
        switch result {
          case .success(let bookmark): results.append(bookmark)
          case .failure(let err):
            Logger.model.error("Could not resolve bookmark on load: \(err)")
        }
      }

      return results.sorted { $0.offset < $1.offset }.map(\.value)
    }
  }

  func updateImages() {
    images = bookmarks.compactMap(\.image)
  }

  func updateBookmarks() {
    bookmarked = images.filter { $0.bookmark.bookmarked }
    bookmarkedIndex = Set(bookmarked.map(\.id))
  }

  // Codable conformance

  required init(from decoder: Decoder) throws {
    do {
      let container = try decoder.singleValueContainer()

      self.bookmarks = try container.decode([ImageCollectionBookmark].self)
    } catch {
      Logger.model.info("Could not decode image collection for scene restoration.")

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
