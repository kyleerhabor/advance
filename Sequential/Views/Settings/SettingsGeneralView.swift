//
//  SettingsGeneralView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/12/23.
//

import Defaults
import SwiftUI

struct SettingsGeneralView: View {
  typealias Scheme = ColorScheme?

  @Environment(\.liveTextSupported) private var liveTextSupported
  @AppStorage(Keys.margin.key) private var margin = Keys.margin.value
  @AppStorage(Keys.collapseMargins.key) private var collapseMargins = Keys.collapseMargins.value
  @AppStorage(Keys.displayTitleBarImage.key) private var displayTitleBarImage = Keys.displayTitleBarImage.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var liveTextIcons = Keys.liveTextIcon.value
  @Default(.colorScheme) private var colorScheme
  @Default(.hideToolbarScrolling) private var hideToolbar
  @Default(.hideCursorScrolling) private var hideCursor
  @Default(.hideScrollIndicator) private var hideScroll
  @Default(.resolveCopyingConflicts) private var resolveConflicts
  @State private var isPresentingCopyingSheet = false
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
      GroupBox {
        Toggle("Enable Live Text", isOn: $liveText)

        Toggle("Show icon", isOn: $liveTextIcons)
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

      Toggle("Display the current image in the title", isOn: $displayTitleBarImage)
    }

    LabeledContent("Copying:") {
      // TODO: Add a setting to not flip the direction for multiple resolutions.
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
