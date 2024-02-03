//
//  Windowed.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

@Observable
class Windowed {
  weak var window: NSWindow?
}

extension Windowed: Equatable {
  static func ==(lhs: Windowed, rhs: Windowed) -> Bool {
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

struct WindowingView: NSViewRepresentable {
  let windowed: Windowed

  func makeNSView(context: Context) -> WindowCaptureView {
    .init(windowed: windowed)
  }

  func updateNSView(_ captureView: WindowCaptureView, context: Context) {
    captureView.windowed = windowed
  }
}

struct WindowViewModifier: ViewModifier {
  @State private var windowed = Windowed()

  func body(content: Content) -> some View {
    content
      .environment(windowed)
      .background {
        WindowingView(windowed: windowed)
      }
  }
}

struct WindowFullScreenViewModifier: ViewModifier {
  @Environment(Windowed.self) private var windowed
  @State private var fullScreen = FullScreenEnvironmentKey.defaultValue
  private var window: NSWindow? { windowed.window }

  func body(content: Content) -> some View {
    content
      .environment(\.fullScreen, fullScreen)
      .onChange(of: windowed) {
        fullScreen = window?.isFullScreen() ?? FullScreenEnvironmentKey.defaultValue
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

    return window == self.window
  }
}

struct WindowFullScreenToggleViewModifier: ViewModifier {
  @Environment(Windowed.self) private var windowed
  private var window: NSWindow? { windowed.window }

  func body(content: Content) -> some View {
    content.background {
      // This is a workaround for an odd behavior where the menu item to toggle full screen mode disappears. It's not a
      // solution, since some existing behavior does not work (e.g. Fn-F to full screen); but it is something.
      Button("Window.FullScreen.Toggle") {
        window?.toggleFullScreen(window)
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
