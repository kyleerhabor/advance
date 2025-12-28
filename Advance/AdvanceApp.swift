//
//  AdvanceApp.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/23.
//

import AdvanceCore
import Foundation
import GRDB
import OSLog
import SwiftUI

@main
struct AdvanceApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate2
  @State private var app = AppModel()
  @State private var folders = FoldersSettingsModel()
  @State private var search = SearchSettingsModel()

  var body: some Scene {
    AppScene()
      .commands {
        AppCommands()
      }
      .environment(app)
      .environment(folders)
      .environment(search)
      .environmentObject(delegate)
      .defaultAppStorage(.default)
  }

  init() {
    Task { [search] in
      await search.load()
    }

    Task {
      do {
        try await run(base: analyses, count: 10)
      } catch {
        // TODO: Elaborate.
        Logger.model.fault("\(error)")

        return
      }
    }
  }
}
