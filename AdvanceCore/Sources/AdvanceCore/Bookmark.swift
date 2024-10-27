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
      Logger.sandbox.debug("Started security scope for URL \"\(self.pathString)\"")
    } else {
      Logger.sandbox.info("Tried to start security scope for URL \"\(self.pathString)\", but scope was inaccessible")
    }

    return accessing
  }

  public func endSecurityScope() {
    self.stopAccessingSecurityScopedResource()

    Logger.sandbox.debug("Ended security scope for URL \"\(self.pathString)\"")
  }
}

extension URL.BookmarkCreationOptions {
  public static let withReadOnlySecurityScope = Self([.withSecurityScope, .securityScopeAllowOnlyReadAccess])
}

extension URL.BookmarkCreationOptions: Codable {}

public protocol SecurityScopedResource {
  associatedtype Scope

  func startSecurityScope() -> Scope

  func endSecurityScope(_ scope: Scope)
}

extension SecurityScopedResource {
  public func accessingSecurityScopedResource<T, Failure>(_ body: () throws(Failure) -> T) throws(Failure) -> T {
    let scope = startSecurityScope()

    defer {
      endSecurityScope(scope)
    }

    return try body()
  }

  public func accessingSecurityScopedResource<T, Failure>(
    _ body: @isolated(any) () async throws(Failure) -> T
  ) async throws(Failure) -> T where T: Sendable {
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

extension URLSource: SecurityScopedResource {
  public func startSecurityScope() -> Bool {
    options.contains(.withSecurityScope) && url.startSecurityScope()
  }

  public func endSecurityScope(_ scope: Bool) {
    url.endSecurityScope(scope)
  }
}

extension URLSource: Sendable {}

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
  public struct Scope {
    let source: URLSource.Scope
    let relative: URLSource.Scope?
  }

  public func startSecurityScope() -> Scope {
    let relative = relative?.startSecurityScope()
    let source = source.startSecurityScope()

    return Scope(source: source, relative: relative)
  }

  public func endSecurityScope(_ scope: Scope) {
    source.endSecurityScope(scope.source)

    if let scope = scope.relative {
      relative?.endSecurityScope(scope)
    }
  }
}

public struct Bookmark {
  public let data: Data
  public let options: URL.BookmarkCreationOptions

  public init(data: Data, options: URL.BookmarkCreationOptions) {
    self.data = data
    self.options = options
  }
}

extension Bookmark {
  public init(url: URL, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    self.init(
      data: try url.bookmark(options: options, relativeTo: relative),
      options: options
    )
  }
}

extension Bookmark: Sendable, Codable {}

public struct ResolvedBookmark {
  public let url: URL
  public let isStale: Bool

  public init(url: URL, isStale: Bool) {
    self.url = url
    self.isStale = isStale
  }
}

extension ResolvedBookmark {
  public init(data: Data, options: URL.BookmarkResolutionOptions, relativeTo relative: URL?) throws {
    var isStale = false

    self.url = try URL(resolvingBookmarkData: data, options: options, relativeTo: relative, bookmarkDataIsStale: &isStale)
    self.isStale = isStale
  }
}

extension ResolvedBookmark: Sendable {}

// https://english.stackexchange.com/a/227919
public struct AssignedBookmark {
  public let url: URL
  public let data: Data

  public init(url: URL, data: Data) {
    self.url = url
    self.data = data
  }
}

extension AssignedBookmark {
  public init(
    data: Data,
    options: URL.BookmarkResolutionOptions,
    relativeTo relative: URL?,
    creating create: (URL) throws -> Data
  ) throws {
    var data = data
    let resolved = try ResolvedBookmark(data: data, options: options, relativeTo: relative)

    if resolved.isStale {
      Logger.sandbox.info("Bookmark for URL \"\(resolved.url.pathString)\" is stale; recreating...")

      data = try create(resolved.url)
    }

    self.init(url: resolved.url, data: data)
  }
}

extension AssignedBookmark: Sendable {}

// MARK: - Convenience

public struct URLBookmark {
  public let url: URL
  public let bookmark: Bookmark

  public init(url: URL, bookmark: Bookmark) {
    self.url = url
    self.bookmark = bookmark
  }
}

extension URLBookmark {
  public init(url: URL, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    self.init(
      url: url,
      bookmark: try Bookmark(url: url, options: options, relativeTo: relative)
    )
  }
}

extension URLBookmark: Sendable, Codable {}
