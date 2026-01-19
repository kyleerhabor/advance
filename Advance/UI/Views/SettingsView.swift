//
//  SettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import SwiftUI

struct SettingsGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) { // 2^2 + 2^1
      configuration.content
    }
  }
}

extension GroupBoxStyle where Self == SettingsGroupBoxStyle {
  static var settings: SettingsGroupBoxStyle {
    SettingsGroupBoxStyle()
  }
}

struct SettingsLabeledGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) { // 2^2 + 2^1
      configuration.label

      configuration.content
        .padding(.leading)
    }
  }
}

extension GroupBoxStyle where Self == SettingsLabeledGroupBoxStyle {
  static var settingsLabeled: SettingsLabeledGroupBoxStyle {
    SettingsLabeledGroupBoxStyle()
  }
}

struct SettingsLabeledContentStyle: LabeledContentStyle {
  let width: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    // There's probably a better way to model this, but we want all tabs to share the same alignment.
    GridRow(alignment: .firstTextBaseline) {
      Color.clear
        .frame(maxWidth: .infinity, maxHeight: 0)

      configuration.label
        .frame(width: self.width * 0.35, alignment: .trailing)

      VStack(alignment: .leading) {
        configuration.content
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(width: self.width * 0.65, alignment: .leading)

      Color.clear
        .frame(maxWidth: .infinity, maxHeight: 0)
    }
  }
}

extension LabeledContentStyle where Self == SettingsLabeledContentStyle {
  static func settings(width: CGFloat) -> some LabeledContentStyle {
    SettingsLabeledContentStyle(width: width)
  }
}

struct SettingsFormStyle: FormStyle {
  let width: CGFloat

  func makeBody(configuration: Configuration) -> some View {
    Grid {
      configuration.content
        .labeledContentStyle(.settings(width: self.width))
    }
  }
}

extension FormStyle where Self == SettingsFormStyle {
  static func settings(width: CGFloat) -> some FormStyle {
    SettingsFormStyle(width: width)
  }
}

struct SettingsView: View {
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
