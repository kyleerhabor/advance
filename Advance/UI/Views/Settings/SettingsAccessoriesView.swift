//
//  SettingsAccessoriesView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/25/24.
//

import SwiftUI

struct SettingsAccessoriesView: View {
  @Environment(SearchSettingsModel.self) private var search
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.searchUseSystemDefault) private var searchUseSystemDefault
  private var engine: Binding<SearchSettingsEngineModel.ID?> {
    Binding {
      search.engine?.id
    } set: { id in
      search.engineID = id
      search.submitEngine()
    }
  }

  var body: some View {
    Form {
      LabeledContent("Settings.Accessories.SearchEngine") {
        VStack(alignment: .leading) {
          HStack(alignment: .firstTextBaseline) {
            Picker("Settings.Accessories.SearchEngine.Use", selection: engine) {
              Section {
                Text("Settings.Accessories.SearchEngine.Use.None")
                  .tag(nil as SearchSettingsEngineModel.ID?, includeOptional: false)
              }

              Section {
                ForEach(search.settingsEngines) { engine in
                  Text(engine.name)
                    .tag(engine.id as SearchSettingsEngineModel.ID?, includeOptional: false)
                }
              }
            }
            .disabled(searchUseSystemDefault)
            .labelsHidden()
            .frame(width: SettingsView2.pickerWidth)

            Button("Settings.Accessories.SearchEngine.Manage") {
              openWindow(id: SearchSettingsScene.id)
            }
            .buttonStyle(.accessory)
          }

          Toggle(isOn: $searchUseSystemDefault) {
            Text("Settings.Accessories.SearchEngine.Default")

            Text("Settings.Accessories.SearchEngine.Default.Note")
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      LabeledContent("Settings.Accessories.Folders") {
        VStack(alignment: .leading) {
          Button("Settings.Accessories.Folders.Manage") {
            openWindow(id: FoldersSettingsScene.id)
          }
          .buttonStyle(.accessory)

          Toggle(isOn: $resolveConflicts) {
            Text("Settings.Accessories.Folders.ResolveConflicts")

            Text("Settings.Accessories.Folders.ResolveConflicts.Note")
          }
        }
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }
}

#Preview {
  SettingsAccessoriesView()
}
