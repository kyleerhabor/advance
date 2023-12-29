//
//  ImageCollection.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/17/23.
//

import Foundation
import OrderedCollections
import OSLog
import SwiftUI
import VisionKit

// TODO: Implement the following:
//
// Image:
// - Bookmark index

extension URL {
  static let collectionDirectory = dataDirectory.appending(component: "Collections")

  static func collectionFile(for id: UUID) -> URL {
    .collectionDirectory
    .appending(component: id.uuidString)
    .appendingPathExtension(for: .binaryPropertyList)
  }
}

struct URLSource {
  let url: URL
  let options: URL.BookmarkCreationOptions
}

extension URLSource: URLScope {
  func startSecurityScope() -> Bool {
    options.contains(.withSecurityScope) && url.startSecurityScope()
  }

  func endSecurityScope(scope: Bool) {
    if scope {
      url.endSecurityScope()
    }
  }
}

struct ImageCollectionDocumentSource<T> {
  let source: T
  let files: [T]
}

enum ImageCollectionSourceKind<T> {
  case file(T)
  case document(ImageCollectionDocumentSource<T>)

  var files: [T] {
    switch self {
      case .file(let file): [file]
      case .document(let document): document.files
    }
  }
}

struct ImageCollectionItemRoot {
  typealias ID = BookmarkStoreItem.ID

  let bookmark: BookmarkStoreItem.ID
  let bookmarked: Bool
}

extension ImageCollectionItemRoot: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.bookmark == rhs.bookmark
  }
}

extension ImageCollectionItemRoot: Codable {}

@Observable
class ImageCollectionItemImage {
  let bookmark: BookmarkStoreItem.ID

  let url: URL
  let relative: URL?

  var properties: ImageProperties
  var bookmarked: Bool

  var analysis: ImageAnalysis?
  var highlighted: Bool

  init(bookmark: BookmarkStoreItem.ID, url: URL, relative: URL?, properties: ImageProperties, bookmarked: Bool) {
    self.bookmark = bookmark
    self.url = url
    self.relative = relative
    self.properties = properties
    self.bookmarked = bookmarked
    self.analysis = nil
    self.highlighted = false
  }

  func resolve() -> ImageProperties? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let props = source.properties() as? MapCF else {
      return nil
    }

    return .init(from: props)
  }
}

extension ImageCollectionItemImage: Identifiable {
  var id: UUID { bookmark }
}

extension ImageCollectionItemImage: Hashable {
  static func ==(lhs: ImageCollectionItemImage, rhs: ImageCollectionItemImage) -> Bool {
    lhs.url == rhs.url
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(url)
  }
}

extension ImageCollectionItemImage: URLScope {
  struct Scope {
    let image: URLSecurityScope
    let relative: URLSecurityScope?
  }

  func startSecurityScope() -> Scope {
    .init(
      image: .init(url: url),
      relative: relative.map { .init(url: $0) }
    )
  }

  func endSecurityScope(scope: Scope) {
    if scope.image.accessing {
      scope.image.url.endSecurityScope()
    }

    if let relative = scope.relative,
       relative.accessing {
      relative.url.endSecurityScope()
    }
  }
}

struct ImageCollectionItem {
  let root: ImageCollectionItemRoot
  let image: ImageCollectionItemImage?

  var bookmarked: Bool { image?.bookmarked ?? root.bookmarked }
}

extension ImageCollectionItem: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.root == rhs.root
  }
}

extension ImageCollectionItem: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.init(
      root: try container.decode(ImageCollectionItemRoot.self),
      image: nil
    )
  }

  func encode(to encoder: Encoder) throws {
    let root = ImageCollectionItemRoot(bookmark: root.bookmark, bookmarked: bookmarked)

    var container = encoder.singleValueContainer()
    try container.encode(root)
  }
}

@Observable
class ImageCollection: Codable {
  typealias Order = OrderedSet<ImageCollectionItemRoot.ID>
  typealias Items = [ImageCollectionItemRoot.ID: ImageCollectionItem]

  @ObservationIgnored var store: BookmarkStore
  @ObservationIgnored var items: Items
  @ObservationIgnored var order: Order

  // The materialized state for the UI.
  var images = [ImageCollectionItemImage]()
  var bookmarks = [ImageCollectionItemImage]()
  var bookmarkings = Set<ImageCollectionItemRoot.ID>()

  init() {
    self.store = .init()
    self.items = .init()
    self.order = .init()
  }

