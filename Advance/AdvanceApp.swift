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
  @State private var copying = CopyingSettingsModel()

  var body: some Scene {
    AppScene()
      .environment(search)
      .environment(copying)
      .environmentObject(delegate)
  }

  init() {
    let search = search
    let copying = copying

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
