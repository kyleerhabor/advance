//
//  AdvanceApp.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/23.
//

import Foundation
import GRDB
import OSLog
import SwiftUI

@main
struct AdvanceApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate
  @State private var app = AppModel()
  @State private var folders = FoldersSettingsModel()
  @State private var search = SearchSettingsModel()

  var body: some Scene {
    AppScene()
      .handlesExternalEvents(matching: [])
      .commands {
        AppCommands()
      }
      .environment(self.search)
      .environment(self.folders)
      .environment(self.app)
      .environment(self.delegate)
  }

  init() {
    Task { [search = self.search] in
      await search.load()
    }

    Task {
      do {
        try await run(analyses, count: 10)
      } catch {
        // TODO: Elaborate.
        Logger.model.fault("\(error)")

        return
      }
    }
  }
}
