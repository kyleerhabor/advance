//
//  FoldersSettingsScene.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import SwiftUI

struct FoldersSettingsScene: Scene {
  @Environment(FoldersSettingsModel.self) private var folders
  @Environment(\.locale) private var locale
  @State private var task: Task<Void, Never>?
  static let id = "folders"

  var body: some Scene {
    SwiftUI.Window("Settings.Accessory.Folders.Window.Title", id: Self.id) {
      FoldersSettingsView()
        .frame(width: 600, height: 300)
    }
    .windowToolbarStyle(.unifiedCompact)
    .windowResizability(.contentSize)
    .keyboardShortcut(.foldersSettings)
    .onChange(of: self.locale, initial: true) {
      self.task?.cancel()
      self.task = Task {
        await self.folders.load(locale: self.locale)
      }
    }
  }
}
