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
  @AppStorage(StorageKeys.copyingResolveConflicts) private var copyingResolveConflicts
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

      LabeledContent("Settings.Accessories.Copying") {
        VStack(alignment: .leading) {
          Button("Settings.Accessories.Copying.Manage") {
            openWindow(id: CopyingSettingsScene.id)
          }
          .buttonStyle(.accessory)

          Toggle(isOn: $copyingResolveConflicts) {
            Text("Settings.Accessories.Copying.ResolveConflicts")

            Text("Settings.Accessories.Copying.ResolveConflicts.Note")
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
