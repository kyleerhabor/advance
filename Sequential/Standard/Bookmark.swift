//
//  Bookmark.swift
//  Sequential
//
//  Created by Kyle Erhabor on 12/20/23.
//

import Foundation
import OSLog

// MARK: - URL

extension URL {
  func startSecurityScope() -> Bool {
    let accessing = self.startAccessingSecurityScopedResource()

    if accessing {
      Logger.sandbox.debug("Started security scope for URL \"\(self.string)\"")
    } else {
      Logger.sandbox.info("Tried to start security scope for URL \"\(self.string)\", but scope was inaccessible")
    }

    return accessing
  }

  func endSecurityScope() {
    self.stopAccessingSecurityScopedResource()

    Logger.sandbox.debug("Ended security scope for URL \"\(self.string)\"")
  }

  func scoped<T>(_ body: () throws -> T) rethrows -> T {
    let accessing = startSecurityScope()

    defer {
      if accessing {
        endSecurityScope()
      }
    }

    return try body()
  }

  func scoped<T>(_ body: () async throws -> T) async rethrows -> T {
    let accessing = startSecurityScope()

    defer {
      if accessing {
        endSecurityScope()
      }
    }

    return try await body()
  }

  func bookmark(options: BookmarkCreationOptions, relativeTo relative: URL?) throws -> Data {
    try self.bookmarkData(options: options, includingResourceValuesForKeys: [], relativeTo: relative)
  }
}

extension URL.BookmarkCreationOptions {
  static let withReadOnlySecurityScope = Self([.withSecurityScope, .securityScopeAllowOnlyReadAccess])
}

extension URL.BookmarkCreationOptions: Codable {}

extension URL.BookmarkResolutionOptions {
  init(_ options: URL.BookmarkCreationOptions) {
    self.init()

    if options.contains(.withSecurityScope) {
      self.insert(.withSecurityScope)
    }

    // This option is super important, as it prevents the sandbox from interning URLs for security scoping. If a user
    // loads, say, 3,000 URLs with security scopes while this option is not set, the URLs will be resolved, but
    // internally fail whenever the program tries to use it.
    if options.contains(.withoutImplicitSecurityScope) {
      self.insert(.withoutImplicitStartAccessing)
    }
  }
}

protocol SecurityScope {
  associatedtype Scope

  func startSecurityScope() -> Scope

  func endSecurityScope(scope: Scope)

  func scoped<T>(_ body: () throws -> T) rethrows -> T

  func scoped<T>(_ body: () async throws -> T) async rethrows -> T
}

extension SecurityScope {
  func scoped<T>(_ body: () throws -> T) rethrows -> T {
    let scope = startSecurityScope()

    defer { endSecurityScope(scope: scope) }

    return try body()
  }

  func scoped<T>(_ body: () async throws -> T) async rethrows -> T {
    let scope = startSecurityScope()

    defer { endSecurityScope(scope: scope) }

    return try await body()
  }
}

extension Optional: SecurityScope where Wrapped: SecurityScope {
  func startSecurityScope() -> Wrapped.Scope? {
    guard case .some(let wrapped) = self else {
      return nil
    }

    return wrapped.startSecurityScope()
  }

  func endSecurityScope(scope: Wrapped.Scope?) {
    guard case .some(let wrapped) = self,
          let scope else {
      return
    }

    wrapped.endSecurityScope(scope: scope)
  }
}

protocol URLScope: SecurityScope {
  var url: URL { get }
}

extension URL: URLScope {
  var url: URL { self }

  func endSecurityScope(scope: Bool) {
    if scope { self.endSecurityScope() }
  }
}

struct URLSecurityScope {
  let url: URL
  let accessing: Bool
}

extension URLSecurityScope {
  init(source: URLSource) {
    self.init(url: source.url, accessing: source.startSecurityScope())
  }
}

// MARK: - Bookmark

