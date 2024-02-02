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

struct SidebarScrollerEnvironmentKey: EnvironmentKey {
  static var defaultValue = SidebarScrollerFocusedValueKey.Value(identity: .sidebar, scroll: noop)
}

struct DetailScrollerEnvironmentKey: EnvironmentKey {
  static var defaultValue = DetailScrollerFocusedValueKey.Value(identity: .detail, scroll: noop)
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

struct AppMenuItemAction<I> where I: Equatable {
  typealias Action = () -> Void

  let identity: I
  let action: Action

  func callAsFunction() {
    action()
  }
}

extension AppMenuItemAction: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identity == rhs.identity
  }
}

struct AppMenuItem<I> where I: Equatable {
  typealias Action = AppMenuItemAction<I>

  let enabled: Bool
  let action: Action

  func callAsFunction() {
    action()
  }
}

extension AppMenuItem {
  init(identity: I, enabled: Bool, action: @escaping Action.Action) {
    self.init(enabled: enabled, action: .init(identity: identity, action: action))
  }
}

extension AppMenuItem: Equatable {}

struct AppMenuToggleItem<I> where I: Equatable {
  typealias Item = AppMenuItem<I>

  let state: Bool
  let item: Item
}

extension AppMenuToggleItem {
  init(identity: I, enabled: Bool, state: Bool, action: @escaping Item.Action.Action) {
    self.init(state: state, item: .init(identity: identity, enabled: enabled, action: action))
  }
}

extension AppMenuToggleItem: Equatable {}

struct ShowFinderFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionSidebar.Selection>
}

struct OpenFinderFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<SettingsCopyingView.Selection>
}

struct BackFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionItemImage.ID?>
}

struct BackAllFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionItemImage.ID?>
}

struct ForwardFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionItemImage.ID?>
}

struct ForwardAllFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionItemImage.ID?>
}

struct LiveTextHighlightFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggleItem<[ImageCollectionItemImage]>
}

// MARK: - Focus (legacy)

struct AppMenuAction<I, A> where I: Equatable {
  let identity: I
  let action: A
}

extension AppMenuAction: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identity == rhs.identity
  }
}

typealias AppMenu<I> = AppMenuAction<I, () -> Void> where I: Equatable

struct AppMenuToggle<I> where I: Equatable {
  let enabled: Bool
  let state: Bool
  let menu: AppMenu<I>
}

extension AppMenuToggle: Equatable {}

struct SearchSidebarFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenu<ImageCollectionEnvironmentKey.Value>
}

struct LiveTextIconFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggle<Bool>
}

// MARK: - Focus (continued)

extension FocusedValues {
  var showFinder: ShowFinderFocusedValueKey.Value? {
    get { self[ShowFinderFocusedValueKey.self] }
    set { self[ShowFinderFocusedValueKey.self] = newValue }
  }

  var openFinder: OpenFinderFocusedValueKey.Value? {
    get { self[OpenFinderFocusedValueKey.self] }
    set { self[OpenFinderFocusedValueKey.self] = newValue }
  }

  var back: BackFocusedValueKey.Value? {
    get { self[BackFocusedValueKey.self] }
    set { self[BackFocusedValueKey.self] = newValue }
  }

  var backAll: BackAllFocusedValueKey.Value? {
    get { self[BackAllFocusedValueKey.self] }
    set { self[BackAllFocusedValueKey.self] = newValue }
  }

  var forward: ForwardFocusedValueKey.Value? {
    get { self[ForwardFocusedValueKey.self] }
    set { self[ForwardFocusedValueKey.self] = newValue }
  }

  var forwardAll: ForwardAllFocusedValueKey.Value? {
    get { self[ForwardAllFocusedValueKey.self] }
    set { self[ForwardAllFocusedValueKey.self] = newValue }
  }

  var searchSidebar: SearchSidebarFocusedValueKey.Value? {
    get { self[SearchSidebarFocusedValueKey.self] }
    set { self[SearchSidebarFocusedValueKey.self] = newValue }
  }

  var sidebarScroller: SidebarScrollerFocusedValueKey.Value? {
    get { self[SidebarScrollerFocusedValueKey.self] }
    set { self[SidebarScrollerFocusedValueKey.self] = newValue }
  }

  var detailScroller: DetailScrollerFocusedValueKey.Value? {
    get { self[DetailScrollerFocusedValueKey.self] }
    set { self[DetailScrollerFocusedValueKey.self] = newValue }
  }

  var liveTextIcon: LiveTextIconFocusedValueKey.Value? {
    get { self[LiveTextIconFocusedValueKey.self] }
    set { self[LiveTextIconFocusedValueKey.self] = newValue }
  }

  var liveTextHighlight: LiveTextHighlightFocusedValueKey.Value? {
    get { self[LiveTextHighlightFocusedValueKey.self] }
    set { self[LiveTextHighlightFocusedValueKey.self] = newValue }
  }
}

// MARK: - Keyboard Shortcuts
extension KeyboardShortcut {
  static let showFinder = Self("r", modifiers: .command)
  static let openFinder = Self("r", modifiers: [.command, .option])

  static let back = Self("[", modifiers: .command)
  static let backAll = Self("[", modifiers: [.command, .option])
  static let forward = Self("]", modifiers: .command)
  static let forwardAll = Self("]", modifiers: [.command, .option])

  static let searchSidebar = Self("f", modifiers: .command)
  static let jumpToCurrentImage = Self("l", modifiers: .command)

  static let bookmark = Self("d")

  static let liveTextIcon = Self("t", modifiers: .command)
  // Command-T toggles the icon, so Command-Shift-T toggles the highlight. A pretty useful feature to see what matched
  // without reaching for the mouse.
  static let liveTextHighlight = Self("t", modifiers: [.command, .shift])

  static let resetWindowSize = Self("r", modifiers: [.command, .control])
}
