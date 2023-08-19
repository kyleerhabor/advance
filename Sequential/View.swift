//
//  View.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/31/23.
//

import SwiftUI

extension NSWindow {
  func isFullScreened() -> Bool {
    self.styleMask.contains(.fullScreen)
  }
}

extension EdgeInsets {
  // Normally, NSTableView's style can just be set to .plain to take up the full size of the container. List, for some
  // reason, doesn't want to do that, so I have to do this little dance. I have no idea if this will transfer well to
  // other devices.
  static let listRow = Self(top: 0, leading: -8, bottom: 0, trailing: -9)

  init(_ insets: Double) {
    self.init(top: insets, leading: insets, bottom: insets, trailing: insets)
  }
}

extension Color {
  static let tertiaryFill = Self(nsColor: .tertiarySystemFill)
  static let secondaryFill = Self(nsColor: .secondarySystemFill)
}

extension KeyboardShortcut {
  static let finder = Self("r")
  static let currentImage = Self("l")
  static let open = Self("o")
  static let quicklook = Self("y")
  static let liveText = Self("t", modifiers: [.command, .control])
}
