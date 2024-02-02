//
//  SettingsGeneralView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/12/23.
//

import Defaults
import SwiftUI
import VisionKit

struct SettingsGeneralView: View {
  typealias Scheme = ColorScheme?

  @Default(.margins) private var margins
  @Default(.colorScheme) private var colorScheme
  @Default(.collapseMargins) private var collapseMargins
  @Default(.liveText) private var liveText
  @Default(.liveTextIcon) private var liveTextIcon
  @Default(.liveTextSearchWith) private var liveTextSearchWith
  @Default(.displayTitleBarImage) private var displayTitleBarImage
  @Default(.hideToolbarScrolling) private var hideToolbar
  @Default(.hideCursorScrolling) private var hideCursor
  @Default(.hideScrollIndicator) private var hideScroll
  @Default(.resolveCopyingConflicts) private var resolveConflicts
  @State private var isPresentingCopyingSheet = false
  private let liveTextSupported = ImageAnalyzer.isSupported
  private let range = 0.0...4.0

  var body: some View {
    LabeledContent("Appearance:") {
      Picker("Theme:", selection: $colorScheme) {
        Text("System")
          .tag(ColorScheme.system)

        Divider()

        Text("Light")
          .tag(ColorScheme.light)

        Text("Dark")
          .tag(ColorScheme.dark)
      }
      .labelsHidden()
      .frame(width: 160) // 128 - 192
      .onChange(of: colorScheme) {
        NSApp.appearance = colorScheme.appearance
      }
    }

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

    LabeledContent("Live Text:") {
      GroupBox {
        Toggle("Enable Live Text", isOn: $liveText)

        Toggle("Show icon", isOn: $liveTextIcon)
          .disabled(!liveText)
      }
      .disabled(!liveTextSupported)
      .help(liveTextSupported ? "" : "This device does not support Live Text.")
    }

    LabeledContent("Main Canvas:") {
      GroupBox {
        HStack {
          Toggle("Toolbar", isOn: $hideToolbar)

          Toggle("Cursor", isOn: $hideCursor)

          Toggle("Scroll bar", isOn: $hideScroll)
        }
      } label: {
        Toggle(sources: [$hideToolbar, $hideCursor, $hideScroll], isOn: \.self) {
          Text("Hide when scrolling:")

          Text("Only relevant when the sidebar is not open.")
        }
      }.groupBoxStyle(.settingsLabeled)

      Toggle("Display current image in the title", isOn: $displayTitleBarImage)
    }

    LabeledContent("Copying:") {
      // TODO: Add a setting to not flip the direction.
      Toggle(isOn: $resolveConflicts) {
        Text("Resolve conflicts")

        Text("If a file already exists at the destination of a folder, the name of the image's enclosing folder will be appended to the destination.")
      }

      Button("Show Folders...") {
        isPresentingCopyingSheet.toggle()
      }.sheet(isPresented: $isPresentingCopyingSheet) {
        SettingsCopyingView()
          .frame(minWidth: 512, minHeight: 256)
      }
    }
  }
}
