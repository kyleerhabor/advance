//
//  AdvanceApp.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/23.
//

import AdvanceData
import Foundation
import GRDB
import OSLog
import SwiftUI

@main
struct AdvanceApp: App {
  @NSApplicationDelegateAdaptor private var delegate: AppDelegate2
  @State private var app = AppModel()
  @State private var search = SearchSettingsModel()
  @State private var folders = FoldersSettingsModel2()

  var body: some Scene {
    AppScene()
      .commands {
        AppCommands()
      }
      .environment(app)
      .environment(search)
      .environment(folders)
      .environmentObject(delegate)
      .defaultAppStorage(.default)
  }

  init() {
    let search = search

    Task {
      await search.load()
    }
  }
}
