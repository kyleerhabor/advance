//
//  SettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

struct SettingsView: View {
  @State private var tab = Tab.extra

  var body: some View {
    // TODO: Figure out how to animate tab changes.
    TabView(selection: $tab) {
      Form {
        SettingsExtraView()
      }
      .tag(Tab.extra)
      .tabItem {
        Label("Extra", systemImage: "wand.and.stars")
      }
    }
    .frame(width: 384) // 256 - 512
    .scenePadding()
    .frame(width: 576) // 512 - 640
  }

  enum Tab {
    case extra
  }
}
