//
//  SettingsGeneralView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import Defaults
import SwiftUI
import VisionKit

struct SettingsGeneralView: View {
  @AppStorage(StorageKeys.collapseMargins) private var collapseMargins
  @AppStorage(StorageKeys.hiddenLayout) private var hiddenLayout
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextIconEnabled) private var isLiveTextIconEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  @AppStorage(StorageKeys.margins) private var margins
  @AppStorage(StorageKeys.restoreLastImage) private var restoreLastImage
  @Default(.colorScheme) private var colorScheme
  private let isImageAnalysisSupported = ImageAnalyzer.isSupported

  var body: some View {
    Form {
      LabeledContent("Settings.General.Appearance") {
        Picker("Settings.General.Appearance.Theme", selection: $colorScheme) {
          Section {
            Text("Settings.General.Appearance.Theme.System")
              .tag(DefaultColorScheme.system)
          }

          Section {
            Text("Settings.General.Appearance.Theme.Light")
              .tag(DefaultColorScheme.light)

            Text("Settings.General.Appearance.Theme.Dark")
              .tag(DefaultColorScheme.dark)
          }
        }
        .labelsHidden()
        .frame(width: SettingsView2.pickerWidth)
      }

      LabeledContent("Settings.General.Window") {
        Toggle(isOn: $restoreLastImage) {
          Text("Settings.General.Window.ImageRestore")

          Text("Settings.General.Window.ImageRestore.Note")
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      LabeledContent("Settings.General.Margins") {
        VStack(spacing: 0) {
          let range = 0.0...4.0
          let step = 1.0

          Slider(value: $margins, in: range, step: step) {
            Text("Settings.General.Margins.Label")
          }
          .labelsHidden()

          HStack {
            Button("Settings.General.Margins.Minimum") {
              margins = max(range.lowerBound, margins - step)
            }

            Spacer()

            Button("Settings.General.Margins.Maximum") {
              margins = min(range.upperBound, margins + step)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .buttonStyle(.plain)
        }
        .frame(width: SettingsView2.sliderWidth)

        Toggle(isOn: $collapseMargins) {
          Text("Settings.General.Margins.Collapse")

          Text("Settings.General.Margins.Collapse.Note")
        }
        .disabled(margins == 0)
      }

      LabeledContent("Settings.General.Layout") {
        GroupBox {
          HStack(alignment: .firstTextBaseline) {
            Toggle("Settings.General.Layout.Hidden.Toolbar", isOn: $hiddenLayout.toolbar)

            Toggle("Settings.General.Layout.Hidden.Cursor", isOn: $hiddenLayout.cursor)

            Toggle("Settings.General.Layout.Hidden.Scroll", isOn: $hiddenLayout.scroll)
          }
        } label: {
          Toggle(
            "Settings.General.Layout.Hidden",
            sources: [$hiddenLayout.toolbar, $hiddenLayout.cursor, $hiddenLayout.scroll],
            isOn: \.self
          )
        }
      }

      LabeledContent("Settings.General.LiveText") {
        VStack(alignment: .leading) {
          Toggle("Settings.General.LiveText.Enable", isOn: $isLiveTextEnabled)

          GroupBox {
            Toggle("Settings.General.LiveText.Icon", isOn: $isLiveTextIconEnabled)

            Toggle(isOn: $isLiveTextSubjectEnabled) {
              Text("Settings.General.LiveText.Subject")

              Text("Settings.General.LiveText.Subject.Note")
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .groupBoxStyle(.settingsGrouped)
          .disabled(!isLiveTextEnabled)
        }
        .disabled(!isImageAnalysisSupported)
        .help(isImageAnalysisSupported ? Text() : Text("Settings.LiveText.Unsupported"))
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }
}
