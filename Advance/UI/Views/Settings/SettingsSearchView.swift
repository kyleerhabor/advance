//
//  SettingsSearchView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/28/24.
//

import SwiftUI
import VisionKit

struct SettingsSearchView: View {
  @Environment(SearchSettingsModel.self) private var search
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.searchUseSystemDefault) private var searchUseSystemDefault
  @State private var isPresented = false
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
      LabeledContent("Settings.Search.Engine") {
        VStack(alignment: .leading) {
          HStack(alignment: .firstTextBaseline) {
            Picker("Settings.Search.Engine.Use", selection: engine) {
              Section {
                Text("Settings.Search.Engine.Use.None")
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
            
            Button("Settings.Search.Engine.Manage") {
              openWindow(id: SearchSettingsScene.id)
            }
            .buttonStyle(.accessory)
          }
          
          Toggle(isOn: $searchUseSystemDefault) {
            Text("Settings.Search.Engine.Default")
            
            Text("Settings.Search.Engine.Default.Note")
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }
}
