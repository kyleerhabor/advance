//
//  Standard.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import AppKit
import ImageIO
import OSLog
import UniformTypeIdentifiers

extension Bundle {
  static let identifier = Bundle.main.bundleIdentifier!
}

extension Logger {
  static let ui = Self(subsystem: Bundle.identifier, category: "UI")
  static let model = Self(subsystem: Bundle.identifier, category: "Model")
  static let startup = Self(subsystem: Bundle.identifier, category: "Initialization")
  static let livetext = Self(subsystem: Bundle.identifier, category: "LiveText")
}

extension URL {
  static let liveTextDownsampledDirectory = Self.temporaryDirectory.appending(component: "Live Text Downsampled")

  var string: String {
    self.path(percentEncoded: false)
  }

  func scoped<T>(_ body: () throws -> T) throws -> T {
    guard self.startAccessingSecurityScopedResource() else {
      Logger.model.info("Could not access security scope for URL \"\(self.string)\"")

      throw URLError.inaccessibleSecurityScope
    }

    defer {
      self.stopAccessingSecurityScopedResource()
    }

    return try body()
  }

  func scoped<T>(_ body: () async throws -> T) async throws -> T {
    guard self.startAccessingSecurityScopedResource() else {
      throw URLError.inaccessibleSecurityScope
    }

    defer {
      self.stopAccessingSecurityScopedResource()
    }

    return try await body()
  }

  func bookmark(options: BookmarkCreationOptions = [.withSecurityScope, .securityScopeAllowOnlyReadAccess]) throws -> Data {
    try self.bookmarkData(options: options)
  }
}

extension Sequence {
  func sorted<T>(byOrderOf source: some Sequence<T>, transform: (Element) -> T) -> [Element] where T: Hashable {
    let index = source.enumerated().reduce(into: [:]) { partialResult, pair in
      partialResult[pair.element] = pair.offset
    }

    return self.sorted { a, b in
      guard let ai = index[transform(a)] else {
        return false
      }

      guard let bi = index[transform(b)] else {
        return true
      }

      return ai < bi
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

  func filter<T>(in set: Set<T>, by value: (Element) -> T) -> [Element] {
    self.filter { set.contains(value($0)) }
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

extension Double {
  public init(_ source: Bool) {
    self.init(source ? 1 : 0)
  }
}

struct ResolvedBookmark {
  let url: URL
  let stale: Bool
}

extension ResolvedBookmark {
  init(from data: Data) throws {
    var stale = false

    self.url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &stale)
    self.stale = stale
  }
}

extension RandomAccessCollection {
  var isMany: Bool {
    self.count > 1
  }
}


