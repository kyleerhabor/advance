//
//  SettingsFilesView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/24/24.
//

import SwiftUI

struct SettingsFilesView: View {
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories

  var body: some View {
    Form {
      LabeledContent("Settings.Files.Import") {
        Toggle("Settings.Files.Import.Hidden", isOn: $importHiddenFiles)

        Toggle("Settings.Files.Import.Subdirectories", isOn: $importSubdirectories)
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }
}
