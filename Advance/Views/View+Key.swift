//
//  View+Key.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/4/24.
//

import SwiftUI

// MARK: - Focus

struct NavigatorFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<UUID, (Navigator) -> Void>
}

extension FocusedValues {
  var navigator: NavigatorFocusedValueKey.Value? {
    get { self[NavigatorFocusedValueKey.self] }
    set { self[NavigatorFocusedValueKey.self] = newValue }
  }
}

// MARK: - Keyboard Shortcuts

extension KeyboardShortcut {
  static let navigatorImages = Self("1", modifiers: .command)
  static let navigatorBookmarks = Self("2", modifiers: .command)
}
