//
//  SequentialApp.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import OSLog
import SwiftUI

@main
struct SequentialApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @State private var copyDepot = CopyDepot()

  var body: some Scene {
    Group {
      ImageCollectionScene()
        .handlesExternalEvents(matching: [])

      Settings {
        SettingsView()
      }
      // FIXME: This isn't giving it a default size of its minimum (the first time).
//      .windowResizability(.contentMinSize)
    }
    .environment(copyDepot)
    .environmentObject(delegate)
  }

  init() {
    Task(priority: .background) {
      await Self.initialize()
    }
  }

  static func initialize() async {
    do {
      try FileManager.default.removeItem(at: .liveTextDownsampledDirectory)
    } catch {
      if let err = error as? CocoaError, err.code == .fileNoSuchFile {
        return
      }

      Logger.startup.error("Could not delete Live Text downsampled directory: \(error)")
    }
  }
}
