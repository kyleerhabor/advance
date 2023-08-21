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

struct SettingsView: View {
  typealias Scheme = ColorScheme?

  @AppStorage(Keys.margin.key) private var margin = Keys.margin.value
  @AppStorage(Keys.appearance.key) private var appearance: Scheme
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var liveTextIcons = Keys.liveTextIcon.value

  var body: some View {
    let margin = Binding {
      Double(self.margin)
    } set: { margin in
      self.margin = Int(margin)
    }

    Form {
      Picker("Appearance:", selection: $appearance) {
        Text("System")
          .tag(nil as Scheme)

        Divider()

        Text("Light").tag(.light as Scheme)
        Text("Dark").tag(.dark as Scheme)
      }.onChange(of: appearance) {
        NSApp.appearance = appearance?.app()
      }

      Slider(value: margin, in: 0...4, step: 1) {
        Text("Margins:")
      } minimumValueLabel: {
        Text("None")
      } maximumValueLabel: {
        Text("A lot")
      }.padding(.vertical, 8)

      LabeledContent("Live Text:") {
        VStack(alignment: .leading) {
          Toggle("Enable Live Text", isOn: $liveText)

          Toggle("Show icons", isOn: $liveTextIcons)
            .disabled(!liveText)
        }
      }
    }
    .frame(width: 384)
    .scenePadding()
  }
}

#Preview {
  SettingsView()
}
