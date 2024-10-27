//
//  UI+SettingsExtraView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/21/24.
//

import AdvanceCore
import SwiftUI

struct SettingsExtraWallpaper {
  let url: URL
  let isReachable: Bool
}

struct SettingsExtraView2: View {
  @Environment(Windowed.self) private var windowed
  @Environment(\.localize) private var localize
  @AppStorage(StorageKeys.copyingConflictFormat) private var copyingConflictFormat
  @AppStorage(StorageKeys.copyingConflictSeparator) private var copyingConflictSeparator
  @AppStorage(StorageKeys.copyingConflictDirection) private var copyingConflictDirection
  private var copyingConflictFormatTokens: Binding<[String]> {
    Binding {
      TokenFieldView.parse(token: copyingConflictFormat, enclosing: CopyingSettingsModel.keywordEnclosing)
    } set: { tokens in
      copyingConflictFormat = TokenFieldView.string(tokens: tokens)
    }
  }
  
  var body: some View {
    Form {
      LabeledContent("Settings.Extra.CopyingDestination") {
        VStack(alignment: .leading) {
          HStack(alignment: .firstTextBaseline) {
            TokenFieldView(
              prompt: nil,
              isBezeled: true,
              tokens: copyingConflictFormatTokens,
              enclosing: CopyingSettingsModel.keywordEnclosing
            ) { token in
              token == CopyingSettingsModel.nameKeyword || token == CopyingSettingsModel.pathKeyword
            } title: { token in
              title(for: token)
            }
            .frame(width: SettingsView2.textFieldWidth, alignment: .leading)
            .truncationMode(.middle)

            Menu("Substitute", systemImage: "plus") {
              Button("Name") {
                copyingConflictFormat.append(CopyingSettingsModel.nameKeyword)
              }

              Button("Path") {
                copyingConflictFormat.append(CopyingSettingsModel.pathKeyword)
              }
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .fontWeight(.medium)

            Spacer()
          }

          Text("Settings.Extra.CopyingDestination.Note")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      LabeledContent("Settings.Extra.CopyingSeparator") {
        Picker("Settings.Extra.CopyingSeparator.Separator", selection: $copyingConflictSeparator) {
          let separators: [StorageCopyingSeparator] = [
            .singlePointingAngleQuotationMark,
            .blackPointingSmallTriangle,
            .blackPointingTriangle,
            .inequalitySign
          ]

          ForEach(separators, id: \.self) { separator in
            let node = separator.separator.separator(direction: copyingConflictDirection)

            Text("Settings.Extra.CopyingSeparator.Separator.Item.\(String(node))")
              .tag(separator, includeOptional: false)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
        .horizontalRadioGroupLayout()
      }

      LabeledContent("Settings.Extra.CopyingDirection") {
        Picker("Settings.Extra.CopyingDirection.Direction", selection: $copyingConflictDirection) {
          Text("Settings.Extra.CopyingDirection.Direction.Leading")
            .tag(StorageDirection.leftToRight, includeOptional: false)

          Text("Settings.Extra.CopyingDirection.Direction.Trailing")
            .tag(StorageDirection.rightToLeft, includeOptional: false)
        }
        .pickerStyle(.inline)
        .labelsHidden()
        .horizontalRadioGroupLayout()
      }

      Divider()

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        let wallpaper = windowed.window?.screen.flatMap { screen in
          // As of macOS Sonoma 14.6.1, this does not prompt. Hopefully, it remains that way.
          //
          // TODO: Update on change to the wallpaper.
          //
          // There isn't a public API for being notified on changes to the desktop image; but there may be a private one
          // that is accessible.
          NSWorkspace.shared.desktopImageURL(for: screen).map { url in
            SettingsExtraWallpaper(url: url, isReachable: true)
          }
        }
        ?? Bundle.main.resourceURL.map { url in
          SettingsExtraWallpaper(url: defaultWallpaperFile(base: url.absoluteURL), isReachable: true)
        }
        ?? SettingsExtraWallpaper(url: defaultWallpaperFile(base: .userDirectory), isReachable: false)

        let component = component(
          url: wallpaper.url,
          separator: copyingConflictSeparator.separator,
          direction: copyingConflictDirection,
          format: copyingConflictFormat
        )

        Text("Settings.Extra.CopyingExample")
          .fontWeight(.regular)
          .foregroundStyle(.secondary)

        Button {
          // I've no idea why this silently fails on URLs composed with relatives.
          NSWorkspace.shared.activateFileViewerSelecting([wallpaper.url])
        } label: {
          Text(component)
            .truncationMode(.middle)
            .help(component)
        }
        .buttonStyle(.plain)
        .disabled(!wallpaper.isReachable)
      }
      .font(.subheadline)
      .padding(.horizontal)
      .padding(.vertical, 2)

      Divider()
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }

  private func defaultWallpaperFile(base: URL) -> URL {
    // A fun Easter egg embedded in the bundle resources.
    base
      .appending(components: "Data", "Wallpapers", "From the New World - e01 [00꞉11꞉28.313]", directoryHint: .notDirectory)
      .appendingPathExtension(for: .jxl)
  }

  private func title(for token: String) -> String {
    switch token {
      case CopyingSettingsModel.nameKeyword: localize("Settings.Extra.CopyingDestination.Token.Name")
      case CopyingSettingsModel.pathKeyword: localize("Settings.Extra.CopyingDestination.Token.Path")
      default: fatalError()
    }
  }

  private func component(
    url: URL,
    separator: StorageCopyingSeparatorItem,
    direction: StorageDirection,
    format: String
  ) -> String {
    let formatted = CopyingSettingsModel.formatPathComponents(components: url.pathComponents)
    let pathComponents = formatted
      .dropFirst() // "/"
      .dropLast() // The path we initially tried (e.g. "image.png")
      .suffix(2)

    let separator = separator.separator(direction: direction)
    let name = url.lastPath
    let path = CopyingSettingsModel.formatPath(components: pathComponents, separator: " \(separator) ", direction: direction)
    let component = CopyingSettingsModel.format(string: format, name: name, path: path)

    return component
  }
}
