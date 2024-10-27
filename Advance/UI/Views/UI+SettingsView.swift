//
//  SettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import SwiftUI

extension EnvironmentValues {
  @Entry var settingsWidth = CGFloat.zero
}

struct SettingsGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) { // 2^2 + 2^1
      configuration.label

      configuration.content
        .groupBoxStyle(.settings)
        .padding(.leading)
    }
  }
}

struct SettingsGroupedGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) { // 2^2 + 2^1
      configuration.content
        .groupBoxStyle(.settings)
    }
  }
}

extension GroupBoxStyle where Self == SettingsGroupBoxStyle {
  static var settings: SettingsGroupBoxStyle {
    SettingsGroupBoxStyle()
  }
}


extension GroupBoxStyle where Self == SettingsGroupedGroupBoxStyle {
  static var settingsGrouped: SettingsGroupedGroupBoxStyle {
    SettingsGroupedGroupBoxStyle()
  }
}

struct SettingsLabeledContentStyle: LabeledContentStyle {
  @Environment(\.settingsWidth) private var width

  func makeBody(configuration: Configuration) -> some View {
    GridRow(alignment: .firstTextBaseline) {
      BlankView()
        .frame(maxWidth: .infinity, maxHeight: 0)

      configuration.label
        .frame(width: width * 0.3, alignment: .trailing)

      VStack(alignment: .leading) {
        configuration.content
          .groupBoxStyle(.settings)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: width * 0.7, alignment: .leading)

      BlankView()
        .frame(maxWidth: .infinity, maxHeight: 0)
    }
  }
}

extension LabeledContentStyle where Self == SettingsLabeledContentStyle {
  static var settings: SettingsLabeledContentStyle {
    SettingsLabeledContentStyle()
  }
}

struct SettingsFormStyle: FormStyle {
  let width: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    Grid {
      configuration.content
        .labeledContentStyle(.settings)
        .environment(\.settingsWidth, width)
    }
  }
}

extension FormStyle {
  static func settings(width: CGFloat) -> some FormStyle where Self == SettingsFormStyle {
    SettingsFormStyle(width: width)
  }
}

struct SettingsView2: View {
  static let contentWidth: CGFloat = 448 // 384 - 512
  static let pickerWidth: CGFloat = 128
  static let textFieldWidth: CGFloat = 192

  var body: some View {
    TabView {
      SettingsGeneralView2()
        .tabItem {
          Label("Settings.Tab.General", systemImage: "gearshape")
        }

      SettingsLayoutView()
        .tabItem {
          Label("Settings.Tab.Layout", systemImage: "align.vertical.center")
        }

      SettingsFilesView()
        .tabItem {
          Label("Settings.Tab.Files", systemImage: "folder")
        }

      SettingsSearchView()
        .tabItem {
          Label("Settings.Tab.Search", systemImage: "magnifyingglass")
        }

      SettingsExtraView2()
        .localized()
        .tabItem {
          Label("Extra", systemImage: "wand.and.stars")
        }
    }
    .scenePadding()
  }
}
