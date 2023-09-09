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

struct FullScreenEnvironmentKey: EnvironmentKey {
  static var defaultValue: Bool?
}

struct PrerenderEnvironmentKey: EnvironmentKey {
  static var defaultValue = true
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
}

class AppearanceView: NSView {
  @Bindable var win: Window

  init(window: Bindable<Window>) {
    self._win = window

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
  @Bindable var window: Window

  func makeNSView(context: Context) -> AppearanceView {
    .init(window: $window)
  }

  func updateNSView(_ nsView: AppearanceView, context: Context) {}
}

struct WindowViewModifier: ViewModifier {
  @State private var window = Window()

  func body(content: Content) -> some View {
    content
      .environment(window)
      .background {
        WindowCaptureView(window: window)
      }
  }
}

struct WindowFullScreenViewModifier: ViewModifier {
  @Environment(Window.self) private var window
  @State private var fullScreen: Bool?

  func body(content: Content) -> some View {
    content
      .environment(\.fullScreen, fullScreen)
      .onChange(of: window.window == nil) {
        fullScreen = window.window?.isFullScreened()
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
      .modifier(WindowFullScreenViewModifier())
      .modifier(WindowViewModifier())
      .modifier(PrerenderViewModifier())
  }
}
