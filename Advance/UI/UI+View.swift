//
//  UI+View.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/11/24.
//

import AppKit
import Combine
import CoreGraphics
import SwiftUI
import IdentifiedCollections
import OSLog

extension Logger {
  static let ui = Self(subsystem: Bundle.appID, category: "UI")
}

// MARK: - Swift

extension Duration {
  // TODO: Rename.
  static let imagesElapse = Self.seconds(1)
  static let imagesHoverElapse = Self.seconds(3)

  // Instruments

  static let microhang = Self.milliseconds(250)
}

// MARK: - AppKit

extension NSWindow {
  var isFullScreen: Bool {
    self.styleMask.contains(.fullScreen)
  }

  func setToolbarVisibility(_ flag: Bool, isFullScreen: Bool) {
    self.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = flag ? 1 : 0

    // For some reason, a window in full screen with a light appearance draws a white line at the top of the screen
    // after scrolling. This doesn't occur with a dark appearance, which is interesting.
    //
    // TODO: Figure out how to animate the title bar separator.
    //
    // The property does not have an associated animation by default.
    self.titlebarSeparatorStyle = flag && !isFullScreen ? .automatic : .none
  }
}

extension NSWorkspace {
  func icon(forFileAt url: URL) -> NSImage {
    self.icon(forFile: url.pathString)
  }
}

extension NSMenuItem {
  // "Search With [...]" (e.g., Google).
  static let search = NSUserInterfaceItemIdentifier(rawValue: "_searchWithGoogleFromMenu:")
}

// MARK: - SwiftUI

extension EdgeInsets {
  init(_ insets: CGFloat) {
    self.init(
      top: insets,
      leading: insets,
      bottom: insets,
      trailing: insets,
    )
  }

  init(vertical: Double, horizontal: Double) {
    self.init(
      top: vertical,
      leading: horizontal,
      bottom: vertical,
      trailing: horizontal,
    )
  }

  init(horizontal: Double, top: Double, bottom: Double) {
    self.init(
      top: top,
      leading: horizontal,
      bottom: bottom,
      trailing: horizontal,
    )
  }
}

struct TrackingMenuViewModifier: ViewModifier {
  @State private var isTrackingMenu = TrackingMenuEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.isTrackingMenu, self.isTrackingMenu)
      .task {
        for await _ in NotificationCenter.default.notifications(named: NSMenu.didBeginTrackingNotification) {
          self.isTrackingMenu = true
        }
      }
      .task {
        for await _ in NotificationCenter.default.notifications(named: NSMenu.didEndTrackingNotification) {
          self.isTrackingMenu = false
        }
      }
  }
}

class WindowCaptureView: NSView {
  var _window: Window

  init(window: Window) {
    self._window = window

    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewWillMove(toWindow window: NSWindow?) {
    super.viewWillMove(toWindow: window)

    self._window.window = window
  }
}

struct WindowCapturingView: NSViewRepresentable {
  func makeNSView(context: Context) -> WindowCaptureView {
    WindowCaptureView(window: context.environment[Window.self]!)
  }

  func updateNSView(_ captureView: WindowCaptureView, context: Context) {
    captureView._window = context.environment[Window.self]!
  }
}

struct WindowViewModifier: ViewModifier {
  @State private var window = Window()

  func body(content: Content) -> some View {
    content
      .background {
        WindowCapturingView()
      }
      .environment(self.window)
  }
}

struct WindowFullScreenViewModifier: ViewModifier {
  @Environment(Window.self) private var window
  @State private var isWindowFullScreen = WindowFullScreenEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    // For some reason, using task(priority:_:) to await notifications results in toolbar(_:for:) not working in scene
    // restoration into full-screen mode.
    content
      .environment(\.isWindowFullScreen, self.isWindowFullScreen)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification, object: self.window.window)) { _ in
        self.isWindowFullScreen = true
      }
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification, object: self.window.window)) { _ in
        self.isWindowFullScreen = false
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
  private static let transparent = 0.0
  private static let opaque = 1.0
  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .opacity(self.isVisible ? Self.opaque : Self.transparent)
  }
}

struct ToolbarVisibleViewModifierID {
  let isVisible: Bool
  let isWindowFullScreen: Bool
}

extension ToolbarVisibleViewModifierID: Equatable {}

struct ToolbarVisibleViewModifier: ViewModifier {
  @Environment(Window.self) private var window
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen
  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .onChange(
        of: ToolbarVisibleViewModifierID(isVisible: self.isVisible, isWindowFullScreen: self.isWindowFullScreen),
        initial: true,
      ) {
        self.setToolbarVisibility(self.isVisible)
      }
      .onDisappear {
        self.setToolbarVisibility(true)
      }
  }

  private func setToolbarVisibility(_ flag: Bool) {
    self.window.window?.setToolbarVisibility(flag, isFullScreen: self.isWindowFullScreen)
  }
}

struct CursorVisibleViewModifier: ViewModifier {
  let isVisible: Bool

  func body(content: Content) -> some View {
    content
      .onChange(of: self.isVisible, initial: true) { old, new in
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
        guard !self.isVisible else {
          return
        }

        NSCursor.unhide()
      }
  }
}

struct TransformViewModifier<Result>: ViewModifier where Result: View {
  let content: (Content) -> Result

  func body(content: Content) -> some View {
    self.content(content)
  }
}

extension View {
  func transform(@ViewBuilder _ content: (Self) -> some View) -> some View {
    content(self)
  }
  
//  func transform<Content>(@ViewBuilder body: @escaping (TransformViewModifier<Content>.Content) -> Content) -> some View {
//    self.modifier(TransformViewModifier(content: body))
//  }

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
}

extension ShapeStyle {
  func visible(_ isVisible: Bool) -> some ShapeStyle {
    let transparent = 0.0
    let opaque = 1.0

    return self.opacity(isVisible ? opaque : transparent)
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
}

extension FocusedValues {
  @Entry var commandScene: AppModelCommandScene?
}

extension KeyboardShortcut {
  static let open = Self("o", modifiers: .command)
  static let showFinder = Self("r", modifiers: .command)
  static let openFinder = Self("r", modifiers: [.command, .shift])
  static let showSidebar = Self("l", modifiers: .command)
  static let toggleSidebarBookmarks = Self("b", modifiers: [.command, .option])
  // Preview > Tools > Add Bookmark
  static let bookmark = Self("d", modifiers: .command)
//  static let toggleLiveTextIcon = Self("t", modifiers: .command)
  static let toggleLiveTextHighlight = Self("t", modifiers: [.command, .shift])
  // Terminal > Window > Return to Default Size
  static let resetWindowSize = Self("m", modifiers: [.command, .control])
  // For some reason, system actions like "Capture Entire Screen" take precedent when using Shift-Command.
  static let foldersSettings = Self("2", modifiers: .command)
  static let searchSettings = Self("3", modifiers: .command)

  // MARK: - Old
  static let back = Self("[", modifiers: .command)
  static let forward = Self("]", modifiers: .command)
}
