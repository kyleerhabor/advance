//
//  BookmarkStore.swift
//  Sequential
//
//  Created by Kyle Erhabor on 12/20/23.
//

import CryptoKit
import Foundation

struct BookmarkStoreItem {
  typealias ID = UUID
  typealias Hash = Data

  let id: ID
  let bookmark: Bookmark
  let hash: Hash
  let relative: ID?

  static func resolve(
    data: Data,
    options: URL.BookmarkCreationOptions,
    relativeTo relative: URL?
  ) throws -> BookmarkResolution {
    try .init(
      data: data,
      // In my experience, if the user has a volume that was created as an image in Disk Utility and it's not mounted,
      // resolution will fail while prompting the user to unlock the volume. Now, we're not a file managing app, so we
      // don't need to invest in making that work.
      //
      // Note there is also a .withoutUI option, but I haven't checked whether or not it performs the same action.
      options: .init(options).union(.withoutMounting),
      relativeTo: relative
    ) { url in
      try url.scoped {
        try url.bookmark(options: options, relativeTo: relative)
      }
    }
  }

  // Swift's Hasher is pseudo-randomly seeded per-program execution, so it's not reliable to compute a bookmark's hash
  // and persist it to always have a fast comparison. A SHA256, meanwhile, is persistent, so we can use it.
  static func hash(data: Data) -> Hash {
    .init(SHA256.hash(data: data))
  }

  // TODO: Remove this.
  func parent(in store: BookmarkStore) -> Self? {
    guard let relative else {
      return nil
    }

    return store.bookmarks[relative]
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

extension BookmarkStore: Codable {
  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let bookmarks = try container.decode([BookmarkStoreItem].self)

    self.bookmarks = .init(uniqueKeysWithValues: bookmarks.map { ($0.id, $0) })
    self.items = .init(uniqueKeysWithValues: bookmarks.map { ($0.hash, $0.id) })
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(Array(bookmarks.values))
  }
}

struct BookmarkStoreState<T> {
  let store: BookmarkStore
  let value: T
}
