//
//  SettingsImportView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/12/23.
//

import SwiftUI

struct SettingsImportView: View {
  @AppStorage(Keys.importHidden.key) private var importHidden = Keys.importHidden.value
  @AppStorage(Keys.importSubdirectories.key) private var importSubdirectories = Keys.importSubdirectories.value

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

#Preview {
  SettingsImportView()
}
