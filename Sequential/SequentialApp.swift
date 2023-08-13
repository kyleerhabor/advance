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

  var body: some Scene {
    SequenceScene()
      // This is required for imports using the document types feature (e.g. dropping a set of images on to the dock icon)
      // to not create additional windows for each import (even when only one actually receives the content).
      .handlesExternalEvents(matching: [])

    Settings {
      SettingsView()
    }
  }
}
