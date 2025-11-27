//
//  UI+View.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/11/24.
//

import AdvanceCore
import AppKit
import Combine
import CoreGraphics
import SwiftUI
import IdentifiedCollections

let OPACITY_TRANSPARENT = 0.0
let OPACITY_OPAQUE = 1.0

extension CGSize {
  var length: Double {
    max(self.width, self.height)
  }
}

// This is not (really) a view. Move elsewhere?
extension NSWorkspace {
  func icon(forFileAt url: URL) -> NSImage {
    self.icon(forFile: url.pathString)
  }
}

extension NSMenu {
  static let itemIndexWithTagNotFoundStatus = -1
}

extension NSMenuItem {
  static let unknownTag = 0

  var isStandard: Bool {
    // This is not safe from evolution.
    !(self.isSectionHeader || self.isSeparatorItem)
  }
}

extension NSWindow {
  func isFullScreen() -> Bool {
    self.styleMask.contains(.fullScreen)
  }

  func setToolbarVisibility(_ flag: Bool) {
    self.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = flag ? OPACITY_OPAQUE : OPACITY_TRANSPARENT

    // For some reason, a window in full screen with a light appearance draws a white line at the top of the screen
    // after scrolling. This doesn't occur with a dark appearance, which is interesting.
    //
    // TODO: Figure out how to animate the title bar separator.
    //
    // The property does not have an associated animation by default.
    self.titlebarSeparatorStyle = flag && !self.isFullScreen() ? .automatic : .none
  }
}

extension NSLineBreakMode {
  init?(_ mode: Text.TruncationMode) {
    switch mode {
      case .head: self = .byTruncatingHead
      case .middle: self = .byTruncatingMiddle
      case .tail: self = .byTruncatingTail
      @unknown default: return nil
    }
  }
}

struct VisibleItem<Item> {
  let item: Item
  let anchor: Anchor<CGRect>
}

extension VisibleItem: Equatable where Item: Equatable {}

struct AppMenuItemAction<I, A> where I: Equatable {
  let identity: I
  let action: A
}

extension AppMenuItemAction: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identity == rhs.identity
  }
}

struct AppMenuItem<I, A> where I: Equatable {
  let enabled: Bool
  let action: AppMenuItemAction<I, A>
}

extension AppMenuItem {
  init(identity: I, enabled: Bool, action: A) {
    self.init(
      enabled: enabled,
      action: AppMenuItemAction(identity: identity, action: action)
    )
  }
}

extension AppMenuItem: Equatable {}

struct AppMenuToggleItem<I> where I: Equatable {
  typealias Action = (Bool) -> Void
  typealias Item = AppMenuItem<I, Action>

  let state: Bool
  let item: Item

  func callAsFunction(state: Bool) {
    item.action.action(state)
  }
}

extension AppMenuToggleItem {
  init(identity: I, enabled: Bool, state: Bool, action: @escaping Action) {
    self.init(
      state: state,
      item: AppMenuItem(identity: identity, enabled: enabled, action: action)
    )
  }
}

extension AppMenuToggleItem: Equatable {}

typealias AppMenuItemDefaultAction = () -> Void

extension AppMenuItem where A == AppMenuItemDefaultAction {
  init(toggle: AppMenuToggleItem<I>) {
    self.init(identity: toggle.item.action.identity, enabled: toggle.item.enabled) {
      toggle(state: !toggle.state)
    }
  }

  func callAsFunction() {
    action.action()
  }
}

typealias AppMenuActionItem<I> = AppMenuItem<I, AppMenuItemDefaultAction> where I: Equatable

// MARK: - Preferences

struct ScrollOffsetPreferenceKey<A>: PreferenceKey {
  typealias Value = Anchor<A>?

  static var defaultValue: Value {
    nil
  }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    guard let next = nextValue() else {
      return
    }

    value = next
  }
}

// https://swiftwithmajid.com/2020/03/18/anchor-preferences-in-swiftui/
struct VisiblePreferenceKey<Item>: PreferenceKey {
  typealias Value = [VisibleItem<Item>]

  // The default is optimized for the detail view, which, for a set of not-too-wide images in a not-too-thin container,
  // will house ~2 images. The sidebar view suffers, storing ~14 images given similar constraints; but the detail view
  // is the most active, so it makes sense to optimize for it.
  static var defaultMinimumCapacity: Int { 4 }

  static var defaultValue: Value {
    Value(reservingCapacity: defaultMinimumCapacity)
  }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.append(contentsOf: nextValue())
  }
}

// MARK: - Environment

struct TrackingMenuEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
}

