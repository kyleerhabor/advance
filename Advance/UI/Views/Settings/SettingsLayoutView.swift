//
//  SettingsLayoutView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/24.
//

import SwiftUI

struct SettingsLayoutView: View {
  @AppStorage(StorageKeys.hiddenLayoutStyles) private var hiddenLayoutStyles

  var body: some View {
    Form {
      LabeledContent("Settings.Layout.Continuous") {
        GroupBox {
          HStack(alignment: .firstTextBaseline) {
            Toggle("Settings.Layout.Continuous.Hidden.Toolbar", isOn: $hiddenLayoutStyles.toolbar)

            Toggle("Settings.Layout.Continuous.Hidden.Cursor", isOn: $hiddenLayoutStyles.cursor)

            Toggle("Settings.Layout.Continuous.Hidden.Scroll", isOn: $hiddenLayoutStyles.scroll)
          }
        } label: {
          Toggle(
            "Settings.Layout.Continuous.Hidden",
            sources: [$hiddenLayoutStyles.toolbar, $hiddenLayoutStyles.cursor, $hiddenLayoutStyles.scroll],
            isOn: \.self
          )
        }
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }
}
