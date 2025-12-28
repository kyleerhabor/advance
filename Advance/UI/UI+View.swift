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
import OSLog

let OPACITY_TRANSPARENT = 0.0
let OPACITY_OPAQUE = 1.0

extension Logger {
  static let ui = Self(subsystem: Bundle.appID, category: "UI")
}

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

// MARK: - View modifiers

struct ToolbarVisibleViewModifier: ViewModifier {
  @Environment(Window.self) private var windowed
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

struct LocalizeAction {
  let locale: Locale

  func callAsFunction(_ key: String.LocalizationValue) -> String {
    String(localized: key, locale: locale)
  }

  func callAsFunction(_ key: String.LocalizationValue) -> AttributedString {
    AttributedString(localized: key, locale: locale)
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

// MARK: - Swift

extension Duration {
  // TODO: Rename.
  static let imagesElapse = Self.seconds(1)

  // Instruments

  static let microhang = Self.milliseconds(250)
}

// MARK: - SwiftUI

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

class WindowCaptureView: NSView {
  var model: Window

  init(window: Window) {
    self.model = window

    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillMove(toWindow window: NSWindow?) {
    super.viewWillMove(toWindow: window)

    model.window = window
  }
}

struct WindowCapturingView: NSViewRepresentable {
  let window: Window

  func makeNSView(context: Context) -> WindowCaptureView {
    WindowCaptureView(window: window)
  }

  func updateNSView(_ captureView: WindowCaptureView, context: Context) {
    captureView.model = window
  }
}

struct WindowViewModifier: ViewModifier {
  @State private var window = Window()

  func body(content: Content) -> some View {
    content
      .environment(window)
      .background {
        WindowCapturingView(window: window)
      }
  }
}

struct WindowFullScreenViewModifier: ViewModifier {
  @Environment(Window.self) private var window
  @State private var isWindowFullScreen = WindowFullScreenEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.isWindowFullScreen, isWindowFullScreen)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { notification in
        let window = notification.object as! NSWindow

        guard self.window.window == window else {
          return
        }

        isWindowFullScreen = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { notification in
        let window = notification.object as! NSWindow

        guard self.window.window == window else {
          return
        }

        isWindowFullScreen = false
      }
  }
}

struct WindowLiveResizeViewModifier: ViewModifier {
  @Environment(Window.self) private var window
  @State private var isWindowLiveResizeActive = WindowLiveResizeEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.isWindowLiveResizeActive, isWindowLiveResizeActive)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willStartLiveResizeNotification)) { notification in
        let window = notification.object as! NSWindow

        guard self.window.window == window else {
          return
        }

        isWindowLiveResizeActive = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEndLiveResizeNotification)) { notification in
        let window = notification.object as! NSWindow

        guard self.window.window == window else {
          return
        }

        isWindowLiveResizeActive = false
      }
  }
}

struct WindowedViewModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .modifier(WindowFullScreenViewModifier())
      .modifier(WindowLiveResizeViewModifier())
      .modifier(WindowViewModifier())
      .modifier(TrackingMenuViewModifier())
  }
}

struct VisibleViewModifier: ViewModifier {
  static let transparent = 0.0
  static let opaque = 1.0

  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .opacity(isVisible ? Self.opaque : Self.transparent)
  }
}

struct CursorVisibleViewModifier: ViewModifier {
  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .onChange(of: isVisible, initial: true) { old, new in
        switch (old, new) {
          case (false, false):
            NSCursor.hide()
          case (false, true):
            NSCursor.unhide()
          case (true, false):
            NSCursor.hide()
          case (true, true):
            break
        }
      }
      .onDisappear {
        guard !isVisible else {
          return
        }

        NSCursor.unhide()
      }
  }
}

extension View {
  func transform(@ViewBuilder _ content: (Self) -> some View) -> some View {
    content(self)
  }

  func windowed() -> some View {
    // We're extracting the view modifiers into one so SwiftUI persists just the 'windowed' view modifier. This will
    // make it so modifications to the list won't cause scene restoration to fail.
    self.modifier(WindowedViewModifier())
  }

  func visible(_ isVisible: Bool) -> some View {
    self.modifier(VisibleViewModifier(isVisible: isVisible))
  }

  func cursorVisible(_ isVisible: Bool) -> some View {
    self.modifier(CursorVisibleViewModifier(isVisible: isVisible))
  }

  func toolbarVisible(_ isVisible: Bool) -> some View {
    self.modifier(ToolbarVisibleViewModifier(isVisible: isVisible))
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

extension EdgeInsets {
  // SwiftUI reserves margins for horizontal scroll indicators, which I haven't found a way to disable. This simply
  // pushes content into that space, which I'm not sure is safe from other devices and settings.
  static let listRow = Self(top: 0, leading: -8, bottom: 0, trailing: -9)
}

struct TrackingMenuEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
}

struct WindowFullScreenEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
}

struct WindowLiveResizeEnvironmentKey: EnvironmentKey {
  static let defaultValue = false
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

  @Entry var isImageAnalysisEnabled = true
  @Entry var isImageAnalysisSupplementaryInterfaceHidden = false

  // MARK: - Old
  // Is using Binding in Environment a good idea?
  @Entry var imagesID = UUID()
}

extension FocusedValues {
  @Entry var commandScene: AppModelCommandScene?

  // MARK: - Old
  @Entry var imagesLiveTextIcon: AppMenuToggleItem<ImagesModel.ID?>?
  @Entry var imagesLiveTextHighlight: AppMenuToggleItem<Set<ImagesItemModel.ID>>?
}

extension KeyboardShortcut {
  static let open = Self("o", modifiers: .command)
  static let showFinder = Self("r", modifiers: .command)
  static let openFinder = Self("r", modifiers: [.command, .shift])
  static let showSidebar = Self("l", modifiers: .command)
  // Preview > Tools > Add Bookmark
  static let bookmark = Self("d", modifiers: .command)
  // Terminal > Window > Return to Default Size
  static let resetWindowSize = Self("m", modifiers: [.command, .control])
  static let foldersSettings = Self("2", modifiers: .command)
  static let searchSettings = Self("3", modifiers: .command)

  static let back = Self("[", modifiers: .command)
  static let forward = Self("]", modifiers: .command)
  static let liveTextIcon = Self("t", modifiers: .command)
  static let liveTextHighlight = Self("t", modifiers: [.command, .shift])
}