struct WindowFullScreenEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
}

struct WindowLiveResizeEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
}

struct ImagesSidebarJumpEnvironmentKey: EnvironmentKey {
  static var defaultValue: ImagesNavigationJumpAction? { nil }
}

struct ImagesDetailJumpEnvironmentKey: EnvironmentKey {
  static var defaultValue: ImagesNavigationJumpAction? { nil }
}

// MARK: Focus

struct ImagesNavigationJumpIdentity {
  let id: ImagesModel.ID
  let isReady: Bool
}

extension ImagesNavigationJumpIdentity: Equatable {}

typealias ImagesNavigationJumpAction = AppMenuItemAction<ImagesNavigationJumpIdentity, (ImagesItemModel) -> Void>

// MARK: - Views

class WindowCaptureView: NSView {
  var windowed: Windowed

  init(windowed: Windowed) {
    self.windowed = windowed

    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillMove(toWindow window: NSWindow?) {
    super.viewWillMove(toWindow: window)

    windowed.window = window
  }
}

struct WindowCapturingView: NSViewRepresentable {
  typealias NSViewType = WindowCaptureView

  let windowed: Windowed

  func makeNSView(context: Context) -> NSViewType {
    WindowCaptureView(windowed: windowed)
  }

  func updateNSView(_ captureView: NSViewType, context: Context) {
    captureView.windowed = windowed
  }
}

// MARK: - View modifiers

struct TrackingMenuViewModifier: ViewModifier {
  @State private var isTrackingMenu = TrackingMenuEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.isTrackingMenu, isTrackingMenu)
      .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
        isTrackingMenu = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
        isTrackingMenu = false
      }
  }
}

struct WindowViewModifier: ViewModifier {
  @State private var windowed = Windowed()

  func body(content: Content) -> some View {
    content
      .environment(windowed)
      .background {
        WindowCapturingView(windowed: windowed)
      }
  }
}

struct WindowFullScreenViewModifier: ViewModifier {
  @Environment(Windowed.self) private var windowed
  @State private var isWindowFullScreen = WindowFullScreenEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.isWindowFullScreen, isWindowFullScreen)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { notification in
        let window = notification.object as! NSWindow

        guard windowed.window == window else {
          return
        }

        isWindowFullScreen = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { notification in
        let window = notification.object as! NSWindow

        guard windowed.window == window else {
          return
        }

        isWindowFullScreen = false
      }
  }
}

struct WindowLiveResizeViewModifier: ViewModifier {
  @Environment(Windowed.self) private var windowed
  @State private var isWindowLiveResizeActive = WindowLiveResizeEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.isWindowLiveResizeActive, isWindowLiveResizeActive)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willStartLiveResizeNotification)) { notification in
        let window = notification.object as! NSWindow

        guard window == windowed.window else {
          return
        }

        isWindowLiveResizeActive = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndLiveResizeNotification)) { notification in
        let window = notification.object as! NSWindow

        guard window == windowed.window else {
          return
        }

        isWindowLiveResizeActive = false
      }
  }
}

struct WindowFullScreenToggleViewModifier: ViewModifier {
  @Environment(Windowed.self) private var windowed

  func body(content: Content) -> some View {
    // This is a workaround for an odd behavior in SwiftUI where the "Enter/Exit Full Screen" menu item disappears.
    // It's not a solution (it relies on the deprecated EventModifiers.function modifier and overrides the default menu
    // item's key equivalent in the responder chain), but it is *something*.
    content
      .background {
        Group {
          Button(action: toggleFullScreen) {
            // Empty
          }
          .keyboardShortcut(.fullScreen)

          // FIXME: Pressing "f" without Fn triggers the action.
          Button(action: toggleFullScreen) {
            // Empty
          }
          .keyboardShortcut(.systemFullScreen)
        }
        .focusable(false)
        .visible(false)
      }
  }

  func toggleFullScreen() {
    windowed.window?.toggleFullScreen(nil)
  }
}

struct ToolbarVisibleViewModifier: ViewModifier {
  @Environment(Windowed.self) private var windowed
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen

  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .onChange(of: isVisible, initial: true) {
        setToolbarVisibility(isVisible)
      }
      .onChange(of: isWindowFullScreen) {
        setToolbarVisibility(isVisible)
      }
      .onDisappear {
        setToolbarVisibility(true)
      }
  }

  private func setToolbarVisibility(_ flag: Bool) {
    windowed.window?.setToolbarVisibility(flag)
  }
}

