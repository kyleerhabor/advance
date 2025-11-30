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
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
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

      LabeledContent("Settings.Accessories.FoldersPathSeparator") {
        Picker("Settings.Accessories.FoldersPathSeparator.Use", selection: $foldersPathSeparator) {
          let separators: [StorageFoldersPathSeparator] = [
            .singlePointingAngleQuotationMark,
            .blackPointingSmallTriangle,
            .blackPointingTriangle,
            .inequalitySign,
          ]

          ForEach(separators, id: \.self) { separator in
            Text(pathComponent(of: separator, in: foldersPathDirection))
              .tag(separator, includeOptional: false)
          }
        }
        .disabled(!resolveConflicts)
        .pickerStyle(.inline)
        .labelsHidden()
        .horizontalRadioGroupLayout()
      }

      LabeledContent("Settings.Accessories.FoldersPathDirection") {
        Picker("Settings.Accessories.FoldersPathDirection.Use", selection: $foldersPathDirection) {
          Text("Settings.Accessories.FoldersPathDirection.Use.Leading")
            .tag(StorageFoldersPathDirection.leading, includeOptional: false)

          Text("Settings.Accessories.FoldersPathDirection.Use.Trailing")
            .tag(StorageFoldersPathDirection.trailing, includeOptional: false)
        }
        .disabled(!resolveConflicts)
        .pickerStyle(.inline)
        .labelsHidden()
        .horizontalRadioGroupLayout()
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }

  private func pathComponent(
    of separator: StorageFoldersPathSeparator,
    in direction: StorageFoldersPathDirection,
  ) -> LocalizedStringKey {
    switch (separator, direction) {
      case (.inequalitySign, .leading):
        "Settings.Accessories.FoldersPathSeparator.Use.InequalitySign.LeftToRight"
      case (.inequalitySign, .trailing):
        "Settings.Accessories.FoldersPathSeparator.Use.InequalitySign.RightToLeft"
      case (.singlePointingAngleQuotationMark, .leading):
        "Settings.Accessories.FoldersPathSeparator.Use.SinglePointingAngleQuotationMark.LeftToRight"
      case (.singlePointingAngleQuotationMark, .trailing):
        "Settings.Accessories.FoldersPathSeparator.Use.SinglePointingAngleQuotationMark.RightToLeft"
      case (.blackPointingTriangle, .leading):
        "Settings.Accessories.FoldersPathSeparator.Use.BlackPointingTriangle.LeftToRight"
      case (.blackPointingTriangle, .trailing):
        "Settings.Accessories.FoldersPathSeparator.Use.BlackPointingTriangle.RightToLeft"
      case (.blackPointingSmallTriangle, .leading):
        "Settings.Accessories.FoldersPathSeparator.Use.BlackPointingSmallTriangle.LeftToRight"
      case (.blackPointingSmallTriangle, .trailing):
        "Settings.Accessories.FoldersPathSeparator.Use.BlackPointingSmallTriangle.RightToLeft"
    }
  }
}

#Preview {
  SettingsAccessoriesView()
}
