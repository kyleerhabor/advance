//
//  CopyingSettingsMenuView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/14/24.
//

import AdvanceCore
import OSLog
import SwiftUI

struct CopyingSettingsMenuView: View {
  @Environment(FoldersSettingsModel.self) private var copying

  let action: (URLSource) -> Void
  let primaryAction: () -> Void

  var body: some View {
    Menu("Settings.Accessory.Copying.Menu.Title") {
      ForEach(copying.resolved) { item in
        Button {
          action(item.data.source)
        } label: {
          Text(item.string)
        }
        .transform { content in
          if #unavailable(macOS 15) {
            content
          } else {
            content
              .modifierKeyAlternate(.option) {
                Button {
                  let source = item.data.source
                  let path = source.url.pathString
                  let didOpen = source.accessingSecurityScopedResource {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                  }

                  if !didOpen {
                    Logger.ui.log("Could not open file at URL \"\(path)\" in Finder")
                  }
                } label: {
                  Text("Finder.Item.\(item.string).Open")
                }
              }
          }
        }
      }
    } primaryAction: {
      primaryAction()
    }
  }

  nonisolated static func format(components: [String]) -> [String] {
    let matchers: [Matcher] = [
      .appSandbox(bundleID: Bundle.appID),
      .userTrash,
      .user(named: NSUserName()),
      .volumeTrash,
      .volume
    ]
    
    let formatted = matchers.reduce(components) { partialResult, matcher in
      matcher.match(on: partialResult)
    }

    return formatted
  }

  nonisolated static func copy(
    _ copier: ImagesItemModelSourceCopier,
    url: URL,
    to source: URLSource,
    resolveConflicts: Bool,
    format: String,
    separator: Character,
    direction: StorageDirection
  ) throws {
    let destination = source.url.appending(path: url.lastPathComponent, directoryHint: .notDirectory)

    do {
      try copier.copy(destination)
    } catch let error as CocoaError where error.code == .fileWriteFileExists {
      guard resolveConflicts else {
        throw error
      }

      let pathComponents = Self.format(components: url.pathComponents)
      let components = pathComponents
        .dropFirst() // "/"
        .dropLast() // The path we initially tried (e.g. image.jpeg)
        .reversed()
        .reductions(into: []) { $0.append($1) }
        .dropFirst() // The initial reduction (an empty array)

      let name = url.lastPath
      let separator = " \(separator) "
      let satisfied = try components.contains { components in
        // The reduction in an order compatible with formatPath(components:separator:direction:)
        let path = FoldersSettingsModel.formatPath(components: components.reversed(), separator: separator, direction: direction)
        let component = FoldersSettingsModel.format(string: format, name: name, path: path)
        let destination = source.url
          .appending(component: component)
          .appendingPathExtension(url.pathExtension)

        do {
          try copier.copy(destination)
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
          return false
        }

        return true
      }

      guard satisfied else {
        throw error
      }
    }
  }

  // MARK: - Convenience

  nonisolated static func copy(
    itemSource: some ImagesItemModelSource & Sendable,
    to source: URLSource,
    resolveConflicts: Bool,
    format: String,
    separator: Character,
    direction: StorageDirection
  ) async throws {
    guard let url = itemSource.url else {
      return
    }

    let copier = await itemSource.copier

    defer {
      copier.close()
    }

    try copy(
      copier,
      url: url,
      to: source,
      resolveConflicts: resolveConflicts,
      format: format,
      separator: separator,
      direction: direction
    )
  }
}
