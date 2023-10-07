//
//  View.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/31/23.
//

import SwiftUI

extension NSWindow {
  func isFullScreen() -> Bool {
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

  init(vertical: Double, horizontal: Double) {
    self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
  }

  init(horizontal: Double, top: Double, bottom: Double) {
    self.init(top: top, leading: horizontal, bottom: bottom, trailing: horizontal)
  }
}

extension Color {
  static let secondaryFill = Self(nsColor: .secondarySystemFill)
  static let tertiaryLabel = Self(nsColor: .tertiaryLabelColor)
  static let tertiaryFill = Self(nsColor: .tertiarySystemFill)
}

extension KeyboardShortcut {
  static let open = Self("o")
  static let finder = Self("r")
  static let quicklook = Self("y")
  static let bookmark = Self("d")
  static let liveTextIcon = Self("t")
  static let fullScreen = Self("f", modifiers: [.command, .control])
  static let jumpToCurrentImage = Self("l")
}

@resultBuilder
struct TextBuilder {
  static let blank = Text(verbatim: "")
  static let spacer = Text(verbatim: " ")

  static func buildBlock(_ components: Text...) -> Text {
    components
      .map { [$0] }
      .joined(separator: [spacer])
      .reduce(blank, +)
  }

  static func buildEither(first component: Text) -> Text {
    component
  }

  static func buildEither(second component: Text) -> Text {
    component
  }
}

extension NSEvent.ModifierFlags {
  static let primary: Self = [.command, .shift, .option, .control]
}

extension View {
  func visible(_ visible: Bool) -> some View {
    self.opacity(visible ? 1 : 0)
  }
}
