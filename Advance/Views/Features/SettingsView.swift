//
//  SettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

enum SettingsTab {
  case general, importing, extra
}

struct SettingsTabEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(SettingsTab.general)
}

extension EnvironmentValues {
  var settingsTab: SettingsTabEnvironmentKey.Value {
    get { self[SettingsTabEnvironmentKey.self] }
    set { self[SettingsTabEnvironmentKey.self] = newValue }
  }
}

struct SettingsView: View {
  @State private var tab = SettingsTab.general

  var body: some View {
    // TODO: Figure out how to animate tab changes.
    TabView(selection: $tab) {
      Form {
        SettingsGeneralView()
      }
      .tag(SettingsTab.general)
      .tabItem {
        Label("General", systemImage: "gearshape")
      }

      Form {
        SettingsImportView()
      }
      .tag(SettingsTab.importing)
      .tabItem {
        Label("Import", systemImage: "square.and.arrow.down")
      }

      Form {
        SettingsExtraView()
      }
      .tag(SettingsTab.extra)
      .tabItem {
        Label("Extra", systemImage: "wand.and.stars")
      }
    }
    .formStyle(SettingsFormStyle(spacing: 16))
    .frame(width: 384) // 256 - 512
    .scenePadding()
    .frame(width: 576) // 512 - 640
    .environment(\.settingsTab, $tab)
  }
}
