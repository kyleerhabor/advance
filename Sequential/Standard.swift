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
  func forEach(_ body: (Element) async throws -> Void) async rethrows {
    for element in self {
      try await body(element)
    }
  }

  func map<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
    var result = [T]()

    try await forEach { element in
      result.append(try await transform(element))
    }

    return result
  }

  func ordered(by array: [Element]) -> [Element] where Element: Hashable {
    let index = array.enumerated().reduce(into: [:]) { partialResult, pair in
      partialResult[pair.1] = pair.0
    }

    return self.sorted { a, b in
      guard let ai = index[a] else {
        return false
      }

      guard let bi = index[b] else {
        return true
      }

      return ai < bi
    }
  }
}

extension CGSize {
  func length() -> Double {
    max(self.width, self.height)
  }
}
