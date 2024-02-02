//
//  SettingsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

struct SettingsGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      configuration.content
    }
  }
}

struct SettingsLabeledGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      configuration.label

      VStack(alignment: .leading) {
        configuration.content
          .groupBoxStyle(.settings)
      }.padding(.leading)
    }
  }
}

extension GroupBoxStyle where Self == SettingsGroupBoxStyle {
  static var settings: SettingsGroupBoxStyle { .init() }
}

extension GroupBoxStyle where Self == SettingsLabeledGroupBoxStyle {
  static var settingsLabeled: SettingsLabeledGroupBoxStyle { .init() }
}

struct SettingsLabeledContentStyle: LabeledContentStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(alignment: .firstTextBaseline) {
      configuration.label
        .alignmentGuide(.keyed) { dimensions in
          dimensions[HorizontalAlignment.trailing]
        }

      VStack(alignment: .leading) {
        configuration.content
          .groupBoxStyle(.settings)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

extension LabeledContentStyle where Self == SettingsLabeledContentStyle {
  static var settings: SettingsLabeledContentStyle { .init() }
}

struct KeyedHorizontalAlignment: AlignmentID {
  static func defaultValue(in context: ViewDimensions) -> CGFloat {
    context[HorizontalAlignment.center]
  }
}

extension HorizontalAlignment {
  static let keyed = HorizontalAlignment(KeyedHorizontalAlignment.self)
}

struct SettingsFormStyle: FormStyle {
  let spacing: CGFloat?

  init(spacing: CGFloat? = nil) {
    self.spacing = spacing
  }

  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .keyed, spacing: spacing) {
      configuration.content
        .labeledContentStyle(.settings)
    }
  }
}

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
        SettingsImportView()
      }
      .tag(Tab.importing)
      .tabItem {
        Label("Import", systemImage: "square.and.arrow.down")
      }

      Form {
        SettingsExtraView()
      }
      .tag(Tab.extra)
      .tabItem { 
        Label("Extra", systemImage: "wand.and.stars")
      }
    }
    .formStyle(SettingsFormStyle(spacing: 16))
    .frame(width: 384) // 256 - 512
    .scenePadding()
    .frame(width: 576) // 512 - 640
  }

  enum Tab {
    case general, importing, extra
  }
}
