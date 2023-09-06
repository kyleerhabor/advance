//
//  KeyMonitorViewModifier.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/23/23.
//

import SwiftUI

struct KeyMonitorViewModifier: ViewModifier {
  @State private var monitor: Any?
  let key: String
  let modifiers: NSEvent.ModifierFlags
  let repeating: Bool
  let body: () -> Void

  func body(content: Content) -> some View {
    content
      .onAppear {
        print("[Appearance] Creating monitor!")

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
          // Returning `event` symbolizes that the event was not handled, producing the "unknown command" sound people hear.
          // Returning `nil` does the opposite.
          //
          // We need to intersect the set since AppKit, for some reason, likes adding flags like 0x10A to the set
          // (which I'm not sure what represents).
          guard event.characters == key && event.modifierFlags.intersection(.primary) == modifiers else {
            return event
          }

          if repeating || !event.isARepeat {
            body()
          }

          // This should return nil, but if the user has multiple windows, it'll only be reflected in the oldest window.
          // Since it doesn't, the user hears the "unknown command" sound, which is not ideal.
          return event
        }
      }.onDisappear {
        print("[Appearance] Releasing monitor!")

        guard let monitor else {
          return
        }

        NSEvent.removeMonitor(monitor)
      }
  }
}

extension View {
  func onKey(
    _ key: String,
    modifiers: NSEvent.ModifierFlags,
    repeating: Bool = false,
    body: @escaping () -> Void
  ) -> some View {
    self.modifier(KeyMonitorViewModifier(key: key, modifiers: modifiers, repeating: repeating, body: body))
  }
}
