//
//  SettingsGeneralView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 10/12/23.
//

import SwiftUI

struct SettingsGeneralView: View {
  typealias Scheme = ColorScheme?

  @Environment(CopyDepot.self) private var copyDepot
  @AppStorage(Keys.appearance.key) private var appearance: Scheme
  @AppStorage(Keys.margin.key) private var margin = Keys.margin.value
  @AppStorage(Keys.collapseMargins.key) private var collapseMargins = Keys.collapseMargins.value
  @AppStorage(Keys.windowless.key) private var windowless = Keys.windowless.value
  @AppStorage(Keys.displayTitleBarImage.key) private var displayTitleBarImage = Keys.displayTitleBarImage.value
  @AppStorage(Keys.liveText.key) private var liveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcon.key) private var liveTextIcons = Keys.liveTextIcon.value
  @AppStorage(Keys.trackCurrentImage.key) private var trackCurrentImage = Keys.trackCurrentImage.value
  @AppStorage(Keys.resolveCopyDestinationConflicts.key) private var resolveConflicts = Keys.resolveCopyDestinationConflicts.value
  @State private var showingDestinations = false
  private let range = 0.0...4.0

  var body: some View {
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
      GroupBox {
        Toggle("Enable Live Text", isOn: $liveText)

        Toggle("Show icons", isOn: $liveTextIcons)
          .disabled(!liveText)
      }
    }

    LabeledContent("Main Canvas:") {
      Toggle(isOn: $trackCurrentImage) {
        Text("Track the current image")

        // TODO: Figure out how to make the chevron smaller.
        Text("This enables functionality like dynamically modifying the title and showing the current image via **Image 􀯻 Show in Sidebar**, but may degrade performance.")
      }

      GroupBox {
        Toggle(isOn: $windowless) {
          Text("Hide the toolbar when scrolling")

          Text("Only relevant when the sidebar is not open.")
        }

        Toggle("Display the current image in the title", isOn: $displayTitleBarImage)
      }.disabled(!trackCurrentImage)
    }

    LabeledContent("Copying:") {
      // TODO: Add a setting to not flip the direction for multiple resolutions.
      Toggle(isOn: $resolveConflicts) {
        Text("Resolve conflicts")

        Text("If a file already exists at the destination of a folder, the name of the image's enclosing folder will be appended to the destination.")
      }

      Button("Show Folders...") {
        showingDestinations = true
      }.sheet(isPresented: $showingDestinations) {
        // We want the destinations to be sorted off-screen to not disrupt the user. The action is in a Task so it's
        // not visible to the user while the sheet is dismissing.
        Task {
          copyDepot.bookmarks.sort { $0.url < $1.url }
          copyDepot.update()
        }
      } content: {
        SettingsDestinationsView()
          .frame(minWidth: 512, minHeight: 160)
      }
    }
  }
}

#Preview {
  SettingsGeneralView()
}
