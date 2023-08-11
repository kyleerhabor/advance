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
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.appearance.rawValue) private var appearance: SettingsView.Scheme

  var body: some Scene {
    Group {
      WindowGroup("Sequential", id: "app") {
        ContentView()
      }.commands {
        AppCommands()

        CommandGroup(after: .windowArrangement) {
          // This little hack allows us to do stuff with the UI on startup (since it's always called).
          Color.clear.onAppear {
            // We need to set NSApp's appearance explicitly so windows we don't directly control (such as the about)
            // will still sync with the user's preference.
            NSApp.appearance = appearance?.app()

            delegate.onOpenURL = { sequence in
              openWindow(value: sequence)
            }
          }
        }
      }

      // Idea: Add a feature that automatically removes borders embedded in images.
      WindowGroup(for: Sequence.self) { $sequence in
        // When I use the initializer with the default value parameter, the result isn't persisted.
        if let sequence {
          SequenceView(sequence: sequence)
            .windowed()
        }
      }
      .windowToolbarStyle(.unifiedCompact) // Sexy!
      // TODO: Figure out how to remove the tab bar functionality (for this window group specifically).
      //
      // TODO: Figure out how to add a "Go to Current Image" button.
      //
      // Last time, I tried with a callback, but the ScrollViewProxy wouldn't scroll.
      .commands {
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
