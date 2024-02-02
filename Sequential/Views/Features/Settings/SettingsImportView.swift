//
//  SettingsImportView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/12/23.
//

import Defaults
import SwiftUI

struct SettingsImportView: View {
  @Default(.importHiddenFiles) private var importHidden
  @Default(.importSubdirectories) private var importSubdirectories

  var body: some View {
    LabeledContent("Files:") {
      Toggle("Include hidden files", isOn: $importHidden)
    }

    LabeledContent("Folders:") {
      let binding = Binding {
        !importSubdirectories
      } set: { importSubdirectories = !$0 }

      Toggle("Do not search subfolders", isOn: binding)
    }
  }
}
