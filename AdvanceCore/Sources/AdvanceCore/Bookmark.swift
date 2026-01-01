//
//  Bookmark.swift
//  
//
//  Created by Kyle Erhabor on 6/14/24.
//

import Foundation
import OSLog

extension URL {
  public func startSecurityScope() -> Bool {
    let accessing = self.startAccessingSecurityScopedResource()

    if accessing {
      Logger.sandbox.debug("Started security scope for resource at file URL '\(self.pathString)'")
    } else {
      Logger.sandbox.log("Could not start security scope for resource at file URL '\(self.pathString)'")
    }

    return accessing
  }

  public func endSecurityScope() {
    self.stopAccessingSecurityScopedResource()

    Logger.sandbox.debug("Ended security scope for file URL '\(self.pathString)'")
  }

  @available(*, noasync)
  public func bookmark(options: BookmarkCreationOptions, relativeTo relative: URL?) throws -> Data {
    try self.bookmarkData(options: options, relativeTo: relative)
  }

  public func bookmark(options: BookmarkCreationOptions, relativeTo relative: URL?) async throws -> Data {
    try await withTranslatingCheckedContinuation {
      try self.bookmark(options: options, relativeTo: relative)
    }
  }
}

public protocol SecurityScopedResource {
  associatedtype SecurityScope

  func startSecurityScope() -> SecurityScope

  func endSecurityScope(_ scope: SecurityScope)
}

extension SecurityScopedResource {
  public func accessingSecurityScopedResource<R, E>(_ body: () throws(E) -> R) throws(E) -> R {
    let scope = startSecurityScope()

    defer {
      endSecurityScope(scope)
    }

    return try body()
  }

  public func accessingSecurityScopedResource<Result, E>(
    _ body: @isolated(any) () async throws(E) -> Result
  ) async throws(E) -> Result where Result: Sendable {
    let scope = startSecurityScope()

    defer {
      endSecurityScope(scope)
    }

    return try await body()
  }
}

extension URL: SecurityScopedResource {
  public func endSecurityScope(_ scope: Bool) {
    guard scope else {
      return
    }

    self.endSecurityScope()
  }
}

public struct URLSource {
  public let url: URL
  public let options: URL.BookmarkCreationOptions

  public init(url: URL, options: URL.BookmarkCreationOptions) {
    self.url = url
    self.options = options
  }
}

extension URLSource: Sendable, Equatable {}

extension URLSource: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(url)
    hasher.combine(options.rawValue)
  }
}

extension URLSource: SecurityScopedResource {
  public func startSecurityScope() -> Bool {
    options.contains(.withSecurityScope) && url.startSecurityScope()
  }

  public func endSecurityScope(_ scope: Bool) {
    url.endSecurityScope(scope)
  }
}

public struct URLSourceDocument {
  public let source: URLSource
  public let relative: URLSource?

  public init(source: URLSource, relative: URLSource?) {
    self.source = source
    self.relative = relative
  }
}

extension URLSourceDocument: Sendable {}

extension URLSourceDocument: SecurityScopedResource {
  public struct SecurityScope {
    let source: URLSource.SecurityScope
    let relative: URLSource.SecurityScope?
  }

  public func startSecurityScope() -> SecurityScope {
    let relative = relative?.startSecurityScope()
    let source = source.startSecurityScope()

    return SecurityScope(source: source, relative: relative)
  }

  public func endSecurityScope(_ scope: SecurityScope) {
    source.endSecurityScope(scope.source)

    if let scope = scope.relative {
      relative?.endSecurityScope(scope)
    }
  }
}

// TODO: Remove.
//
// With URLSourceDocument, this is a hazard for our use case.
extension Optional: SecurityScopedResource where Wrapped: SecurityScopedResource {
  public func startSecurityScope() -> Wrapped.SecurityScope? {
    self?.startSecurityScope()
  }

  public func endSecurityScope(_ scope: Wrapped.SecurityScope?) {
    guard let scope else {
      return
    }

    self?.endSecurityScope(scope)
  }
}

extension KeyedEncodingContainer {
  mutating func encode(_ value: URL.BookmarkCreationOptions, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encode(value.rawValue, forKey: key)
  }

  public mutating func encode(_ value: URL.BookmarkCreationOptions?, forKey key: KeyedEncodingContainer<K>.Key) throws {
    try self.encode(value?.rawValue, forKey: key)
  }
}

