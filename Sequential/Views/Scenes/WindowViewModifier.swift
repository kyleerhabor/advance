//
//  WindowView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

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
struct WindowDataView: NSViewRepresentable {
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
        WindowDataView(window: $window)
      }
  }
}

extension View {
  func windowed() -> some View {
    self.modifier(WindowViewModifier())
  }
}
