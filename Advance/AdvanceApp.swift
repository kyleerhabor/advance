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
  @State private var search = SearchSettingsModel()
  @State private var folders = FoldersSettingsModel()

  var body: some Scene {
    AppScene()
      .environment(search)
      .environment(folders)
      .environmentObject(delegate)
      .defaultAppStorage(.default)
  }

  init() {
    let search = search
    let copying = folders

    Task {
      await search.load()
    }

    Task {
      do {
        try await copying.load()
      } catch {
        Logger.model.error("\(error)")
      }
    }
  }
}
