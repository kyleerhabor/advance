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
        if let sequence {
          SequenceView(sequence: sequence)
            .windowed()
        }
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
