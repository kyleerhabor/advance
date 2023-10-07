//
//  Standard.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import AppKit
import OSLog
import UniformTypeIdentifiers

typealias Offset<T> = (offset: Int, element: T)

extension Bundle {
  static let identifier = Bundle.main.bundleIdentifier!
}

extension Logger {
  static let ui = Self(subsystem: Bundle.identifier, category: "UI")
  static let model = Self(subsystem: Bundle.identifier, category: "Model")
  static let startup = Self(subsystem: Bundle.identifier, category: "Initialization")
  static let livetext = Self(subsystem: Bundle.identifier, category: "LiveText")
  static let sandbox = Self(subsystem: Bundle.identifier, category: "Sandbox")
}

extension URL {
  static let none = Self(string: "file:")!
  static let liveTextDownsampledDirectory = Self.temporaryDirectory.appending(component: "Live Text Downsampled")

  var string: String {
    self.path(percentEncoded: false)
  }

  func bookmark(options: BookmarkCreationOptions, document: URL? = nil) throws -> Data {
    try self.bookmarkData(options: options, includingResourceValuesForKeys: [], relativeTo: document)
  }

  func scoped<T>(_ body: () throws -> T) rethrows -> T {
    let accessing = self.startAccessingSecurityScopedResource()

    if accessing {
      Logger.sandbox.debug("Started security scope for URL \"\(self.string)\"")
    } else {
      Logger.sandbox.info("Tried to start security scope for URL \"\(self.string)\", but scope was inaccessible")
    }

    defer {
      if accessing {
        self.stopAccessingSecurityScopedResource()

        Logger.sandbox.debug("Ended security scope for URL \"\(self.string)\"")
      }
    }

    return try body()
  }

  func scoped<T>(_ body: () async throws -> T) async rethrows -> T {
    let accessing = self.startAccessingSecurityScopedResource()

    if accessing {
      Logger.sandbox.debug("Started security scope for URL \"\(self.string)\"")
    } else {
      Logger.sandbox.info("Tried to start security scope for URL \"\(self.string)\", but scope was inaccessible")
    }

    defer {
      if accessing {
        self.stopAccessingSecurityScopedResource()

        Logger.sandbox.debug("Ended security scope for URL \"\(self.string)\"")
      }
    }

    return try await body()
  }

  func isDirectory() throws -> Bool? {
    return try self.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
  }
}

extension Sequence {
  func ordered<T>() -> [T] where Element == Offset<T> {
    self
      .sorted { $0.offset < $1.offset }
      .map(\.element)
  }

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

extension RandomAccessCollection {
  var isMany: Bool {
    self.count > 1
  }
}

extension Set {
  var isMany: Bool {
    self.count > 1
  }
}

extension NSItemProvider {
  func resolve(_ type: UTType) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      self.loadInPlaceFileRepresentation(forTypeIdentifier: type.identifier) { url, inPlace, err in
        if let err {
          continuation.resume(throwing: err)

          return
        }

        if let url {
          // Note that when this happens, the image is copied to ~/Library/Containers/<sandbox>/Data/Library/Caches.
          // We most likely want to allow the user to clear this data (in case it becomes excessive).
          if !inPlace {
            Logger.model.info("URL from dragged image \"\(url.string)\" is a local copy")
          }

          continuation.resume(returning: url)

          return
        }

        fatalError()
      }
    }
  }
}

struct EnumeratedURL {
  let url: URL
  let resources: URLResourceValues
}

extension FileManager {
  func enumerate(
    at url: URL,
    properties: [URLResourceKey],
    include: (URL, DirectoryEnumerator) throws -> Bool
  ) rethrows -> [URL] {
    guard let enumerator = self.enumerator(at: url, includingPropertiesForKeys: properties) else {
      return []
    }

    var urls = [URL]()

    for case let url as URL in enumerator {
      if try include(url, enumerator) {
        urls.append(url)
      }
    }

    return urls
  }

  func enumerate(at url: URL) throws -> [URL] {
    try enumerate(at: url, properties: [.isDirectoryKey]) { url, enumerator in
      return try url.isDirectory() != true
    }
  }

  func enumerate(at url: URL, maxLevel: Int) throws -> [URL] {
    try enumerate(at: url, properties: [.isDirectoryKey]) { url, enumerator in
      guard try url.isDirectory() == true else {
        return true
      }

      if enumerator.level >= maxLevel {
        enumerator.skipDescendants()
      }

      return false
    }
  }
}

extension URL.BookmarkCreationOptions {
  static let withReadOnlySecurityScope = Self([.withSecurityScope, .securityScopeAllowOnlyReadAccess])
}
