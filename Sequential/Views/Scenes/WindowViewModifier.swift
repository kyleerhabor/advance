//
//  WindowViewModifier.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

struct WindowEnvironmentKey: EnvironmentKey {
  static var defaultValue: NSWindow?
}

struct FullScreenEnvironmentKey: EnvironmentKey {
  static var defaultValue: Bool?
}

extension EnvironmentValues {
  var window: WindowEnvironmentKey.Value {
    get { self[WindowEnvironmentKey.self] }
    set { self[WindowEnvironmentKey.self] = newValue }
  }

  var fullScreen: FullScreenEnvironmentKey.Value {
    get { self[FullScreenEnvironmentKey.self] }
    set { self[FullScreenEnvironmentKey.self] = newValue }
  }
}

// https://stackoverflow.com/a/65401530/14695788
struct WindowView: NSViewRepresentable {
  @Binding var window: NSWindow?

  func makeNSView(context: Context) -> some NSView {
    let view = NSView()

    Task {
      window = view.window
    }

    return view
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {}
}

struct WindowViewModifier: ViewModifier {
  @State private var window: NSWindow?

  func body(content: Content) -> some View {
    content
      .environment(\.window, window)
      .background {
        WindowView(window: $window)
      }
  }
}

struct WindowFullScreenViewModifier: ViewModifier {
  @Environment(\.window) private var window
  @State private var fullScreen: Bool?

  func body(content: Content) -> some View {
    content
      .environment(\.fullScreen, fullScreen)
      .onChange(of: window) {
        fullScreen = window?.isFullScreened()
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

extension View {
  func windowed() -> some View {
    self
      .modifier(WindowFullScreenViewModifier())
      .modifier(WindowViewModifier())
  }
}
