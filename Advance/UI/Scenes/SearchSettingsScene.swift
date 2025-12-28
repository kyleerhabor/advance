//
//  SearchSettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/23/25.
//

import SwiftUI

struct SearchSettingsScene: Scene {
  static let id = "search2"

  var body: some Scene {
    SwiftUI.Window("Settings.Accessory.Search.Window.Title", id: Self.id) {
      SearchSettingsView()
        .frame(width: 600, height: 300)
    }
    .windowResizability(.contentSize)
    .windowToolbarStyle(.unifiedCompact)
    .keyboardShortcut(.searchSettings)
  }
}
