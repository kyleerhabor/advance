//
//  Window.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/11/24.
//

import AppKit
import Observation

@Observable
@MainActor
class Window {
  weak var window: NSWindow?
}

extension Window: @MainActor Equatable {
  static func ==(lhs: Window, rhs: Window) -> Bool {
    lhs.window == rhs.window
  }
}
