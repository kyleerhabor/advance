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

struct SidebarSearchFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuActionItem<UUID?>
}

struct LiveTextHighlightFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggleItem<[ImageCollectionItemImage.ID]>
}

extension FocusedValues {
  var navigator: NavigatorFocusedValueKey.Value? {
    get { self[NavigatorFocusedValueKey.self] }
    set { self[NavigatorFocusedValueKey.self] = newValue }
  }

  var sidebarSearch: SidebarSearchFocusedValueKey.Value? {
    get { self[SidebarSearchFocusedValueKey.self] }
    set { self[SidebarSearchFocusedValueKey.self] = newValue }
  }

  var liveTextHighlight: LiveTextHighlightFocusedValueKey.Value? {
    get { self[LiveTextHighlightFocusedValueKey.self] }
    set { self[LiveTextHighlightFocusedValueKey.self] = newValue }
  }
}

// MARK: - Keyboard Shortcuts
extension KeyboardShortcut {
  static let navigatorImages = Self("1", modifiers: .command)
  static let navigatorBookmarks = Self("2", modifiers: .command)

  static let searchSidebar = Self("f", modifiers: .command)
}
