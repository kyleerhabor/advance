//
//  SequentialApp.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import SwiftUI

@main
struct SequentialApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate

  var body: some Scene {
    SequenceScene()
      // For some reason, the delegate is not being placed in the environment (even though the property wrapper says it
      // will). Maybe it only applies to views and not scenes?
      .environmentObject(delegate)
      // This is required for imports using the document types feature (e.g. dropping a set of images on to the dock icon)
      // to not create additional windows for each import (even when only one actually receives the content).
      .handlesExternalEvents(matching: [])

    Settings {
      SettingsView()
    }.windowResizability(.contentMinSize)
  }
}
