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
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection

  var body: some View {
    Form {
      LabeledContent("Settings.Extra.FoldersPathSeparator") {
        Picker("Settings.Extra.FoldersPathSeparator", selection: $foldersPathSeparator) {
          let separators: [StorageFoldersPathSeparator] = [
            .singlePointingAngleQuotationMark,
            .blackPointingSmallTriangle,
            .blackPointingTriangle,
            .inequalitySign,
          ]

          ForEach(separators, id: \.self) { separator in
            Text(pathComponent(of: separator, in: foldersPathDirection))
              .tag(separator, includeOptional: false)
          }
        }
        .disabled(!resolveConflicts)
        .pickerStyle(.inline)
        .labelsHidden()
        .horizontalRadioGroupLayout()
      }

      LabeledContent("Settings.Extra.FoldersPathDirection") {
        Picker("Settings.Extra.FoldersPathDirection.Use", selection: $foldersPathDirection) {
          Text("Settings.Extra.FoldersPathDirection.Use.Leading")
            .tag(StorageFoldersPathDirection.leading, includeOptional: false)

          Text("Settings.Extra.FoldersPathDirection.Use.Trailing")
            .tag(StorageFoldersPathDirection.trailing, includeOptional: false)
        }
        .disabled(!resolveConflicts)
        .pickerStyle(.inline)
        .labelsHidden()
        .horizontalRadioGroupLayout()
      }

      Divider()

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        // TODO: Don't compute this in view body.
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

//        let component = component(
//          url: wallpaper.url,
//          separator: copyingConflictSeparator.separator,
//          direction: copyingConflictDirection,
//          format: copyingConflictFormat
//        )
//
//        Text("Settings.Extra.FoldersExample")
//          .fontWeight(.regular)
//          .foregroundStyle(.secondary)
//
//        Button {
//          // I've no idea why this silently fails on URLs composed with relatives.
//          NSWorkspace.shared.activateFileViewerSelecting([wallpaper.url])
//        } label: {
//          Text(component)
//            .truncationMode(.middle)
//            .help(component)
//        }
//        .buttonStyle(.plain)
//        .disabled(!wallpaper.isReachable)
      }
      .font(.subheadline)
      .padding(.horizontal)
      .padding(.vertical, 2)

      Divider()
    }
    .formStyle(.settings(width: SettingsView2.contentWidth))
  }

  private func pathComponent(
    of separator: StorageFoldersPathSeparator,
    in direction: StorageFoldersPathDirection,
  ) -> LocalizedStringKey {
    switch (separator, direction) {
      case (.inequalitySign, .leading):
        "Settings.Extra.FoldersSeparator.Use.InequalitySign.LeftToRight"
      case (.inequalitySign, .trailing):
        "Settings.Extra.FoldersSeparator.Use.InequalitySign.RightToLeft"
      case (.singlePointingAngleQuotationMark, .leading):
        "Settings.Extra.FoldersSeparator.Use.SinglePointingAngleQuotationMark.LeftToRight"
      case (.singlePointingAngleQuotationMark, .trailing):
        "Settings.Extra.FoldersSeparator.Use.SinglePointingAngleQuotationMark.RightToLeft"
      case (.blackPointingTriangle, .leading):
        "Settings.Extra.FoldersSeparator.Use.BlackPointingTriangle.LeftToRight"
      case (.blackPointingTriangle, .trailing):
        "Settings.Extra.FoldersSeparator.Use.BlackPointingTriangle.RightToLeft"
      case (.blackPointingSmallTriangle, .leading):
        "Settings.Extra.FoldersSeparator.Use.BlackPointingSmallTriangle.LeftToRight"
      case (.blackPointingSmallTriangle, .trailing):
        "Settings.Extra.FoldersSeparator.Use.BlackPointingSmallTriangle.RightToLeft"
    }
  }

  private func defaultWallpaperFile(base: URL) -> URL {
    // A fun Easter egg embedded in the bundle resources.
    //
    // The colons are MODIFIER LETTER COLON and not COLON to allow use in filenames.
    base
      .appending(components: "Data", "Wallpapers", "From the New World - e01 [00꞉11꞉28.313]", directoryHint: .notDirectory)
      .appendingPathExtension(for: .jxl)
  }

//  private func component(
//    url: URL,
//    separator: StorageFoldersSeparatorItem,
//    direction: StorageDirection,
//    format: String
//  ) -> String {
//    let formatted = FoldersSettingsModel.formatPathComponents(components: url.pathComponents)
//    let pathComponents = formatted
//      .dropFirst() // "/"
//      .dropLast() // The path we initially tried (e.g. "image.png")
//      .suffix(2)
//
//    let separator = separator.separator(direction: direction)
//    let name = url.lastPath
//    let path = FoldersSettingsModel.formatPath(components: pathComponents, separator: " \(separator) ", direction: direction)
//    let component = FoldersSettingsModel.format(string: format, name: name, path: path)
//
//    return component
//  }
}
