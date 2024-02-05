//
//  View+Key.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/4/24.
//

import SwiftUI

// MARK: - Scroll

// The image collection view has a sidebar and detail scroller that can be invoked from diverging sections of the view
// hierarchy (the sidebar scrolling detail and detail scrolling the sidebar). To support this, we use focus values to
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

// MARK: - Environment

struct LoadedEnvironmentKey: EnvironmentKey {
  static var defaultValue = false
}

struct NavigationColumnsEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(NavigationSplitViewVisibility.automatic)
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

struct AppMenuItemAction<I, A> where I: Equatable {
  let identity: I
  let action: A
}

extension AppMenuItemAction: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identity == rhs.identity
  }
}

struct AppMenuItemActionable<I, A> where I: Equatable {
  let enabled: Bool
  let action: AppMenuItemAction<I, A>
}

extension AppMenuItemActionable {
  init(identity: I, enabled: Bool, action: A) {
    self.init(enabled: enabled, action: .init(identity: identity, action: action))
  }
}

extension AppMenuItemActionable where A == () -> Void {
  init(toggle: AppMenuToggleItem<I>) {
    self.init(identity: toggle.item.action.identity, enabled: toggle.item.enabled) {
      toggle(state: !toggle.state)
    }
  }

  func callAsFunction() {
    action.action()
  }
}

typealias AppMenuItem<I> = AppMenuItemActionable<I, () -> Void> where I: Equatable

extension AppMenuItem: Equatable {}

struct AppMenuToggleItem<I> where I: Equatable {
  typealias Action = (Bool) -> Void
  typealias Item = AppMenuItemActionable<I, Action>

  let state: Bool
  let item: Item

  func callAsFunction(state: Bool) {
    item.action.action(state)
  }
}

extension AppMenuToggleItem {
  init(identity: I, enabled: Bool, state: Bool, action: @escaping Action) {
    self.init(state: state, item: .init(identity: identity, enabled: enabled, action: action))
  }
}

extension AppMenuToggleItem: Equatable {}

struct OpenFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionEnvironmentKey.Value?>
}

struct FinderShowFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionSidebar.Selection>
}

struct FinderOpenFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<SettingsCopyingView.Selection>
}

struct QuickLookFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggleItem<Set<ImageCollectionItemImage.ID>>
}

struct SidebarSearchFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionEnvironmentKey.Value?>
}

struct CurrentImageShowFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionItemImage.ID?>
}

struct BookmarkFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggleItem<Set<ImageCollectionItemImage.ID>>
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

struct LiveTextIconFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggleItem<ImageCollectionEnvironmentKey.Value?>
}

struct LiveTextHighlightFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuToggleItem<[ImageCollectionItemImage.ID]>
}

struct WindowSizeResetFocusedValueKey: FocusedValueKey {
  typealias Value = AppMenuItem<ImageCollectionEnvironmentKey.Value?>
}

extension FocusedValues {
  var open: OpenFocusedValueKey.Value? {
    get { self[OpenFocusedValueKey.self] }
    set { self[OpenFocusedValueKey.self] = newValue }
  }

  var finderShow: FinderShowFocusedValueKey.Value? {
    get { self[FinderShowFocusedValueKey.self] }
    set { self[FinderShowFocusedValueKey.self] = newValue }
  }

  var finderOpen: FinderOpenFocusedValueKey.Value? {
    get { self[FinderOpenFocusedValueKey.self] }
    set { self[FinderOpenFocusedValueKey.self] = newValue }
  }

  var quicklook: QuickLookFocusedValueKey.Value? {
    get { self[QuickLookFocusedValueKey.self] }
    set { self[QuickLookFocusedValueKey.self] = newValue }
  }

  var sidebarSearch: SidebarSearchFocusedValueKey.Value? {
    get { self[SidebarSearchFocusedValueKey.self] }
    set { self[SidebarSearchFocusedValueKey.self] = newValue }
  }

  var currentImageShow: CurrentImageShowFocusedValueKey.Value? {
    get { self[CurrentImageShowFocusedValueKey.self] }
    set { self[CurrentImageShowFocusedValueKey.self] = newValue }
  }

  var bookmark: BookmarkFocusedValueKey.Value? {
    get { self[BookmarkFocusedValueKey.self] }
    set { self[BookmarkFocusedValueKey.self] = newValue }
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

  var windowSizeReset: WindowSizeResetFocusedValueKey.Value? {
    get { self[WindowSizeResetFocusedValueKey.self] }
    set { self[WindowSizeResetFocusedValueKey.self] = newValue }
  }
}

// MARK: - Keyboard Shortcuts
extension KeyboardShortcut {
  static let open = Self("o", modifiers: .command)

  static let showFinder = Self("r", modifiers: .command)
  static let openFinder = Self("r", modifiers: [.command, .option])
  
  static let quicklook = Self("y", modifiers: .command)

  static let fullScreen = Self("f", modifiers: [.command, .control])

  static let back = Self("[", modifiers: .command)
  static let backAll = Self("[", modifiers: [.command, .option])
  static let forward = Self("]", modifiers: .command)
  static let forwardAll = Self("]", modifiers: [.command, .option])

  static let searchSidebar = Self("f", modifiers: .command)
  static let showCurrentImage = Self("l", modifiers: .command)
  static let bookmark = Self("d")

  static let liveTextIcon = Self("t", modifiers: .command)
  // Command-T toggles the icon, so Command-Shift-T toggles the highlight. A pretty useful feature to see what matched
  // without reaching for the mouse.
  static let liveTextHighlight = Self("t", modifiers: [.command, .shift])

  static let resetWindowSize = Self("r", modifiers: [.command, .control])
}
