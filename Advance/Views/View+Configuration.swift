//
//  View+Configuration.swift
//  Advance
//
//  Created by Kyle Erhabor on 3/10/24.
//

import SwiftUI

struct EmptyTransition: Transition {
  func body(content: Content, phase: TransitionPhase) -> some View {
    content // Is this the same as IdentityTransition?
  }
}

extension Transition where Self == EmptyTransition {
  static var empty: EmptyTransition { .init() }
}

// MARK: - Alignment

struct KeyedHorizontalAlignment: AlignmentID {
  static func defaultValue(in context: ViewDimensions) -> CGFloat {
    context[HorizontalAlignment.center]
  }
}

extension HorizontalAlignment {
  static let keyed = HorizontalAlignment(KeyedHorizontalAlignment.self)
}

// MARK: - Settings

struct SettingsGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      configuration.content
    }
  }
}

extension GroupBoxStyle where Self == SettingsGroupBoxStyle {
  static var settings: SettingsGroupBoxStyle { .init() }
}

struct ContainerSettingsGroupBoxStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading) {
      configuration.content
        .groupBoxStyle(.settings)
    }
  }
}

extension GroupBoxStyle where Self == ContainerSettingsGroupBoxStyle {
  static var containerSettings: ContainerSettingsGroupBoxStyle { .init() }
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

extension GroupBoxStyle where Self == LabeledSettingsGroupBoxStyle {
  static var labeledSettings: LabeledSettingsGroupBoxStyle { .init() }
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
