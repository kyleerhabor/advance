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
  static let file = Self(string: "file:")!
  static let rootDirectory = Self(string: "file:/")!
  static let liveTextDownsampledDirectory = Self.temporaryDirectory.appending(component: "Live Text Downsampled")

  var string: String {
    self.path(percentEncoded: false)
  }

  func bookmark(options: BookmarkCreationOptions, document: URL? = nil) throws -> Data {
    try self.bookmarkData(options: options, includingResourceValuesForKeys: [], relativeTo: document)
  }

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

  func isDirectory() throws -> Bool? {
    return try self.resourceValues(forKeys: [.isDirectoryKey]).isDirectory ?? false
  }

  func appending<S>(components: some BidirectionalCollection<S>) -> URL where S: StringProtocol {
    // Pretty gross (and a bad name, since no percent encoding is occurring.
    self.appending(path: components.joined(separator: "/"))
  }
}

extension URL: Comparable {
  public static func <(lhs: Self, rhs: Self) -> Bool {
    lhs.dataRepresentation.lexicographicallyPrecedes(rhs.dataRepresentation)
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

  func finderSort() -> [Element] where Element == URL {
    self.sorted { a, b in
      // First, we need to find a and b's common directory, then compare which one is a file or directory (since Finder
      // sorts folders first). Finally, if they're the same type, we do a localized standard comparison (the same Finder
      // applies when sorting by name) to sort by ascending order.
      //
      // In the future, it may be useful to extract the first two steps so the user can sort by some condition (e.g. date added)
      let ap = a.pathComponents
      let bp = b.pathComponents
      let (index, (ac, bc)) = zip(ap, bp).enumerated().first { _, pair in
        pair.0 != pair.1
      }!

      let count = index + 1

      if ap.count > count && bp.count == count {
        return true
      }

      if ap.count == count && bp.count > count {
        return false
      }

      return ac.localizedStandardCompare(bc) == .orderedAscending
    }
  }

  func find<Result>(_ body: (Element) -> Result?) -> Result? {
    for element in self {
      if let value = body(element) {
        return value
      }
    }

    return nil
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

extension FileManager {
  // This is partially coupled to the UI since it makes assumptions about how the iteration occurrs (limit and packages
  // as the two notable examples).
  func enumerate(at url: URL, hidden: Bool, subdirectories: Bool) throws -> [URL] {
    var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]

    if !hidden {
      options.insert(.skipsHiddenFiles)
    }

    if !subdirectories {
      options.insert(.skipsSubdirectoryDescendants)
    }

    guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: options) else {
      return []
    }

    return try enumerator.compactMap { element -> URL? in
      guard let url = element as? URL else {
        return nil
      }

      let resource = try url.resourceValues(forKeys: [.isDirectoryKey])

      guard resource.isDirectory == true else {
        return url
      }

      return nil
    }
  }
}

extension URL.BookmarkCreationOptions {
  static let withReadOnlySecurityScope = Self([.withSecurityScope, .securityScopeAllowOnlyReadAccess])
}

extension Comparable {
  func clamp(to range: ClosedRange<Self>) -> Self {
    Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
  }
}

struct Matcher<Item, Path, Transform> where Item: Equatable, Path: Sequence<Item?> {
  typealias Items = Sequence<Item>

  let path: Path
  let transform: ([Item]) -> Transform

  func match(items: some Items) -> Transform? {
    guard let matches = Self.match(path: self.path, items: items) else {
      return nil
    }

    return transform(matches)
  }

  static func match(path: Path, items: some Items) -> [Item]? {
    let paths = zip(items, path)
    let satisfied = paths.allSatisfy { (component, path) in
      if let path {
        return component == path
      }

      return true
    }

    guard satisfied else {
      return nil
    }

    return paths.filter { (_, path) in path == nil }.map(\.0)
  }
}

extension Matcher where Item == String, Path == [String?], Transform == URL {
  typealias URLItems = BidirectionalCollection<Item>

  static let home = Matcher(path: ["/", "Users", nil]) { _ in URL.rootDirectory }
  static let trash = Matcher(path: ["/", "Users", nil, ".Trash"]) { matches in
    URL.rootDirectory.appending(components: "Users", matches.first!, "Trash")
  }

  static let volumeTrash = Matcher(path: ["/", "Volumes", nil, ".Trashes", nil]) { matched in
    URL.rootDirectory.appending(components: "Volumes", matched.first!, "Trash")
  }

  static let volume = Matcher(path: ["/", "Volumes", nil]) { _ in URL.rootDirectory }

  func match(items: some URLItems) -> Transform? {
    if let matches = Self.match(path: path, items: items) {
      return self
        .transform(matches)
        .appending(components: items.dropFirst(self.path.count))
    }

    return nil
  }
}
