//
//  SettingsGeneralView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import Defaults
import SwiftUI
import VisionKit

struct SettingsGeneralView2: View {
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.restoreLastImage) private var restoreLastImage
  @AppStorage(StorageKeys.layoutStyle) private var layoutStyle
  @AppStorage(StorageKeys.liveTextEnabled) private var liveTextEnabled
  @AppStorage(StorageKeys.liveTextIcon) private var liveTextIcon
  @AppStorage(StorageKeys.liveTextSubject) private var liveTextSubject
  @AppStorage(StorageKeys.copyingResolveConflicts) private var copyingResolveConflicts
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

      LabeledContent("Settings.General.Layout") {
        Picker("Settings.General.Layout.Style", selection: $layoutStyle) {
          Text("Settings.General.Layout.Style.Continuous")
            .tag(StorageImagesLayoutStyle.continuous)

          Text("Settings.General.Layout.Style.Paged")
            .tag(StorageImagesLayoutStyle.paged)
        }
        .labelsHidden()
        .frame(width: SettingsView2.pickerWidth)
      }

      LabeledContent("Settings.General.LiveText") {
        VStack(alignment: .leading) {
          Toggle("Settings.General.LiveText.Enabled", isOn: $liveTextEnabled)

          GroupBox {
            Toggle("Settings.General.LiveText.Icon", isOn: $liveTextIcon)
              .disabled(!liveTextEnabled)

            Toggle(isOn: $liveTextSubject) {
              Text("Settings.General.LiveText.Subject")

              Text("Settings.General.LiveText.Subject.Note")
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .groupBoxStyle(.settingsGrouped)
        }
        .disabled(!isImageAnalysisSupported)
        .help(isImageAnalysisSupported ? Text() : Text("Settings.LiveText.Unsupported"))
      }

      LabeledContent("Settings.General.Copying") {
        VStack(alignment: .leading) {
          Button("Settings.General.Copying.Manage") {
            openWindow(id: CopyingSettingsScene.id)
          }
          .buttonStyle(.accessory)

          Toggle(isOn: $copyingResolveConflicts) {
            Text("Settings.General.Copying.ResolveConflicts")

            Text("Settings.General.Copying.ResolveConflicts.Note")
          }
        }
      }
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }
}
