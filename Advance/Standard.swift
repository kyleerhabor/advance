//
//  Standard.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/23.
//

import AdvanceCore
@preconcurrency import BigInt
import Foundation

// MARK: - Files

extension URL {
  var lastPath: String {
    self.deletingPathExtension().lastPathComponent
  }

  func isDirectory() -> Bool? {
    try? self.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
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
