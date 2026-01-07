//
//  ImageCollection.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/17/23.
//

import Foundation
import OrderedCollections
import OSLog
import SwiftUI

extension URL {
  static let collectionDirectory = dataDirectory.appending(component: "Collections")
}

struct ImageCollectionItemRoot {
  typealias ID = UUID

  let bookmark: UUID
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
  let bookmark: UUID
  var bookmarked: Bool

  init(bookmark: UUID, bookmarked: Bool) {
    self.bookmark = bookmark
    self.bookmarked = bookmarked
  }
}

extension ImageCollectionItemImage: Identifiable {
  var id: UUID {
    self.bookmark
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
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()

    self.init(
      root: try container.decode(ImageCollectionItemRoot.self),
      image: nil
    )
  }

  func encode(to encoder: any Encoder) throws {
    let root = ImageCollectionItemRoot(bookmark: root.bookmark, bookmarked: bookmarked)

    var container = encoder.singleValueContainer()
    try container.encode(root)
  }
}

@Observable
class ImageCollectionSidebar {
  typealias Selection = Set<ImageCollectionItemImage.ID>

  var images: [ImageCollectionItemImage]
  var selection: Selection
  @ObservationIgnored var current: ImageCollectionItemImage.ID?

  init(
    images: [ImageCollectionItemImage] = [],
    selection: Selection = [],
    current: ImageCollectionItemImage.ID? = nil
  ) {
    self.images = images
    self.selection = selection
    self.current = current
  }
}

struct ImageCollectionSidebars {
  let images = ImageCollectionSidebar()
  let bookmarks = ImageCollectionSidebar()
}

struct ImageCollectionDetailItem {
  let image: ImageCollectionItemImage
}

extension ImageCollectionDetailItem: Identifiable {
  var id: ImageCollectionItemImage.ID { image.id }
}

@Observable
class ImageCollection: Codable {
  typealias Order = OrderedSet<ImageCollectionItemRoot.ID>
  typealias Items = [ImageCollectionItemRoot.ID: ImageCollectionItem]

  // The source of truth for the collection.
  //
  // TODO: Remove unused bookmarks in store via items or order
  @ObservationIgnored var items: Items
  @ObservationIgnored var order: Order

  // The materialized state for the UI.
  var images = [ImageCollectionItemImage]()
  var detail = [ImageCollectionDetailItem]()
  var sidebar: ImageCollectionSidebar { sidebars[keyPath: sidebarPage] }

  // Extra UI state.
  var sidebarPage = \ImageCollectionSidebars.images
  var bookmarks = Set<ImageCollectionItemRoot.ID>()
  @ObservationIgnored var sidebars = ImageCollectionSidebars()

  init() {
    self.items = .init()
    self.order = .init()
  }

  init(items: Items, order: Order) {
    self.items = items
    self.order = order
  }

  func update() {
    images = order.compactMap { items[$0]?.image }
    detail = images.map { image in
      ImageCollectionDetailItem(image: image)
    }

    updateBookmarks()
  }

  func updateBookmarks() {
    let bookmarks = images.filter(\.bookmarked)
    let bookmarked: [ImageCollectionItemImage]
    let page = sidebarPage

    switch page {
      case \.images:
        bookmarked = images
      case \.bookmarks:
        bookmarked = bookmarks
      default:
        Logger.model.error("Unknown sidebar page \"\(page.debugDescription)\"; defaulting to all")

        bookmarked = images
    }

    sidebars[keyPath: page].images = bookmarked

    self.bookmarks = .init(bookmarks.map(\.bookmark))
  }

  func persist(to url: URL) throws {
    let encoder = PropertyListEncoder()
    let encoded = try encoder.encode(self)

    do {
      try encoded.write(to: url)
    } catch let err as CocoaError where err.code == .fileNoSuchFile {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try encoded.write(to: url)
    }
  }

  // MARK: - Codable conformance

  required init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let roots = try container.decode([ImageCollectionItem].self, forKey: .items)

    self.items = .init(uniqueKeysWithValues: roots.map { ($0.root.bookmark, $0) })
    self.order = try container.decode(Order.self, forKey: .order)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Array(items.values), forKey: .items)
    try container.encode(order, forKey: .order)
  }

  enum CodingKeys: CodingKey {
    case items, order, current
  }
}

extension ImageCollection: Hashable {
  static func ==(lhs: ImageCollection, rhs: ImageCollection) -> Bool {
    lhs.order == rhs.order
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(order)
  }
}

extension Navigator {
  init?(page: KeyPath<ImageCollectionSidebars, ImageCollectionSidebar>) {
    switch page {
      case \.images: self = .images
      case \.bookmarks: self = .bookmarks
      default: return nil
    }
  }

  var page: KeyPath<ImageCollectionSidebars, ImageCollectionSidebar> {
    switch self {
      case .images: \.images
      case .bookmarks: \.bookmarks
    }
  }
}
