//
//  ImageCollection.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/17/23.
//

import Foundation
import ImageIO
import OSLog
import SwiftUI
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

    let flipped = orientation == .right

    self.width = flipped ? size.height : size.width
    self.height = flipped ? size.width : size.height
    self.orientation = orientation
  }
}

@Observable
class ImageCollectionItemImage {
  var url: URL
  unowned let item: ImageCollectionItem
  var aspectRatio: Double
  // Do we want to use Observable's accessors directly (rather than putting them on item)?
  var bookmarked: Bool {
    get { item.bookmarked }
    set { item.bookmarked = newValue }
  }

  // Live Text
  var orientation: CGImagePropertyOrientation
  var analysis: ImageAnalysis?

  init(
    url: URL,
    item: ImageCollectionItem,
    aspectRatio: Double,
    orientation: CGImagePropertyOrientation
  ) {
    self.url = url
    self.item = item
    self.aspectRatio = aspectRatio
    self.orientation = orientation
    self.analysis = nil
  }

  convenience init(
    url: URL,
    item: ImageCollectionItem,
    properties: ImageProperties
  ) {
    self.init(
      url: url,
      item: item,
      aspectRatio: properties.width / properties.height,
      orientation: properties.orientation
    )
  }
}

extension ImageCollectionItemImage: Identifiable, Hashable {
  var id: UUID {
    item.bookmark.id
  }

  static func ==(lhs: ImageCollectionItemImage, rhs: ImageCollectionItemImage) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

struct URLSecurityScope {
  let url: URL
  let accessing: Bool
}

struct BookmarkSecurityScope {
  let document: URLSecurityScope?
  let url: URLSecurityScope
}

extension ImageCollectionItemImage: URLScope {
  func startSecurityScope() -> BookmarkSecurityScope {
    let document: URLSecurityScope? = if let url = item.bookmark.document?.url {
      .init(url: url, accessing: url.startSecurityScope())
    } else {
      nil
    }

    return .init(
      document: document,
      url: .init(url: url, accessing: url.startSecurityScope())
    )
  }

  func endSecurityScope(scope: BookmarkSecurityScope) {
    if scope.url.accessing {
      scope.url.url.endSecurityScope()
    }

    if let scope = scope.document, scope.accessing {
      scope.url.endSecurityScope()
    }
  }
}

@Observable
class ImageCollectionItem: Codable {
  var bookmark: BookmarkFile
  var image: ImageCollectionItemImage?
  var bookmarked: Bool

  init(bookmark: BookmarkFile, bookmarked: Bool = false) {
    self.bookmark = bookmark
    self.bookmarked = bookmarked
  }

  init(image: ResolvedBookmarkImage, document: BookmarkDocument?, bookmarked: Bool = false) {
    let url = image.bookmark.url
    let file = BookmarkFile(
      id: image.id,
      data: image.bookmark.data,
      url: url,
      document: document
    )

    self.bookmark = file
    self.bookmarked = bookmarked
    self.image = .init(url: url, item: self, properties: image.properties)
  }

  // Codable conformance

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let id = try container.decode(UUID.self, forKey: .bookmark)

    self.bookmark = .init(id: id, data: .init(), document: nil)
    self.bookmarked = try container.decode(Bool.self, forKey: .bookmarked)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(bookmark.id, forKey: .bookmark)
    try container.encode(bookmarked, forKey: .bookmarked)
  }

  enum CodingKeys: CodingKey {
    case bookmark
    case bookmarked
  }
}

struct ResolvedBookmarkImage {
  let id: UUID
  let bookmark: Bookmark
  let properties: ImageProperties
}

extension ResolvedBookmarkImage {
  init(id: UUID, file: BookmarkFile) throws {
    let data = file.data
    let bookmark = if let url = file.url {
      Bookmark(data: data, url: url)
    } else {
      try BookmarkFile(
        id: file.id,
        data: data,
        url: nil,
        document: file.document
      ).resolve()
    }

    let url = bookmark.url

    guard let properties = url.scoped({ ImageProperties(at: bookmark.url) }) else {
      throw BookmarkError(url: url, underlying: ImageError.undecodable)
    }

    self.init(id: id, bookmark: bookmark, properties: properties)
  }
}

struct ResolvedBookmarkImageDocument {
  let data: Data
  let url: URL
  let images: [ResolvedBookmarkImage]
}

enum ResolvedBookmarkImageKind {
  case document(ResolvedBookmarkImageDocument)
  case file(ResolvedBookmarkImage)
}

struct ResolvedBookmarkDocument {
  let data: Data
  let url: URL
  let images: [Bookmark]
}

enum ResolvedBookmarkKind {
  case document(ResolvedBookmarkDocument)
  case file(Bookmark)
}

struct BookmarkError<Underlying>: Error where Underlying: Error {
  let url: URL
  let underlying: Underlying
}

@Observable
class ImageCollection: Codable {
  // The "source of truth".
  var bookmarks: [BookmarkKind]
  var items = [ImageCollectionItem]()

  // The state for the UI.
  var images = [ImageCollectionItemImage]()
  var bookmarked = [ImageCollectionItemImage]()
  var bookmarkedIndex = ImageCollectionView.Selection()

  // The materialized state useful for the UI.
  var visible = [ImageCollectionItemImage]()
  var currentImage: ImageCollectionItemImage? {
    visible.last
  }

  init() {
    self.bookmarks = []
  }

  init(bookmarks: [BookmarkKind]) {
    self.bookmarks = bookmarks
    self.items = bookmarks.flatMap { bookmark in
      switch bookmark {
        case .document(let document):
          return document.files.map { file in
            ImageCollectionItem(bookmark: file)
          }
        case .file(let file):
          return [ImageCollectionItem(bookmark: file)]
      }
    }
  }

