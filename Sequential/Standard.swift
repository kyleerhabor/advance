//
//  Standard.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import Foundation
import os

let bundleIdentifier = Bundle.main.bundleIdentifier!

extension Logger {
  // Maybe rename to initial?
  static let startup = Self(subsystem: bundleIdentifier, category: "init")
  static let ui = Self(subsystem: bundleIdentifier, category: "ui")
  static let model = Self(subsystem: bundleIdentifier, category: "model")
}
