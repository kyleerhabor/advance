//
//  Standard.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import OSLog

extension Bundle {
  static let identifier = Bundle.main.bundleIdentifier!
}

extension Logger {
  static let ui = Self(subsystem: Bundle.identifier, category: "ui")
  static let model = Self(subsystem: Bundle.identifier, category: "model")
}

extension URL {
  // "/", without a scheme, doesn't represent anything, in of itself. In the context of a file system, it does
  // represent the root directory, but we're using this in SwiftUI's .navigationDocument(_:) modifier, so it just looks
  // like a generic file.
  static let blank = Self(string: "/")!

  func fileRepresentation() -> String? {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      return nil
    }

    components.scheme = nil

    return components.url?.absoluteString.removingPercentEncoding
  }

  func scoped<T>(_ body: () throws -> T) throws -> T {
    guard self.startAccessingSecurityScopedResource() else {
      throw URLError.inaccessibleSecurityScope
    }

    defer {
      self.stopAccessingSecurityScopedResource()
    }

    return try body()
  }

  func bookmark() throws -> Data {
    try self.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
  }
}

extension Sequence {
  func ordered(by array: [Element], for keyPath: KeyPath<Element, some Hashable>) -> [Element] where Element: Hashable {
    let index = array.enumerated().reduce(into: [:]) { partialResult, pair in
      partialResult[pair.1[keyPath: keyPath]] = pair.0
    }

    return self.sorted { a, b in
      guard let ai = index[a[keyPath: keyPath]] else {
        return false
      }

      guard let bi = index[b[keyPath: keyPath]] else {
        return true
      }
      return ai < bi
    }
  }

  // These functions should only be used for bodies that execute very quickly (to prevent task explosion).

  func perform(_ body: @escaping (Element) async -> Void) async {
    await withDiscardingTaskGroup { group in
      self.forEach { element in
        group.addTask {
          await body(element)
        }
      }
    }
  }

  func perform(_ body: @escaping (Element) async throws -> Void) async throws {
    try await withThrowingDiscardingTaskGroup { group in
      self.forEach { element in
        group.addTask {
          try await body(element)
        }
      }
    }
  }
}

extension CGSize {
  func length() -> Double {
    max(self.width, self.height)
  }
}