  func load() async -> [ResolvedBookmarkImageKind] {
    await Self.resolve(bookmarks: bookmarks.enumerated()).ordered()
  }

  func updateImages() {
    images = items.compactMap(\.image)
  }

  func updateBookmarks() {
    bookmarked = images.filter { $0.item.bookmarked }
    bookmarkedIndex = Set(bookmarked.map(\.id))
  }

  // If we want hidden and limit to not spill into many callers, it would make sense to have one function that consumes
  // the hidden and limit parameters that exist solely for enumerating and return a structure this can easily iterate.
  static func resolve(urls: some Sequence<Offset<URL>>, hidden: Bool, subdirectories: Bool) async throws -> [Offset<BookmarkKind>] {
    try await withThrowingTaskGroup(of: Offset<BookmarkKind>.self) { group in
      urls.forEach { (offset, url) in
        group.addTask {
          let bookmark = try await url.scoped {
            let data = try url.bookmark(options: .withReadOnlySecurityScope)

            guard try url.isDirectory() == true else {
              return BookmarkKind.file(.init(
                data: data,
                url: url,
                document: nil
              ))
            }

            let contents = try FileManager.default
              .enumerate(at: url, hidden: hidden, subdirectories: subdirectories)
              .finderSort()

            let document = BookmarkDocument(data: data, url: url, files: [])
            document.files = try await withThrowingTaskGroup(of: Offset<BookmarkFile>.self) { group in
              contents.enumerated().forEach { (offset, content) in
                group.addTask {
                  let data = try content.bookmark(options: .withReadOnlySecurityScope, document: url)
                  let file = BookmarkFile(data: data, url: content, document: document)

                  return (offset, file)
                }
              }

              var files = [Offset<BookmarkFile>]()
              files.reserveCapacity(contents.count)

              return try await group.reduce(into: files) { partialResult, file in
                partialResult.append(file)
              }.ordered()
            }

            return .document(document)
          }

          return (offset, bookmark)
        }
      }

      var bookmarks = [Offset<BookmarkKind>]()
      bookmarks.reserveCapacity(urls.underestimatedCount)

      return try await group.reduce(into: bookmarks) { partialResult, bookmark in
        partialResult.append(bookmark)
      }
    }
  }

  static func resolve(bookmarks: some Sequence<Offset<BookmarkKind>>) async -> [Offset<ResolvedBookmarkImageKind>] {
    await withThrowingTaskGroup(of: Offset<ResolvedBookmarkImageKind>.self) { group in
      bookmarks.forEach { (offset, bookmark) in
        group.addTask {
          switch bookmark {
            case .document(let document):
              let bookmark = if let url = document.url {
                Bookmark(data: document.data, url: url)
              } else {
                try document.resolve()
              }

              let url = bookmark.url
              let doc = BookmarkDocument(data: bookmark.data, url: url)
              let document = ResolvedBookmarkImageKind.document(.init(
                data: bookmark.data,
                url: url,
                images: await url.scoped {
                  await withThrowingTaskGroup(of: Offset<ResolvedBookmarkImage>.self) { group in
                    let files = document.files

                    files.enumerated().forEach { (offset, file) in
                      group.addTask {
                        let image = try ResolvedBookmarkImage(
                          id: file.id,
                          file: .init(
                            id: file.id,
                            data: file.data,
                            url: file.url,
                            document: doc
                          )
                        )

                        return (offset, image)
                      }
                    }

                    var images = [Offset<ResolvedBookmarkImage>]()
                    images.reserveCapacity(files.count)

                    while let result = await group.nextResult() {
                      switch result {
                        case .success(let image): images.append(image)
                        case .failure(let err):
                          Logger.model.error("Could not resolve bookmark image for document \"\(url.string)\": \(err)")
                      }
                    }

                    return images.ordered()
                  }
                }
              ))

              return (offset, document)
            case .file(let file):
              let file = ResolvedBookmarkImageKind.file(try .init(id: file.id, file: file))

              return (offset, file)
          }
        }
      }

      var marks = [Offset<ResolvedBookmarkImageKind>]()
      marks.reserveCapacity(bookmarks.underestimatedCount)

      while let result = await group.nextResult() {
        switch result {
          case .success(let bookmark): marks.append(bookmark)
          case .failure(let err):
            Logger.model.error("Could not resolve bookmark: \(err)")
        }
      }

      return marks
    }
  }

  // Codable conformance

  required init(from decoder: Decoder) throws {
    do {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let bookmarks = try container.decode([BookmarkKind].self, forKey: .bookmarks)
      let index = bookmarks.reduce(into: [UUID: BookmarkFile]()) { partialResult, bookmark in
        bookmark.files.forEach { file in
          partialResult[file.id] = file
        }
      }

      let items = try container
        .decode([ImageCollectionItem].self, forKey: .items)
        .compactMap { item -> ImageCollectionItem? in
          guard let file = index[item.bookmark.id] else {
            return nil
          }

          item.bookmark = file

          return item
        }

      self.bookmarks = bookmarks
      self.items = items
    } catch {
      Logger.model.error("Could not decode image collection for scene restoration.")

      self.bookmarks = []
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(bookmarks, forKey: .bookmarks)
    try container.encode(items, forKey: .items)
  }

  enum CodingKeys: CodingKey {
    case bookmarks, items
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

struct ResolvedBookmarkImageSnapshot {
  let document: Bookmark?
  let image: ResolvedBookmarkImage
}
