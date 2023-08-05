//
//  View.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/31/23.
//

import AppKit

extension NSWindow {
  func isFullScreened() -> Bool {
    self.styleMask.contains(.fullScreen)
  }
}