struct CursorVisibleViewModifier: ViewModifier {
  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .onAppear {
        guard !isVisible else {
          return
        }

        NSCursor.hide()
      }
      .onChange(of: isVisible) {
        if isVisible {
          NSCursor.unhide()

          return
        }

        NSCursor.hide()
      }
      .onDisappear {
        guard !isVisible else {
          return
        }

        NSCursor.unhide()
      }
  }
}

struct LocalizeAction {
  let locale: Locale

  func callAsFunction(_ key: String.LocalizationValue) -> String {
    String(localized: key, locale: locale)
  }

  func callAsFunction(_ key: String.LocalizationValue) -> AttributedString {
    AttributedString(localized: key, locale: locale)
  }
}

struct LocalizedViewModifier: ViewModifier {
  @Environment(\.locale) private var locale

  func body(content: Content) -> some View {
    content.environment(\.localize, LocalizeAction(locale: locale))
  }
}

struct WindowedViewModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .modifier(WindowFullScreenViewModifier())
      .modifier(WindowLiveResizeViewModifier())
      .modifier(WindowFullScreenToggleViewModifier())
      .modifier(WindowViewModifier())
      .modifier(TrackingMenuViewModifier())
  }
}

struct VisibleViewModifier: ViewModifier {
  let isVisible: Bool


  func body(content: Content) -> some View {
    content.opacity(isVisible ? OPACITY_OPAQUE : OPACITY_TRANSPARENT)
  }
}

struct PreferencePublisherViewModifier<Source, Destination, Subject, Publisher>: ViewModifier
where Source: PreferenceKey,
      Source.Value: Equatable,
      Destination: PreferenceKey,
      Subject: Combine.Subject<Source.Value, Never>,
      Publisher: Combine.Publisher<Destination.Value, Never> {
  private let source: Source.Type
  private let destination: Destination.Type
  private let subject: Subject
  private let publisher: Publisher
  private let defaultValue: Destination.Value

  @State private var value: Destination.Value?

  init(
    source: Source.Type = Source.self,
    destination: Destination.Type = Destination.self,
    subject: Subject,
    publisher: Publisher,
    defaultValue: Destination.Value
  ) {
    self.source = source
    self.destination = destination
    self.subject = subject
    self.publisher = publisher
    self.defaultValue = defaultValue
  }

  func body(content: Content) -> some View {
    content
      .onPreferenceChange(source) { value in
        subject.send(value)
      }
      .onReceive(publisher) { value in
        self.value = value
      }
      .preference(key: destination, value: value ?? defaultValue)
  }
}

// MARK: - Extensions

extension View {
  func transform(@ViewBuilder _ transform: (Self) -> some View) -> some View {
    transform(self)
  }

  func windowed() -> some View {
    // We're extracting the view modifiers into one so SwiftUI persists just the 'windowed' view modifier. This will
    // make it so modifications to the list won't cause scene restoration to fail.
    self.modifier(WindowedViewModifier())
  }

  func localized() -> some View {
    self.modifier(LocalizedViewModifier())
  }

  func toolbarVisible(_ isVisible: Bool) -> some View {
    self.modifier(ToolbarVisibleViewModifier(isVisible: isVisible))
  }

  func cursorVisible(_ isVisible: Bool) -> some View {
    self.modifier(CursorVisibleViewModifier(isVisible: isVisible))
  }

  func navigationSplitViewColumnWidth(min: CGFloat, max: CGFloat) -> some View {
    self.navigationSplitViewColumnWidth(min: min, ideal: min, max: max)
  }

  func preferencePublisher<Source, Destination, Subject, Publisher>(
    source: Source.Type = Source.self,
    destination: Destination.Type = Destination.self,
    subject: Subject,
    publisher: Publisher,
    defaultValue: Destination.Value
  ) -> some View where Source: PreferenceKey,
                       Source.Value: Equatable,
                       Destination: PreferenceKey,
                       Subject: Combine.Subject<Source.Value, Never>,
                       Publisher: Combine.Publisher<Destination.Value, Never> {
    self.modifier(PreferencePublisherViewModifier(
      source: source,
      destination: destination,
      subject: subject,
      publisher: publisher,
      defaultValue: defaultValue
    ))
  }

  func preferencePublisher<Key, Subject, Publisher>(
    _ key: Key.Type = Key.self,
    subject: Subject,
    publisher: Publisher
  ) -> some View where Key: PreferenceKey,
                       Key.Value: Equatable,
                       Subject: Combine.Subject<Key.Value, Never>,
                       Publisher: Combine.Publisher<Key.Value, Never> {
    self.preferencePublisher(
      source: key,
      destination: key,
      subject: subject,
      publisher: publisher,
      defaultValue: key.defaultValue
    )
  }
}

