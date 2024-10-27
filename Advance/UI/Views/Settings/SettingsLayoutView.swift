//
//  SettingsLayoutView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/27/24.
//

import SwiftUI

struct SettingsLayoutView: View {
  @AppStorage(StorageKeys.layoutStyle) private var style
  @AppStorage(StorageKeys.layoutContinuousStyleHidden) private var continuousStyleHidden

  var body: some View {
    Form {
      LabeledContent("Settings.Layout.Continuous") {
        GroupBox {
          HStack(alignment: .firstTextBaseline) {
            Toggle("Settings.Layout.Continuous.Hidden.Toolbar", isOn: $continuousStyleHidden.toolbar)

            Toggle("Settings.Layout.Continuous.Hidden.Cursor", isOn: $continuousStyleHidden.cursor)

            Toggle("Settings.Layout.Continuous.Hidden.Scroll", isOn: $continuousStyleHidden.scroll)
          }
        } label: {
          Toggle(
            "Settings.Layout.Continuous.Hidden",
            sources: [$continuousStyleHidden.toolbar, $continuousStyleHidden.cursor, $continuousStyleHidden.scroll],
            isOn: \.self
          )
        }
        .disabled(style != .continuous)
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }
}
