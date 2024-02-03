//
//  AdvanceApp.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/23.
//

import OSLog
import SwiftUI

@main
struct AdvanceApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @State private var depot = CopyDepot()

  var body: some Scene {
    Group {
      ImageCollectionScene()
        .handlesExternalEvents(matching: [])

      Settings {
        SettingsView()
      }
    }
    .environment(depot)
    .environmentObject(delegate)
  }

  init() {
    Task(priority: .background) {
      await Self.initialize()
    }
  }

  static func initialize() async {
    do {
      try FileManager.default.removeItem(at: .temporaryLiveTextImagesDirectory)
    } catch let err as CocoaError where err.code == .fileNoSuchFile {
      // The directory does not exist, so we do not care.
    } catch {
      Logger.standard.error("Could not remove Live Text images directory: \(error)")
    }
  }
}
