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

      SequenceScene()
    }
    // This is required for imports using the document types feature (e.g. dropping a set of images on to the dock icon)
    // to not create additional windows for each import (even when only one actually receives the content).
    .handlesExternalEvents(matching: [])

    Settings {
      SettingsView()
    }
  }
}
