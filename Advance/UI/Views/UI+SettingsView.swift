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
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: 0)

      configuration.label
        .frame(width: width * 0.35, alignment: .trailing)

      VStack(alignment: .leading) {
        configuration.content
          .groupBoxStyle(.settings)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: width * 0.65, alignment: .leading)

      Color.clear
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
  static let contentWidth: CGFloat = 500
  static let pickerWidth: CGFloat = 150
  static let sliderWidth: CGFloat = 200

  var body: some View {
    TabView {
      SettingsGeneralView()
        .tabItem {
          Label("Settings.Tab.General", systemImage: "gearshape")
        }

      SettingsFilesView()
        .tabItem {
          Label("Settings.Tab.Files", systemImage: "folder")
        }

      SettingsAccessoriesView()
        .tabItem {
          Label("Settings.Tab.Accessories", systemImage: "macwindow.badge.plus")
        }
    }
    .scenePadding()
  }
}
