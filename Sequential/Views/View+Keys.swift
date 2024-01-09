//
//  View+Keys.swift
//  Sequential
//
//  Created by Kyle Erhabor on 1/4/24.
//

import SwiftUI

// The image collection view has a sidebar and detail scroller that can be invoked from diverging sections of the view
// hierarchy (the sidebar scrolling detail and detail scrolling the sidebar). To support this, we use focused values to
// pass the actions up the view hierarchy, and then environment values for the descending views to access. The reason
// we can't just rely on focus values is because SwiftUI does not behave appropriately when the two are trying to access
// each other. I presume it's causing a dependency cycle that's implicitly broken by SwiftUI; but routing the values up
// to the image collection so they can be swapped does work.
struct Scroller<I, Item> where I: Equatable {
  typealias Scroll = (Item) -> Void

  let identity: I
  let scroll: Scroll
}

extension Scroller: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identity == rhs.identity
  }
}

enum ScrollerIdentity: Equatable {
  case sidebar, detail
  // Since identity is determined by the case, we need to handle the initial case where SwiftUI is initializing views.
  case unknown
}

struct SidebarScrollerItem {
  let id: ImageCollectionItemImage.ID
  let completion: () -> Void
}

// MARK: - Environment

struct LoadedEnvironmentKey: EnvironmentKey {
  static var defaultValue = false
}

struct NavigationColumnsEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(NavigationSplitViewVisibility.automatic)
}

struct SidebarScrollerFocusedValueKey: FocusedValueKey {
  typealias Value = Scroller<ScrollerIdentity, SidebarScrollerItem>
}

struct DetailScrollerFocusedValueKey: FocusedValueKey {
  typealias Value = Scroller<ScrollerIdentity, ImageCollectionItemImage.ID>
}

extension EnvironmentValues {
  var loaded: LoadedEnvironmentKey.Value {
    get { self[LoadedEnvironmentKey.self] }
    set { self[LoadedEnvironmentKey.self] = newValue }
  }

  var navigationColumns: NavigationColumnsEnvironmentKey.Value {
    get { self[NavigationColumnsEnvironmentKey.self] }
    set { self[NavigationColumnsEnvironmentKey.self] = newValue }
  }

  var sidebarScroller: SidebarScrollerEnvironmentKey.Value {
    get { self[SidebarScrollerEnvironmentKey.self] }
    set { self[SidebarScrollerEnvironmentKey.self] = newValue }
  }

  var detailScroller: DetailScrollerEnvironmentKey.Value {
    get { self[DetailScrollerEnvironmentKey.self] }
    set { self[DetailScrollerEnvironmentKey.self] = newValue }
  }
}

// MARK: - Focus

struct AppMenu<I> where I: Equatable {
  let identity: I
  let action: () -> Void
}

extension AppMenu: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identity == rhs.identity
  }
}

struct AppMenuToggle<I> where I: Equatable {
  let enabled: Bool
  let state: Bool
  let menu: AppMenu<I>
}

extension AppMenuToggle: Equatable {}

struct SearchSidebarFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenu<Bool>
}

struct LiveTextIconFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggle<Bool>
}

struct LiveTextHighlightFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggle<[ImageCollectionItemImage]>
}

struct SidebarScrollerEnvironmentKey: EnvironmentKey {
  static var defaultValue = SidebarScrollerFocusedValueKey.Value(identity: .sidebar, scroll: noop)
}

struct DetailScrollerEnvironmentKey: EnvironmentKey {
  static var defaultValue = DetailScrollerFocusedValueKey.Value(identity: .detail, scroll: noop)
}

extension FocusedValues {
  var searchSidebar: SearchSidebarFocusedValueKey.Value? {
    get { self[SearchSidebarFocusedValueKey.self] }
    set { self[SearchSidebarFocusedValueKey.self] = newValue }
  }

  var liveTextIcon: LiveTextIconFocusedValueKey.Value? {
    get { self[LiveTextIconFocusedValueKey.self] }
    set { self[LiveTextIconFocusedValueKey.self] = newValue }
  }

  var liveTextHighlight: LiveTextHighlightFocusedValueKey.Value? {
    get { self[LiveTextHighlightFocusedValueKey.self] }
    set { self[LiveTextHighlightFocusedValueKey.self] = newValue }
  }

  var sidebarScroller: SidebarScrollerFocusedValueKey.Value? {
    get { self[SidebarScrollerFocusedValueKey.self] }
    set { self[SidebarScrollerFocusedValueKey.self] = newValue }
  }

  var detailScroller: DetailScrollerFocusedValueKey.Value? {
    get { self[DetailScrollerFocusedValueKey.self] }
    set { self[DetailScrollerFocusedValueKey.self] = newValue }
  }
}

// MARK: - Keyboard Shortcuts
extension KeyboardShortcut {
  static let searchSidebar = Self("f", modifiers: .command)
  static let jumpToCurrentImage = Self("l", modifiers: .command)

  static let bookmark = Self("d")

  static let liveTextIcon = Self("t", modifiers: .command)
  // Command-T toggles the icon, so Command-Shift-T toggles the highlight. A pretty useful feature to see what matched
  // without reaching for the mouse.
  static let liveTextHighlight = Self("t", modifiers: [.command, .shift])

  static let resetWindowSize = Self("r", modifiers: [.command, .control])
}