  init(store: BookmarkStore, items: Items, order: Order) {
    self.store = store
    self.items = items
    self.order = order
  }

  typealias Roots = [URL: ImageCollectionItemRoot]
  typealias Kind = ImageCollectionSourceKind<URLSource>

  static func resolve(
    kinds: [Kind],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<Roots> {
    await withThrowingTaskGroup(of: ImageCollectionSourceKind<URLBookmark>.self) { group in
      kinds.forEach { kind in
        group.addTask {
          switch kind {
            case .document(let document):
              return try await document.source.scoped {
                let item = try URLBookmark(
                  url: document.source.url,
                  options: document.source.options,
                  relativeTo: nil
                )

                let urbs = await withThrowingTaskGroup(of: URLBookmark.self) { group in
                  let files = document.files

                  files.forEach { source in
                    group.addTask {
                      try source.scoped {
                        try .init(
                          url: source.url,
                          options: source.options,
                          relativeTo: document.source.url
                        )
                      }
                    }
                  }

                  var urbs = [URLBookmark](minimumCapacity: files.count)

                  while let result = await group.nextResult() {
                    switch result {
                      case .success(let urb):
                        urbs.append(urb)
                      case .failure(let err):
                        Logger.model.error("Could not create bookmark for URL source of document: \(err)")
                    }
                  }

                  return urbs
                }

                return .document(.init(source: item, files: urbs))
              }
            case .file(let source):
              return try source.scoped {
                let item = try URLBookmark(url: source.url, options: source.options, relativeTo: nil)

                return .file(item)
              }
          }
        }
      }

      var store = store
      var roots = Roots(minimumCapacity: kinds.map(\.files.count).sum())

      while let result = await group.nextResult() {
        switch result {
          case .success(let kind):
            switch kind {
              case .document(let document):
                // TODO: Extract the duplication.
                let bookmark = document.source.bookmark
                let hash = BookmarkStoreItem.hash(data: bookmark.data)
                let id = store.identify(hash: hash, bookmark: bookmark, relative: nil)

                store.urls[hash] = document.source.url

                document.files.forEach { source in
                  let bookmark = source.bookmark
                  let hash = BookmarkStoreItem.hash(data: bookmark.data)
                  let id = store.identify(hash: hash, bookmark: bookmark, relative: id)

                  store.urls[hash] = source.url
                  roots[source.url] = .init(bookmark: id, bookmarked: false)
                }
              case .file(let source):
                let bookmark = source.bookmark
                let hash = BookmarkStoreItem.hash(data: bookmark.data)
                let id = store.identify(hash: hash, bookmark: bookmark, relative: nil)

                store.urls[hash] = source.url
                roots[source.url] = .init(bookmark: id, bookmarked: false)
            }
          case .failure(let err):
            Logger.model.error("Could not create bookmark for URL source: \(err)")
        }
      }

      return .init(store: store, value: roots)
    }
  }

  typealias Bookmarks = Set<BookmarkStoreItem.ID>

  static func resolve(
    bookmarks: [BookmarkStoreItem],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<Bookmarks> {
    await withThrowingTaskGroup(of: Pair<BookmarkStoreItem.ID, BookmarkResolution>?.self) { group in
      let relatives = bookmarks
        .compactMap(\.relative)
        .uniqued()
        .compactMap { id -> URLSecurityScope? in
          guard let bookmark = store.bookmarks[id],
                let url = store.urls[bookmark.hash] else {
            return nil
          }

          return URLSecurityScope(url: url)
        }

      bookmarks.forEach { item in
        group.addTask {
          let resolved: BookmarkResolution
          let bookmark = item.bookmark

          if let url = store.urls[item.hash] {
            resolved = .init(data: bookmark.data, url: url)
          } else {
            let relative: URL?

            if let id = item.relative {
              guard let bookmark = store.bookmarks[id],
                    let url = store.urls[bookmark.hash] else {
                return nil
              }

              relative = url
            } else {
              relative = nil
            }

            resolved = try BookmarkStoreItem.resolve(
              data: bookmark.data,
              options: bookmark.options,
              relativeTo: relative
            )
          }

          return .init(left: item.id, right: resolved)
        }
      }

      var store = store
      var ids = Bookmarks(minimumCapacity: bookmarks.count)

      while let result = await group.nextResult() {
        switch result {
          case .success(let pair):
            guard let pair else {
              continue
            }

            let id = pair.left
            let resolved = pair.right

            ids.insert(id)

            let item = store.bookmarks[id]!
            let bookmark = BookmarkStoreItem(
              id: id,
              bookmark: .init(
                data: resolved.data,
                options: item.bookmark.options
              ),
              relative: item.relative
            )

            store.register(item: bookmark)
            store.urls[bookmark.hash] = resolved.url
          case .failure(let err):
            Logger.model.error("Could not resolve bookmark: \(err)")
        }
      }

      relatives.filter(\.accessing).forEach { $0.url.endSecurityScope() }

      return .init(store: store, value: ids)
    }
  }

  typealias Images = [ImageCollectionItemRoot.ID: ImageCollectionItemImage]

  static func resolve(roots: [ImageCollectionItemRoot], in store: BookmarkStore) async -> Images {
    await withTaskGroup(of: ImageCollectionItemImage?.self) { group in
      let relatives = roots
        .compactMap { store.bookmarks[$0.bookmark]?.relative }
        .uniqued()
        .compactMap { id -> URLSecurityScope? in
          guard let bookmark = store.bookmarks[id],
                let url = store.urls[bookmark.hash] else {
            return nil
          }

          return URLSecurityScope(url: url)
        }

      roots.forEach { root in
        group.addTask {
          guard let bookmark = store.bookmarks[root.bookmark],
                let url = store.urls[bookmark.hash] else {
            return nil
          }

          let relative: URL?

          if let id = bookmark.relative {
            guard let bookmark = store.bookmarks[id],
                  let url = store.urls[bookmark.hash] else {
              return nil
            }

            relative = url
          } else {
            relative = nil
          }

          let image = ImageCollectionItemImage(
            bookmark: bookmark.id,
            url: url,
            relative: relative,
            properties: .init(size: .init(width: 0, height: 0), orientation: .up),
            bookmarked: root.bookmarked
          )

          let source = URLSource(url: url, options: bookmark.bookmark.options)

          guard let properties = source.scoped({ image.resolve() }) else {
            return nil
          }

          image.properties = properties

          return image
        }
      }

      let images = await group.reduce(into: Images(minimumCapacity: roots.count)) { images, image in
        guard let image else {
          return
        }

        images[image.bookmark] = image
      }

      relatives.filter(\.accessing).forEach { $0.url.endSecurityScope() }

      return images
    }
  }

  func update() {
    self.images = order.compactMap { items[$0]?.image }

    updateBookmarks()
  }

  func updateBookmarks() {
    self.bookmarks = images.filter(\.bookmarked)
    self.bookmarkings = .init(bookmarks.map(\.bookmark))
  }

  func persist(to url: URL) throws {
    let encoder = PropertyListEncoder()
    let encoded = try encoder.encode(self)

    try FileManager.default.creatingDirectories(at: url.deletingLastPathComponent(), code: .fileNoSuchFile) {
      try encoded.write(to: url)
    }
  }

  // MARK: - Codable conformance

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let roots = try container.decode([ImageCollectionItem].self, forKey: .items)

    self.store = try container.decode(BookmarkStore.self, forKey: .store)
    self.items = .init(uniqueKeysWithValues: roots.map { ($0.root.bookmark, $0) })
    self.order = try container.decode(Order.self, forKey: .order)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(store, forKey: .store)
    try container.encode(Array(items.values), forKey: .items)
    try container.encode(order, forKey: .order)
  }

  enum CodingKeys: CodingKey {
    case store, items, order
  }
}

extension ImageCollection {
  // MARK: - Convenience
  
  static func resolving(
    bookmarks: [BookmarkStoreItem],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<Bookmarks> {
    let relatives = bookmarks
      .compactMap(\.relative)
      .uniqued()
      .compactMap { store.bookmarks[$0] }

    let rels = await Self.resolve(bookmarks: relatives, in: store)
    let books = bookmarks.filter { bookmark in
      guard let id = bookmark.relative else {
        return true
      }

      return rels.value.contains(id)
    }

    return await Self.resolve(bookmarks: books, in: rels.store)
  }

  func persist(id: UUID) async throws {
    try self.persist(to: URL.collectionFile(for: id))
  }
}

extension ImageCollection: Equatable {
  static func ==(lhs: ImageCollection, rhs: ImageCollection) -> Bool {
    lhs.items == rhs.items && lhs.order == rhs.order
  }
}
