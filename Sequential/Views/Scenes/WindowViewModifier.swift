//
//  WindowViewModifier.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

@Observable
class Window {
  weak var window: NSWindow?
}

extension Window: Equatable {
  static func ==(lhs: Window, rhs: Window) -> Bool {
    lhs.window == rhs.window
  }
}

struct FullScreenEnvironmentKey: EnvironmentKey {
  static var defaultValue = false
}

struct IsFullScreenEnvironmentKey: EnvironmentKey {
  static var defaultValue = false
}

struct PrerenderEnvironmentKey: EnvironmentKey {
  static var defaultValue = true
}

extension EnvironmentValues {
  var fullScreen: FullScreenEnvironmentKey.Value {
    get { self[FullScreenEnvironmentKey.self] }
    set { self[FullScreenEnvironmentKey.self] = newValue }
  }

  var isFullScreen: IsFullScreenEnvironmentKey.Value {
    get { self[IsFullScreenEnvironmentKey.self] }
    set { self[IsFullScreenEnvironmentKey.self] = newValue }
  }

  var prerendering: PrerenderEnvironmentKey.Value {
    get { self[PrerenderEnvironmentKey.self] }
    set { self[PrerenderEnvironmentKey.self] = newValue }
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
  @State private var isFullScreen = IsFullScreenEnvironmentKey.defaultValue

  func body(content: Content) -> some View {
    content
      .environment(\.fullScreen, fullScreen)
      .environment(\.isFullScreen, isFullScreen)
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
      }.onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
        guard isCurrentWindow(notification) else {
          return
        }

        isFullScreen = true
      }.onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
        guard isCurrentWindow(notification) else {
          return
        }

        isFullScreen = false
      }
  }

  func isCurrentWindow(_ notification: Notification) -> Bool {
    let window = notification.object as! NSWindow

    return window == self.window.window
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

extension View {
  func windowed() -> some View {
    self
      .modifier(PrerenderViewModifier())
      .modifier(WindowFullScreenViewModifier())
      .modifier(WindowViewModifier())
  }
}
