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

  init(bookmark: UUID) {
    self.bookmark = bookmark
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
    let root = ImageCollectionItemRoot(bookmark: root.bookmark)
    var container = encoder.singleValueContainer()
    try container.encode(root)
  }
}

struct ImageCollectionDetailItem {
  let image: ImageCollectionItemImage
}

extension ImageCollectionDetailItem: Identifiable {
  var id: ImageCollectionItemImage.ID { image.id }
}

@Observable
class ImageCollection: Codable {
  // The source of truth for the collection.
  //
  // TODO: Remove unused bookmarks in store via items or order
  @ObservationIgnored var items: [ImageCollectionItemRoot.ID: ImageCollectionItem]
  @ObservationIgnored var order: OrderedSet<ImageCollectionItemRoot.ID>

  // The materialized state for the UI.
  var images = [ImageCollectionItemImage]()
  var bookmarks = Set<ImageCollectionItemRoot.ID>()

  init() {
    self.items = [ImageCollectionItemRoot.ID: ImageCollectionItem]()
    self.order = OrderedSet<ImageCollectionItemRoot.ID>()
  }

  func update() {
    self.images = self.order.compactMap { self.items[$0]?.image }
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
    self.order = try container.decode(OrderedSet<ImageCollectionItemRoot.ID>.self, forKey: .order)
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
