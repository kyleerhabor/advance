//
//  Windowed.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

@Observable
class Window {
  // TODO: Don't make this optional.
  weak var window: NSWindow?
}

extension Window: Equatable {
  static func ==(lhs: Window, rhs: Window) -> Bool {
    lhs.window == rhs.window
  }
}

struct PrerenderEnvironmentKey: EnvironmentKey {
  static var defaultValue = true
}

struct FullScreenEnvironmentKey: EnvironmentKey {
  static var defaultValue = false
}

struct MenuTrackingEnvironmentKey: EnvironmentKey {
  static var defaultValue = false
}

extension EnvironmentValues {
  var fullScreen: FullScreenEnvironmentKey.Value {
    get { self[FullScreenEnvironmentKey.self] }
    set { self[FullScreenEnvironmentKey.self] = newValue }
  }

  var prerendering: PrerenderEnvironmentKey.Value {
    get { self[PrerenderEnvironmentKey.self] }
    set { self[PrerenderEnvironmentKey.self] = newValue }
  }

  var trackingMenu: MenuTrackingEnvironmentKey.Value {
    get { self[MenuTrackingEnvironmentKey.self] }
    set { self[MenuTrackingEnvironmentKey.self] = newValue }
  }
}

class AppearanceView: NSView {
  var win: Window

  init(window: Window) {
    self.win = window

    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()

    win.window = self.window
  }
}

struct WindowCaptureView: NSViewRepresentable {
  let window: Window

  func makeNSView(context: Context) -> AppearanceView {
    .init(window: window)
  }

  func updateNSView(_ appearanceView: AppearanceView, context: Context) {
    appearanceView.win = window
  }
}

struct WindowViewModifier: ViewModifier {
  @State private var window = Window()

  func body(content: Content) -> some View {
    content
      .environment(window)
      .focusedSceneValue(\.window, window)
      .background {
        WindowCaptureView(window: window)
      }
  }
}

struct WindowFullScreenViewModifier: ViewModifier {
  @Environment(Window.self) private var window
  @State private var fullScreen = FullScreenEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.fullScreen, fullScreen)
      .focusedSceneValue(\.fullScreen, fullScreen)
      .onChange(of: window) {
        fullScreen = window.window?.isFullScreen() ?? FullScreenEnvironmentKey.defaultValue
      }.onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { notification in
        guard isCurrentWindow(notification) else {
          return
        }

        fullScreen = true
      }.onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { notification in
        guard isCurrentWindow(notification) else {
          return
        }

        fullScreen = false
      }
  }

  func isCurrentWindow(_ notification: Notification) -> Bool {
    let window = notification.object as! NSWindow

    return window == self.window.window
  }
}

struct WindowFullScreenToggleViewModifier: ViewModifier {
  @Environment(Window.self) private var window

  func body(content: Content) -> some View {
    content.background {
      // This is a workaround for an odd behavior where the menu item to toggle full screen mode disappears. It's not a
      // solution, since some existing behavior does not work (e.g. Fn-F to full screen); but it is something.
      Button("Window.FullScreen.Toggle") {
        window.window?.toggleFullScreen(nil)
      }
      .keyboardShortcut(.fullScreen)
      .focusable(false)
      .visible(false)
    }
  }
}

struct PrerenderViewModifier: ViewModifier {
  @State private var prerendering = true

  func body(content: Content) -> some View {
    content
      .environment(\.prerendering, prerendering)
      .task { prerendering = false }
  }
}

struct MenuTrackingViewModifier: ViewModifier {
  @State private var tracking = MenuTrackingEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.trackingMenu, tracking)
      .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
        tracking = true
      }.onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
        tracking = false
      }
  }
}

struct WindowedViewModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .modifier(PrerenderViewModifier())
      .modifier(WindowFullScreenViewModifier())
      .modifier(WindowFullScreenToggleViewModifier())
      .modifier(WindowViewModifier())
      .modifier(MenuTrackingViewModifier())
  }
}

extension View {
  func windowed() -> some View {
    // We're extracting the view modifiers into one so SwiftUI persists just the 'windowed' view modifier. This will
    // make it so modifications to the list won't cause scene restoration to fail.
    self.modifier(WindowedViewModifier())
  }
}
