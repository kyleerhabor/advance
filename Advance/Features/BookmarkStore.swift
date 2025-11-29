//
//  BookmarkStore.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/20/23.
//

import AdvanceCore
import CryptoKit
import Foundation

struct BookmarkStoreItem {
  typealias ID = UUID
  typealias Hash = Data

  let id: ID
  let bookmark: Bookmark
  let hash: Hash
  let relative: ID?

  // Swift's Hasher is pseudo-randomly seeded per-program execution, so it's not reliable to compute a bookmark's hash
  // and persist it to always have a fast lookup. A SHA256, meanwhile, is persistent, so we can use it.
  static func hash(data: Data) -> Hash {
    .init(SHA256.hash(data: data))
  }
}

extension BookmarkStoreItem {
  init(id: ID, bookmark: Bookmark, relative: ID?) {
    self.init(
      id: id,
      bookmark: bookmark,
      hash: Self.hash(data: bookmark.data),
      relative: relative
    )
  }
}

extension BookmarkStoreItem: Codable {}

struct BookmarkStore {
  typealias Items = Dictionary<BookmarkStoreItem.Hash, BookmarkStoreItem.ID>

  var bookmarks = Dictionary<BookmarkStoreItem.ID, BookmarkStoreItem>()
  var items = Items()
  var urls = Dictionary<BookmarkStoreItem.Hash, URL>()

  mutating func identify(bookmark: Bookmark, relative: BookmarkStoreItem.ID?) -> BookmarkStoreItem.ID {
    identify(
      hash: BookmarkStoreItem.hash(data: bookmark.data),
      bookmark: bookmark,
      relative: relative
    )
  }

  mutating func identify(hash: BookmarkStoreItem.Hash, bookmark: Bookmark, relative: BookmarkStoreItem.ID?) -> BookmarkStoreItem.ID {
    if let id = items[hash] {
      return id
    }

    let id = UUID()
    let bookmark = BookmarkStoreItem(id: id, bookmark: bookmark, hash: hash, relative: relative)

    bookmarks[id] = bookmark
    items[hash] = id

    return id
  }

  mutating func register(item bookmark: BookmarkStoreItem) {
    bookmarks[bookmark.id] = bookmark
    items[bookmark.hash] = bookmark.id
  }
}

extension BookmarkStore: Sendable {}

extension BookmarkStore: Codable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let bookmarks = try container.decode([BookmarkStoreItem].self)

    self.bookmarks = .init(uniqueKeysWithValues: bookmarks.map { ($0.id, $0) })
    self.items = .init(uniqueKeysWithValues: bookmarks.map { ($0.hash, $0.id) })
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(Array(bookmarks.values))
  }
}

struct BookmarkStoreState<T> {
  let store: BookmarkStore
  let value: T
}

extension BookmarkStoreState: Sendable where T: Sendable {}