extension View {
  func visible(_ flag: Bool) -> some View {
    self.opacity(flag ? OPACITY_OPAQUE : OPACITY_TRANSPARENT)
  }
}

extension ShapeStyle {
  func visible(_ flag: Bool) -> some ShapeStyle {
    self.opacity(flag ? OPACITY_OPAQUE : OPACITY_TRANSPARENT)
  }
}

extension Anchor.Source where Value == CGPoint {
  static let origin = Self.unitPoint(.zero)
}

extension Text {
  init() {
    self.init(verbatim: "")
  }
}

extension EnvironmentValues {
  var isTrackingMenu: TrackingMenuEnvironmentKey.Value {
    get { self[TrackingMenuEnvironmentKey.self] }
    set { self[TrackingMenuEnvironmentKey.self] = newValue }
  }

  var isWindowFullScreen: WindowFullScreenEnvironmentKey.Value {
    get { self[WindowFullScreenEnvironmentKey.self] }
    set { self[WindowFullScreenEnvironmentKey.self] = newValue }
  }

  var isWindowLiveResizeActive: WindowLiveResizeEnvironmentKey.Value {
    get { self[WindowLiveResizeEnvironmentKey.self] }
    set { self[WindowLiveResizeEnvironmentKey.self] = newValue }
  }

  var imagesSidebarJump: ImagesSidebarJumpEnvironmentKey.Value {
    get { self[ImagesSidebarJumpEnvironmentKey.self] }
    set { self[ImagesSidebarJumpEnvironmentKey.self] = newValue }
  }

  var imagesDetailJump: ImagesDetailJumpEnvironmentKey.Value {
    get { self[ImagesDetailJumpEnvironmentKey.self] }
    set { self[ImagesDetailJumpEnvironmentKey.self] = newValue }
  }

  @Entry var localize = LocalizeAction(locale: .current)
  @Entry var isImageAnalysisEnabled = true
  @Entry var isImageAnalysisSupplementaryInterfaceHidden = false

  // MARK: - Old
  // Is using Binding in Environment a good idea?
  @Entry var imagesID = UUID()
}

enum WindowOpen {
  case images(ImagesModel.ID),
       folders
}

extension WindowOpen: Equatable {}

enum FinderShow {
  case unknown,
       images(Set<ImagesItemModel.ID>),
       folders(Set<FoldersSettingsItem.ID>)
}

extension FinderShow: Equatable {}

extension FocusedValues {
  @Entry var windowOpen: AppMenuActionItem<WindowOpen?>?
  @Entry var finderShow: AppMenuActionItem<FinderShow>?
  @Entry var finderOpen: AppMenuActionItem<Set<FoldersSettingsItem.ID>>?
  @Entry var imagesSidebarJump: ImagesNavigationJumpAction?
  @Entry var imagesSidebarShow: AppMenuActionItem<ImagesModel.ID?>?
  @Entry var imagesDetailJump: ImagesNavigationJumpAction?
  @Entry var imagesLiveTextIcon: AppMenuToggleItem<ImagesModel.ID?>?
  @Entry var imagesLiveTextHighlight: AppMenuToggleItem<Set<ImagesItemModel.ID>>?
  @Entry var imagesWindowResetSize: AppMenuActionItem<ImagesModel.ID?>?

  // MARK: - Old

  @Entry var imagesQuickLook: AppMenuToggleItem<Set<ImageCollectionItemImage.ID>>?
}

extension KeyboardShortcut {
  static let back = Self("[", modifiers: .command)
  static let forward = Self("]", modifiers: .command)
  static let showInFinder = Self("r", modifiers: .command)
  static let finderOpenItem = Self("r", modifiers: [.command, .shift])

  static let sidebarShowItem = Self("l", modifiers: .command)

  static let fullScreen = Self("f", modifiers: [.command, .control])
  static let systemFullScreen = Self("f", modifiers: .function) // See WindowFullScreenToggleViewModifier

  static let liveTextIcon = Self("t", modifiers: .command)
  static let liveTextHighlight = Self("t", modifiers: [.command, .shift])

  static let open = Self("o", modifiers: .command)
  // Terminal > Window > Return to Default Size
  static let resetWindowSize = Self("m", modifiers: [.command, .control])

  static let searchSettings = Self("2", modifiers: .command)
  static let foldersSettings = Self("3", modifiers: .command)
}

extension NSUserInterfaceItemIdentifier {
  static let imagesWindowOpen = Self(rawValue: "images-window-open")
  static let foldersOpen = Self(rawValue: "folders-open")
}
