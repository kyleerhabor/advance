//
//  WindowViewModifier.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

// The reason we can't simply grab NSApp.keyWindow is that it changes over time. A prime example is this is in the
// "Cover Full Window" setting, in which the main window would be the setting window rather than the sequence view
// (which would still not work, since there could be many sequence views).
struct WindowEnvironmentKey: EnvironmentKey {
  static var defaultValue: NSWindow?
}

extension EnvironmentValues {
  var window: WindowEnvironmentKey.Value {
    get { self[WindowEnvironmentKey.self] }
    set { self[WindowEnvironmentKey.self] = newValue }
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

extension View {
  func windowed() -> some View {
    self.modifier(WindowViewModifier())
  }
}
