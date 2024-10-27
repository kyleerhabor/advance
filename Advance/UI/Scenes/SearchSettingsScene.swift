//
//  SearchSettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/31/24.
//

import SwiftUI

struct SearchSettingsScene: Scene {
  static let id = "search"

  var body: some Scene {
    Window("Settings.Accessory.Search.Window.Title", id: Self.id) {
      SearchSettingsView()
        .localized()
        .frame(width: 625, height: 250)
    }
    .windowResizability(.contentSize)
    .windowToolbarStyle(.unifiedCompact)
    .keyboardShortcut(.searchSettings)
  }
}
