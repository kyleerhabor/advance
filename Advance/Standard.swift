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
