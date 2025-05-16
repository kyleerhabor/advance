//
//  SearchSettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/28/24.
//

import SwiftUI
import SwiftUIIntrospect

struct SearchSettingsView: View {
  @Environment(\.localize) private var localize
  @Environment(SearchSettingsModel.self) private var search
  @FocusState private var focus: TextFieldColumn?

  var body: some View {
    Table(of: SearchSettingsEngineModel.self) {
      TableColumn("Settings.Accessory.Search.Name") { engine in
        @Bindable var engine = engine

        TextField("Settings.Accessory.Search.Name.Label", text: $engine.name, prompt: Text("Settings.Accessory.Search.Name.Prompt"))
          .introspect(.textField, on: .macOS(.v14, .v15)) { textField in
            textField.drawsBackground = true
            textField.backgroundColor = nil
          }
          .focused($focus, equals: .name)
      }

      TableColumn("Settings.Accessory.Search.Location") { engine in
        TokenFieldReaderView { proxy in
          HStack(alignment: .firstTextBaseline) {
            let tokens = Binding {
              TokenFieldView.parse(token: engine.string, enclosing: SearchSettingsEngineModel.keywordEnclosing)
            } set: { tokens in
              engine.string = TokenFieldView.string(tokens: tokens)
            }

            TokenFieldView(
              prompt: localize("Settings.Accessory.Search.Location.Prompt"),
              isBezeled: false,
              tokens: tokens,
              enclosing: SearchSettingsEngineModel.keywordEnclosing
            ) { token in
              token == SearchSettingsEngineModel.keyword
            } title: { _ in
              localize("Settings.Accessory.Search.Token.Query")
            }
            .truncationMode(.middle)
            .focusEffectDisabled()
            .focused($focus, equals: .location)

            Button("Settings.Accessory.Search.Location.Substitute", systemImage: "placeholdertext.fill") {
              proxy.insert(
                token: SearchSettingsEngineModel.keyword,
                enclosing: SearchSettingsEngineModel.keywordEnclosing
              )

              if focus == nil {
                search.submitEngines()
              }
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .fontWeight(.semibold)
          }
        }
      }
    } rows: {
      ForEach(search.engines) { engine in
        TableRow(engine)
          .contextMenu {
            // Should we bother to add a confirmation dialog?
            Button("Settings.Accessory.Search.Delete", role: .destructive) {
              search.submit(removalOf: engine)
            }
          }
      }
    }
    .toolbar {
      Button {
        search.engines.append(SearchSettingsEngineModel(id: UUID(), name: "", string: ""))
      } label: {
        Label("Settings.Accessory.Search.Toolbar.Add", systemImage: "plus")
      }
    }
    .onChange(of: focus) { prior, column in
      // We only care about the "lost focus" state.
      guard prior != nil, column == nil else {
        return
      }

      search.submitEngines()
    }
  }

  enum TextFieldColumn: Hashable {
    case name, location
  }
}
