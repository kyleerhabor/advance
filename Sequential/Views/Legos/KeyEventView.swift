//
//  KeyEventView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/16/23.
//

import SwiftUI

// NOTE: This is currently unused, but may be useful if I plan to support Ventura.

class KeyEventHostingView<Content>: NSHostingView<Content> where Content: View {
  typealias Action = (NSEvent) -> Bool

  var action: Action?

  func handle(event: NSEvent) -> Bool {
    if let action {
      return action(event)
    }

    return false
  }

  override func keyDown(with event: NSEvent) {
    if !handle(event: event) {
      super.keyDown(with: event)
    }
  }
}

struct KeyEventView<Content>: NSViewRepresentable where Content: View {
  let view: Content
  let action: KeyEventHostingView.Action

  init(_ view: Content, action: @escaping KeyEventHostingView.Action) {
    self.view = view
    self.action = action
  }

  func makeNSView(context: Context) -> KeyEventHostingView<Content> {
    let hostingView = KeyEventHostingView(rootView: view)
    hostingView.action = action

    return hostingView
  }

  func updateNSView(_ hostingView: KeyEventHostingView<Content>, context: Context) {
    hostingView.rootView = view
    hostingView.action = action
  }
}

struct KeyEventViewModifier: ViewModifier {
  let key: String
  let modifiers: NSEvent.ModifierFlags
  let action: KeyEventHostingView.Action

  func body(content: Content) -> some View {
    KeyEventView(content) { event in
      guard event.characters == key && event.modifierFlags.intersection(.primary) == modifiers,
            !event.isARepeat else {
        return false
      }

      return action(event)
    }
  }
}

extension View {
  func onKey(
    _ key: String,
    modifiers: NSEvent.ModifierFlags = [],
    action: @escaping KeyEventHostingView.Action
  ) -> some View {
    // Interestingly, if I embed the logic directly in this method, animations no longer work. So there is a purpose to modifier(_:)
    self.modifier(KeyEventViewModifier(key: key, modifiers: modifiers, action: action))
  }
}
