//
//  Standard.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import AppKit
import OSLog
import UniformTypeIdentifiers

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
  static let nullDevice = Self(string: "file:/dev/null")!

  var string: String {
    let absolute = self.absoluteString

    return absolute.removingPercentEncoding ?? absolute
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

  func removingDuplicates() -> [Element] where Element: Hashable {
    var seen = Set<Element>()

    return self.filter { element in
      if seen.contains(element) {
        return false
      }

      seen.insert(element)

      return true
    }
  }
}

extension CGSize {
  func length() -> Double {
    max(self.width, self.height)
  }
}

extension NSPasteboard {
  func write(items: [some NSPasteboardWriting]) -> Bool {
    self.prepareForNewContents()

    return self.writeObjects(items)
  }
}

struct Execution<T> {
  let duration: Duration
  let value: T
}

// This should be used sparingly, given Instruments provides more insight.
func time<T>(
  _ body: () async throws -> T
) async rethrows -> Execution<T> {
  var result: T?

  let duration = try await ContinuousClock.continuous.measure {
    result = try await body()
  }

  return .init(
    duration: duration,
    value: result!
  )
}

func noop() {}

extension UTType {
  static let avif = Self(importedAs: "public.avif")
}

extension Double {
  public init(_ source: Bool) {
    self.init(source ? 1 : 0)
  }
}
