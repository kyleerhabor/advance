//
//  Standard.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/23.
//

import AdvanceCore
@preconcurrency import BigInt
import AdvanceData
import Foundation

// MARK: - Files

extension URL {
  #if DEBUG
  static let dataDirectory = Self.applicationSupportDirectory.appending(
    components: Bundle.appID, "DebugData",
    directoryHint: .isDirectory,
  )

  #else
  static let dataDirectory = Self.applicationSupportDirectory.appending(
    components: Bundle.appID, "Data",
    directoryHint: .isDirectory,
  )

  #endif

  // homeDirectory returns the home directory relative to App Sandbox. This returns the real user directory.
  static let userDirectory = Self(
    // https://stackoverflow.com/a/46789483
    fileURLWithFileSystemRepresentation: getpwuid(getuid()).pointee.pw_dir!,
    isDirectory: true,
    relativeTo: nil
  )

  var lastPath: String {
    self.deletingPathExtension().lastPathComponent
  }

  func isDirectory() -> Bool? {
    try? self.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
  }

  func contains(url: Self) -> Bool {
    let lhs = self.pathComponents
    let rhs = url.pathComponents

    return ArraySlice(lhs) == rhs.prefix(upTo: min(rhs.count, lhs.count))
  }
}

extension UserDefaults {
  static var `default`: Self {
    let suiteName: String?

    #if DEBUG
    suiteName = nil

    #else
    suiteName = "\(Bundle.appID).Debug"

    #endif

    return Self(suiteName: suiteName)!
  }
}

extension FileManager {
  func creatingDirectories<T>(at url: URL, code: CocoaError.Code, body: () throws -> T) rethrows -> T {
    do {
      return try body()
    } catch let err as CocoaError where err.code == code {
      try self.createDirectory(at: url, withIntermediateDirectories: true)

      return try body()
    }
  }
}

extension FileManager.DirectoryEnumerator {
  func contents() -> [URL] {
    self.compactMap { element -> URL? in
      guard let url = element as? URL,
            url.isDirectory() == false else {
        return nil
      }

      return url
    }
  }
}

// MARK: - Collections

struct Pair<Left, Right> {
  let left: Left
  let right: Right
}

extension Pair: Sendable where Left: Sendable, Right: Sendable {}

extension Pair: Equatable where Left: Equatable, Right: Equatable {}

enum Match {
  case any,
       string(String)

  static let root = Self.string("/")
}

struct Matcher {
  let components: [Match]
  let transform: ([String]) -> [String]

  // The location provided by URL/FileManager/etc. may differ across OS versions and environments (for example, App
  // Sandbox redefines several locations for the app's protected directory). For this reason, components are explicitly
  // defined.

  // /Users/[user]/[...] -> /[...]
  static func user(named name: String) -> Self {
    Self(components: [.root, .string("Users"), .string(name), .any]) { components in
      let root = components[0..<1]
      let rest = components[3...]

      return Array(root + rest)
    }
  }

  // ~/.Trash -> ~/Trash
  static var userTrash: Self {
    Self(components: [.root, .string("Users"), .any, .string(".Trash")]) { components in
      var result = [String](reservingCapacity: components.count)
      result.append(contentsOf: components[0..<3])
      result.append("Trash")
      result.append(contentsOf: components[4...])

      return result
    }
  }

  // ~/Library/Containers/[...]/Data -> ~/Advance
  static func appSandbox(bundleID: String) -> Self {
    let userComponents: [Match] = [.string("Users"), .any]
    let containerComponents: [Match] = [
      .string("Library"),
      .string("Containers"),
      // I'd prefer for this matcher to operate on any application's App Sandbox, but that would likely involve loading
      // foreign bundles, significantly increasing its complexity.
      .string(bundleID),
      .string("Data")
    ]

    let matches = [[Match.root], userComponents, containerComponents].flatMap(identity)

    return Self(components: matches) { components in
      // The last increment is for "Advance".
      var results = [String](reservingCapacity: components.count - containerComponents.count + 1)
      results.append(contentsOf: components.prefix(1 + userComponents.count))
      // TODO: Localize.
      results.append("Advance")
      results.append(contentsOf: components.suffix(components.count - containerComponents.count - userComponents.count - 1))

      return results
    }
  }

  // /Volumes/[volume]/[...] -> /[...]
  static var volume: Self {
    Self(components: [.root, .string("Volumes"), .any, .any]) { components in
      let root = components[0..<1]
      let rest = components[3...]

      return Array(root + rest)
    }
  }

  // /Volumes/[...]/.Trashes/[uid] -> /Volumes/[volume]/Trash
  static var volumeTrash: Self {
    Self(components: [.root, .string("Volumes"), .any, .string(".Trashes"), .any]) { components in
      var results = [String](reservingCapacity: components.count.decremented())
      results.append(contentsOf: components[0..<3])
      results.append("Trash")
      results.append(contentsOf: components[5...])

      return results
    }
  }

  func match(on components: [String]) -> [String] {
    guard self.components.count <= components.count else {
      return components
    }

    let satisfied = zip(self.components, components).allSatisfy { (match, component) in
      switch match {
        case .any: true
        case let .string(s): s == component
      }
    }

    guard satisfied else {
      return components
    }

    return self.transform(components)
  }
}

// https://www.swiftbysundell.com/articles/the-power-of-key-paths-in-swift/
func setter<Object, Value>(
  on keyPath: WritableKeyPath<Object, Value>,
  value: Value
) -> (inout Object) -> Void {
  { object in
    object[keyPath: keyPath] = value
  }
}

func setter<Object: AnyObject, Value>(
  on keyPath: ReferenceWritableKeyPath<Object, Value>,
  value: Value
) -> (Object) -> Void {
  { object in
    object[keyPath: keyPath] = value
  }
}