extension KeyedDecodingContainer {
  func decode(
    _ type: URL.BookmarkCreationOptions.Type,
    forKey key: KeyedDecodingContainer<K>.Key,
  ) throws -> URL.BookmarkCreationOptions {
    URL.BookmarkCreationOptions(rawValue: try self.decode(URL.BookmarkCreationOptions.RawValue.self, forKey: key))
  }

  public func decodeIfPresent(
    _ type: URL.BookmarkCreationOptions.Type,
    forKey key: KeyedDecodingContainer<K>.Key,
  ) throws -> URL.BookmarkCreationOptions? {
    guard let rawValue = try self.decodeIfPresent(URL.BookmarkCreationOptions.RawValue.self, forKey: key) else {
      return nil
    }

    return URL.BookmarkCreationOptions(rawValue: rawValue)
  }
}

public struct Bookmark {
  public let data: Data
  public let options: URL.BookmarkCreationOptions

  public init(data: Data, options: URL.BookmarkCreationOptions) {
    self.data = data
    self.options = options
  }

  @available(*, noasync)
  public init(url: URL, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    self.init(
      data: try url.bookmark(options: options, relativeTo: relative),
      options: options
    )
  }

  public init(
    url: URL,
    options: URL.BookmarkCreationOptions,
    relativeTo relative: URL?,
  ) async throws {
    self.init(
      data: try await url.bookmark(options: options, relativeTo: relative),
      options: options
    )
  }
}

extension Bookmark: Sendable {}

extension Bookmark: Codable {
  enum CodingKeys: CodingKey {
    case data, options
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(
      data: try container.decode(Data.self, forKey: .data),
      options: try container.decode(URL.BookmarkCreationOptions.self, forKey: .options),
    )
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(data, forKey: .data)
    try container.encode(options, forKey: .options)
  }
}

public struct URLBookmark {
  public let url: URL
  public let bookmark: Bookmark

  public init(url: URL, bookmark: Bookmark) {
    self.url = url
    self.bookmark = bookmark
  }

  @available(*, noasync)
  public init(url: URL, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    self.init(
      url: url,
      bookmark: try Bookmark(url: url, options: options, relativeTo: relative),
    )
  }

  public init(
    url: URL,
    options: URL.BookmarkCreationOptions,
    relativeTo relative: URL?,
  ) async throws {
    self.init(
      url: url,
      bookmark: try await Bookmark(url: url, options: options, relativeTo: relative),
    )
  }
}

extension URLBookmark: Sendable, Codable {}

public struct ResolvedBookmark {
  public let url: URL
  public let isStale: Bool

  public init(url: URL, isStale: Bool) {
    self.url = url
    self.isStale = isStale
  }

  public init(data: Data, options: URL.BookmarkResolutionOptions, relativeTo relative: URL?) throws {
    var isStale = false

    self.url = try URL(resolvingBookmarkData: data, options: options, relativeTo: relative, bookmarkDataIsStale: &isStale)
    self.isStale = isStale
  }
}

extension ResolvedBookmark: Sendable {}

// https://english.stackexchange.com/a/227919
public struct AssignedBookmark {
  public let resolved: ResolvedBookmark
  public let data: Data

  public init(resolved: ResolvedBookmark, data: Data) {
    self.resolved = resolved
    self.data = data
  }

  public init(
    data: Data,
    options: URL.BookmarkResolutionOptions,
    relativeTo relative: URL?,
    create: (URL) throws -> Data,
  ) throws {
    var data = data
    let resolved = try ResolvedBookmark(data: data, options: options, relativeTo: relative)

    if resolved.isStale {
      Logger.sandbox.log("Bookmark for file URL '\(resolved.url.pathString)' is stale: re-creating...")

      data = try create(resolved.url)
    }

    self.init(resolved: resolved, data: data)
  }

  public init(
    data: Data,
    options: URL.BookmarkResolutionOptions,
    relativeTo relative: URL?,
    create: (URL) async throws -> Data,
  ) async throws {
    var data = data
    let resolved = try ResolvedBookmark(data: data, options: options, relativeTo: relative)

    if resolved.isStale {
      Logger.sandbox.log("Bookmark for file URL '\(resolved.url.pathString)' is stale: re-creating...")

      data = try await create(resolved.url)
    }

    self.init(resolved: resolved, data: data)
  }
}

extension AssignedBookmark: Sendable {}

public struct AssignedBookmarkDocument {
  public let bookmark: AssignedBookmark
  public let relative: AssignedBookmark?

  public init(bookmark: AssignedBookmark, relative: AssignedBookmark?) {
    self.bookmark = bookmark
    self.relative = relative
  }
}

extension AssignedBookmarkDocument: Sendable {}
