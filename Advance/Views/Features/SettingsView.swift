//
//  SettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

struct SettingsView: View {
  @State private var tab = Tab.general

  var body: some View {
    // TODO: Figure out how to animate tab changes.
    TabView(selection: $tab) {
      Form {
        SettingsGeneralView()
      }
      .tag(Tab.general)
      .tabItem {
        Label("General", systemImage: "gearshape")
      }

      Form {
        SettingsExtraView()
      }
      .tag(Tab.extra)
      .tabItem {
        Label("Extra", systemImage: "wand.and.stars")
      }
    }
//    .formStyle(SettingsFormStyle())
    .frame(width: 384) // 256 - 512
    .scenePadding()
    .frame(width: 576) // 512 - 640
  }

  enum Tab {
    case general, files, extra
  }
}
