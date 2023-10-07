//
//  Bookmark.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/5/23.
//

import Foundation

struct ResolvedBookmark {
  let url: URL
  let stale: Bool

  init(
    data: Data,
    options: URL.BookmarkResolutionOptions,
    relativeTo document: URL? = nil
  ) throws {
    var stale = false

    self.url = try URL(resolvingBookmarkData: data, options: options, relativeTo: document, bookmarkDataIsStale: &stale)
    self.stale = stale
  }
}

struct Bookmark {
  let data: Data
  let url: URL
}

extension Bookmark {
  init(
    data: Data,
    resolving: URL.BookmarkResolutionOptions,
    relativeTo document: URL? = nil,
    create: (URL) throws -> Data
  ) throws {
    var data = data
    var resolved = try ResolvedBookmark(data: data, options: resolving, relativeTo: document)

    if resolved.stale {
      // From the resolution options, we can infer that if it includes .withSecurityScope, wrapping URL in the method
      // with the same name would theoretically be valid, but we still wouldn't exactly know *how* to create the
      // bookmark. Personally, I think accepting a closure and having the caller handle the case maintains simplicity.
      // If we did check for the security scope and implicity wrap create in one, the user would need to implicitly
      // track it, which would be more complex.
      data = try create(resolved.url)
      resolved = try ResolvedBookmark(data: data, options: resolving, relativeTo: document)
    }

    self.init(data: data, url: resolved.url)
  }
}

class BookmarkFile: Codable {
  let id: UUID
  let data: Data
  let url: URL?
  let document: URL?

  init(id: UUID = .init(), data: Data, url: URL? = nil, document: URL?) {
    self.id = id
    self.data = data
    self.url = url
    self.document = document
  }

  static func bookmark(url: URL, document: URL?) throws -> Data {
    try url.bookmark(options: .withReadOnlySecurityScope, document: document)
  }

  func resolve() throws -> Bookmark {
    try Bookmark(data: data, resolving: .withSecurityScope, relativeTo: document) { url in
      try url.scoped {
        try Self.bookmark(url: url, document: document)
      }
    }
  }

  // Codable conformance

  required init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.id = try container.decode(UUID.self, forKey: .id)
    self.data = try container.decode(Data.self, forKey: .data)
    self.url = nil
    self.document = nil
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(id, forKey: .id)
    try container.encode(data, forKey: .data)
  }

  enum CodingKeys: CodingKey {
    case id, data
  }
}

extension BookmarkFile: Hashable {
  static func ==(lhs: BookmarkFile, rhs: BookmarkFile) -> Bool {
    lhs.data == rhs.data
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(data)
  }
}

struct BookmarkDocument: Codable {
  let data: Data
  let url: URL?
  var files: [BookmarkFile]

  init(data: Data, url: URL? = nil, files: [BookmarkFile] = []) {
    self.data = data
    self.url = url
    self.files = files
  }

  func resolve() throws -> Bookmark {
    try Bookmark(data: data, resolving: .withSecurityScope) { url in
      try url.scoped {
        try BookmarkFile.bookmark(url: url, document: nil)
      }
    }
  }

  // Codable conformance

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.data = try container.decode(Data.self, forKey: .data)
    self.url = nil
    self.files = try container.decode([BookmarkFile].self, forKey: .files)
  }

  enum CodingKeys: CodingKey {
    case data, files
  }
}

extension BookmarkDocument: Hashable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.data == rhs.data && lhs.files == rhs.files
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(data)
    hasher.combine(files)
  }
}

enum BookmarkKind: Codable, Hashable {
  case document(BookmarkDocument), file(BookmarkFile)

  var files: [BookmarkFile] {
    switch self {
      case .document(let document):
        document.files
      case .file(let file):
        [file]
    }
  }
}
