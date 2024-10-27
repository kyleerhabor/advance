//
//  Bookmark.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/20/23.
//

import AdvanceCore
import Foundation
import OSLog

// MARK: - URL

protocol SecurityScope {
  associatedtype Scope

  func startSecurityScope() -> Scope

  func endSecurityScope(scope: Scope)

  func withSecurityScope<T>(_ body: () throws -> T) rethrows -> T

  func withSecurityScope<T>(_ body: () async throws -> T) async rethrows -> T
}

extension SecurityScope {
  func withSecurityScope<T>(_ body: () throws -> T) rethrows -> T {
    let scope = startSecurityScope()

    defer { endSecurityScope(scope: scope) }

    return try body()
  }

  func withSecurityScope<T>(_ body: () async throws -> T) async rethrows -> T {
    let scope = startSecurityScope()

    defer { endSecurityScope(scope: scope) }

    return try await body()
  }
}

extension URLSource: SecurityScope {
  func endSecurityScope(scope: Bool) {
    self.url.endSecurityScope(scope: scope)
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
    guard scope else {
      return
    }

    endSecurityScope()
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

extension URLBookmark: URLScope {
  func startSecurityScope() -> Bool {
    bookmark.options.contains(.withSecurityScope) && url.startSecurityScope()
  }

  func endSecurityScope(scope: Bool) {
    guard scope else {
      return
    }

    url.endSecurityScope()
  }
}
