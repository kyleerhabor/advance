//
//  SearchSettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/23/25.
//

import OSLog
import SwiftUI

struct SearchSettingsNameView: View {
  @Bindable var item: SearchSettingsItemModel

  var body: some View {
    TextField(
      "Settings.Accessory.Search.Name.Label",
      text: $item.name,
      prompt: Text("Settings.Accessory.Search.Name.Prompt"),
    )
  }
}

struct SearchSettingsLocationView: View {
  @Environment(\.locale) private var locale
  @Bindable var item: SearchSettingsItemModel

  var body: some View {
    TokenTextFieldView(
      tokens: $item.location,
      prompt: String(localized: "Settings.Accessory.Search.Location.Prompt", locale: locale),
      tokenizer: { SearchSettingsItemModel.tokenize($0) },
      detokenizer: { SearchSettingsItemModel.detokenize($0) },
      tokenLabel: { token in
        switch token {
          case SearchSettingsItemModel.queryToken:
            String(localized: "Settings.Accessory.Search.Location.Token.Query", locale: locale)
          default:
            token
        }
      },
      tokenStyle: { token in
        switch token {
          case SearchSettingsItemModel.queryToken: .rounded
          default: .none
        }
      },
    )
  }
}

enum SearchSettingsViewFocus {
  case name(SearchSettingsItemModel.ID),
       location(SearchSettingsItemModel.ID)
}

extension SearchSettingsViewFocus: Hashable {}

struct SearchSettingsView: View {
  @Environment(SearchSettingsModel.self) private var search
  @Environment(\.locale) private var locale
  @State private var selection = Set<SearchSettingsItemModel.ID>()
  @FocusState private var focus: SearchSettingsViewFocus?

  var body: some View {
    Table(of: SearchSettingsItemModel.self, selection: $selection) {
      TableColumn("Settings.Accessory.Search.Column.Name") { item in
        SearchSettingsNameView(item: item)
          .focused($focus, equals: .name(item.id))
      }

      TableColumn("Settings.Accessory.Search.Column.Location") { item in
        SearchSettingsLocationView(item: item)
          .focused($focus, equals: .location(item.id))
      }
    } rows: {
      ForEach(search.items) { item in
        TableRow(item)
          .draggable(SearchSettingsItemModelID(id: item.id))
      }
      .dropDestination(for: SearchSettingsItemModelID.self) { offset, items in
        Task {
          await search.move(items: items, toOffset: offset)
        }
      }
    }
    .animation(.default, value: search.items)
    .contextMenu(forSelectionType: SearchSettingsItemModel.ID.self) { items in
      Button("Settings.Accessory.Search.Toolbar.Remove", role: .destructive) {
        Task {
          await search.remove(items: items)
        }
      }
    }
    .toolbar {
      ToolbarItem {
        Button("Settings.Accessory.Search.Toolbar.Add", systemImage: "plus") {
          let item = SearchSettingsItemModel(id: UUID(), rowID: nil, name: "", location: [])
          search.add(item: item)
        }
      }
    }
    .onChange(of: focus) { value, _ in
      guard let value else {
        return
      }

      switch value {
        case let .name(item),
             let .location(item):
          Task {
            await search.store(item: item)
          }
      }
    }
  }
}

#Preview {
  SearchSettingsView()
}
