//
//  SettingsView.swift
//  Advance
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

struct ContainerSettingsGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading) {
      configuration.content
        .groupBoxStyle(.settings)
    }
  }
}

struct LabeledSettingsGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      configuration.label

      GroupBox {
        configuration.content
      }
      .groupBoxStyle(.containerSettings)
      .padding(.leading)
    }
  }
}

extension GroupBoxStyle where Self == SettingsGroupBoxStyle {
  static var settings: SettingsGroupBoxStyle { .init() }
}

extension GroupBoxStyle where Self == LabeledSettingsGroupBoxStyle {
  static var labeledSettings: LabeledSettingsGroupBoxStyle { .init() }
}

extension GroupBoxStyle where Self == ContainerSettingsGroupBoxStyle {
  static var containerSettings: ContainerSettingsGroupBoxStyle { .init() }
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
