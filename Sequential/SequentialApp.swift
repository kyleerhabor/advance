//
//  SequentialApp.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import SwiftUI
import OSLog

@main
struct SequentialApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @Environment(\.dismissWindow) private var dismissWindow
  @Environment(\.openWindow) private var openWindow

  var body: some Scene {
    Group {
      WindowGroup("Sequential", id: "app") {
        ContentView()
      }.commands {
        AppCommands {
          dismissWindow(id: "app")
        }

        CommandGroup(after: .windowArrangement) {
          Color.clear.onAppear {
            delegate.onOpenURL = { urls in
              openWindow(value: Sequence(from: urls))
            }
          }
        }
      }

      WindowGroup(for: Sequence.self) { $sequence in
        // When I use the initializer with the default value parameter, the result isn't persisted.
        if let seq = Binding($sequence) {
          SequenceView(sequence: seq)
            .windowed()
        }
      }
      // TODO: Figure out how to remove the tab bar functionality.
      .commands {
        // FIXME: The images in the ScrollView sometimes flashes when toggling the sidebar.
        SidebarCommands()
      }
    }
    // This is required for imports using the document types feature (e.g. dropping a set of images on to the dock icon)
    // to not create additional windows for each import (even when only one actually receives the content).
    .handlesExternalEvents(matching: [])

    Settings {
      SettingsView()
    }
  }
}
