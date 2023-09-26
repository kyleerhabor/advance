//
//  SettingsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/30/23.
//

import SwiftUI

extension ColorScheme: RawRepresentable {
  public init?(rawValue: Int) {
    switch rawValue {
      case 0: self = .light
      case 1: self = .dark
      default: return nil
    }
  }
  
  public var rawValue: Int {
    switch self {
      case .light: 0
      case .dark: 1
      @unknown default: -1
    }
  }

  func app() -> NSAppearance? {
    switch self {
      case .light: .init(named: .aqua)
      case .dark: .init(named: .darkAqua)
      @unknown default: nil
    }
  }
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
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .keyed, spacing: 16) {
      configuration.content
        .labeledContentStyle(.settings)
    }
  }
}

extension FormStyle where Self == SettingsFormStyle {
  static var settings: SettingsFormStyle { .init() }
}

struct SettingsView: View {
  typealias Scheme = ColorScheme?

  @AppStorage(Keys.appearance.key) private var appearance: Scheme
  @AppStorage(Keys.margin.key) private var margin = Keys.margin.value
  @AppStorage(Keys.collapseMargins.key) private var collapseMargins = Keys.collapseMargins.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var liveTextIcons = Keys.liveTextIcon.value
  @State private var showingDestinations = false
  private let range = 0.0...4.0

  var body: some View {
    Form {
      LabeledContent("Appearance:") {
        Picker("Theme:", selection: $appearance) {
          Text("System")
            .tag(nil as Scheme)

          Divider()

          Text("Light").tag(.light as Scheme)
          Text("Dark").tag(.dark as Scheme)
        }
        .labelsHidden()
        .frame(width: 160) // 128 - 192
        .onChange(of: appearance) {
          NSApp.appearance = appearance?.app()
        }
      }

      let margin = Binding {
        Double(self.margin)
      } set: { margin in
        self.margin = Int(margin)
      }

      LabeledContent("Margins:") {
        VStack(spacing: 0) {
          Slider(value: margin, in: range, step: 1)

          HStack {
            Button("None") {
              margin.wrappedValue = max(range.lowerBound, margin.wrappedValue - 1)
            }

            Spacer()

            Button("A lot") {
              margin.wrappedValue = min(range.upperBound, margin.wrappedValue + 1)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          .buttonStyle(.plain)
        }.frame(width: 215)

        Toggle(isOn: $collapseMargins) {
          Text("Collapse margins")

          Text("Images with adjacent borders will have their margins flattened into a single value.")
        }.disabled(margin.wrappedValue == 0)
      }

      LabeledContent("Live Text:") {
        VStack(alignment: .leading, spacing: 6) {
          Toggle("Enable Live Text", isOn: $liveText)

          Toggle("Show icons", isOn: $liveTextIcons)
            .disabled(!liveText)
        }
      }

      LabeledContent("Copying:") {
        Button("Show Destinations...") {
          showingDestinations = true
        }.sheet(isPresented: $showingDestinations) {
          // FIXME: This can take a while to appear.
          SettingsDestinationsView()
        }
      }
    }
    .formStyle(.settings)
    .frame(width: 384) // 256 - 512
    .scenePadding()
    .frame(width: 576) // 512 - 640
  }
}

#Preview {
  SettingsView()
}
