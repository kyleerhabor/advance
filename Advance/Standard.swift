//
//  Standard.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/23.
//

import Foundation

// MARK: - Files

extension URL {
  var lastPath: String {
    self.deletingPathExtension().lastPathComponent
  }
}

// MARK: - Collections

struct Pair<Left, Right> {
  let left: Left
  let right: Right
}

extension Pair: Sendable where Left: Sendable, Right: Sendable {}

extension Pair: Equatable where Left: Equatable, Right: Equatable {}
