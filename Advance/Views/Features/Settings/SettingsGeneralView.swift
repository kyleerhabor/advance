//
//  SettingsGeneralView.swift
//  Advance
//
//  Created by Kyle Erhabor on 10/12/23.
//

import Defaults
import SwiftUI

struct SettingsGeneralView: View {
  typealias Scheme = DefaultColorScheme?

  @Default(.margins) private var margins
  @Default(.collapseMargins) private var collapseMargins
  private let range = 0.0...4.0

  var body: some View {
    LabeledContent("Margins:") {
      let margins = Binding {
        Double(self.margins)
      } set: { margins in
        self.margins = Int(margins)
      }

      VStack(spacing: 0) {
        Slider(value: margins, in: range, step: 1)

        HStack {
          Button("None") {
            margins.wrappedValue = max(range.lowerBound, margins.wrappedValue.decremented())
          }

          Spacer()

          Button("A lot") {
            margins.wrappedValue = min(range.upperBound, margins.wrappedValue.incremented())
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
      }.frame(width: 215)

      Toggle(isOn: $collapseMargins) {
        Text("Collapse margins")

        Text("Images with adjacent borders will have their margins flattened into a single value.")
      }.disabled(margins.wrappedValue == 0)
    }
  }
}