/// A bookmark.
///
/// A "bookmark" is a union of a URL bookmark's data and creation options, which can be resolved into a URL—even when
/// its underlying representation changes (e.g. its location differs).
///
/// On its own, a bookmark is solely concerned for itself, and may not provide enough information to reliably resolve
/// into a URL. For that reason, bookmarks are considered primitive, and often need to be combined with other data to
/// resolve appropriately.
struct Bookmark {
  /// The bookmark's data.
  let data: Data

  /// The bookmark's creation options.
  let options: URL.BookmarkCreationOptions
}

extension Bookmark {
  /// Creates a bookmark for a URL.
  ///
  /// - Parameters:
  ///   - url: The URL to create the bookmark for.
  ///   - options: The creation options to use when creating the bookmark.
  ///   - relativeTo: The URL the bookmark should be relative to.
  init(url: URL, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    self.init(
      data: try url.bookmark(options: options, relativeTo: relative),
      options: options
    )
  }
}

extension Bookmark: Codable {}

/// A URL resolved from a bookmark.
struct BookmarkURL {
  /// The URL resolved from a bookmark.
  let url: URL

  /// An indicator of whether the bookmark data the URL was resolved from is stale.
  let stale: Bool
}

extension BookmarkURL {
  /// Resolves a bookmark.
  ///
  /// - Parameters:
  ///   - data: The bookmark's data.
  ///   - options: The bookmark's resolution options.
  ///   - relativeTo: The URL the bookmark is relative to.
  init(data: Data, options: URL.BookmarkResolutionOptions, relativeTo relative: URL?) throws {
    var stale = false

    self.url = try URL(resolvingBookmarkData: data, options: options, relativeTo: relative, bookmarkDataIsStale: &stale)
    self.stale = stale
  }
}

// TODO: Think of a better name.
/// A union of bookmark data and its associated URL.
struct BookmarkResolution {
  /// The bookmark data.
  let data: Data

  /// The URL associated with the bookmark.
  let url: URL
}

extension BookmarkResolution {
  /// Resolves a bookmark, recreating it when it's stale.
  ///
  /// - Parameters:
  ///   - data: The bookmark's data.
  ///   - options: The bookmark's resolution options.
  ///   - relativeTo: The URL the bookmark is relative to.
  ///   - create: The closure to call to recreate the bookmark when it's stale, receiving the resolved URL to create it from.
  init(
    data: Data,
    options: URL.BookmarkResolutionOptions,
    relativeTo relative: URL?,
    create: (URL) throws -> Data
  ) throws {
    var data = data
    let bookmark = try BookmarkURL(data: data, options: options, relativeTo: relative)

    if bookmark.stale {
      Logger.model.debug("Bookmark at URL \"\(bookmark.url.string)\" (\(data)) is stale. Recreating...")

      // From the language of the stale parameter, it sounds like we can use the URL from the stale bookmark as-is
      // without resolving it a second time.
      data = try create(bookmark.url)
    }

    self.init(data: data, url: bookmark.url)
  }
}

/// A union of a URL and its associated bookmark.
struct URLBookmark {
  /// The URL.
  let url: URL

  /// The bookmark associated with the URL.
  let bookmark: Bookmark
}

// MARK: - URL + Bookmark

extension URLBookmark {
  /// Creates a bookmark for the given URL.
  ///
  /// - Parameters:
  ///   - url: The URL to create the bookmark for.
  ///   - options: The creation options to use when creating the bookmark.
  ///   - relativeTo: The URL's relative for the bookmark.
  init(url: URL, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    self.init(
      url: url,
      bookmark: try .init(url: url, options: options, relativeTo: relative)
    )
  }
}

extension URLBookmark: URLScope {
  func startSecurityScope() -> Bool {
    bookmark.options.contains(.withSecurityScope) && url.startSecurityScope()
  }

  func endSecurityScope(scope: Bool) {
    if scope {
      url.endSecurityScope()
    }
  }
}
