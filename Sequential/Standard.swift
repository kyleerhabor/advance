//
//  Standard.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import OSLog

let bundleIdentifier = Bundle.main.bundleIdentifier!

extension Logger {
  static let ui = Self(subsystem: bundleIdentifier, category: "ui")
  static let model = Self(subsystem: bundleIdentifier, category: "model")
}
