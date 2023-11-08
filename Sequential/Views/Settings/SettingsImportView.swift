//
//  SettingsImportView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/12/23.
//

import SwiftUI

struct SettingsImportView: View {
  @AppStorage(Keys.importHidden.key) private var importHidden = Keys.importHidden.value
  @AppStorage(Keys.importLimit.key) private var importLimit = Keys.importLimit.value
  @State private var subfolders = 1.0
  @State private var limit = TripleCardinality.none
  let subfoldersRange = 1...Double(Int.max)

  var body: some View {
    LabeledContent("Files:") {
      Toggle("Include hidden files", isOn: $importHidden)
    }

    LabeledContent("Folders:") {
      GroupBox {
        Picker(selection: $limit) {
          Text("Do not search subfolders")
            .tag(TripleCardinality.none)

          Text("Search up to a specified number of subfolders")
            .tag(TripleCardinality.some)

          Text("Search all subfolders")
            .tag(TripleCardinality.all)
        } label: {
          // Empty.
        }.pickerStyle(.radioGroup)

        Stepper("Number of subfolders to search:", value: $subfolders, in: 1...Double(Int.max), step: 1, format: .number)
          .disabled(limit != .some)
      }
    }
    // This is a bit weird, but has a very intentional design. We want any changes to importLimit from anywhere to be
    // reflected here, but also need to consider this view's local `limit` so a .some with a max of 0 doesn't switch to .none
    .onChange(of: importLimit, initial: true) {
      switch importLimit {
        case .max(let max):
          if max == 0 {
            limit = .none

            return
          }

          limit = .some
          subfolders = Double(max)
        case .unbound: limit = .all
      }
    }.onChange(of: limit) {
      updateLimit()
    }.onChange(of: subfolders) {
      updateLimit()
    }
  }

  func updateLimit() {
    importLimit = switch limit {
      case .none: .max(0)
      case .some: .max(Int(subfoldersRange.clamp(subfolders)))
      case .all: .unbound
    }
  }
}

#Preview {
  SettingsImportView()
}
