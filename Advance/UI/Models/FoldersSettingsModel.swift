//
//  FoldersSettingsModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import AdvanceCore
import AdvanceData
import AppKit
import Observation

struct FoldersSettingsItemData {
  let info: FolderRecord
  let source: URLSource
  let isResolved: Bool
}

struct FoldersSettingsItem {
  let data: FoldersSettingsItemData
  let icon: NSImage
  let string: AttributedString
}

extension FoldersSettingsItem: Identifiable {
  var id: RowID {
    data.info.rowID!
  }
}

@Observable
@MainActor
class FoldersSettingsModel {
  nonisolated static let keywordEnclosing: Character = "%"
  nonisolated static let nameKeyword = TokenFieldView.enclose("name", with: keywordEnclosing)
  nonisolated static let pathKeyword = TokenFieldView.enclose("path", with: keywordEnclosing)
  var resolved: [FoldersSettingsItem]

  init() {
    self.resolved = []
  }

  static func formatPathComponents(components: [String]) -> [String] {
    let matchers: [Matcher] = [
      .appSandbox(bundleID: Bundle.appID),
      .userTrash,
      .user(named: NSUserName()),
      .volumeTrash
    ]

    let formatted = matchers.reduce(components) { partialResult, matcher in
      matcher.match(on: partialResult)
    }

    return formatted
  }

  // This method primarily exists to assist in not relying on dynamic dispatching (i.e. the any keyword).
  //
  // The fact separator may be influenced by direction is coincidental.
  nonisolated static func formatPath(components: some Sequence<String>, separator: String, direction: StorageDirection) -> String {
    // For Data -> Wallpapers -> From the New World - e01 [00꞉11꞉28.313],
    //
    // Left to right: Data -> Wallpapers -> From the New World - e01 [00꞉11꞉28.313]
    // Right to left: From the New World - e01 [00꞉11꞉28.313] <- Wallpapers <- Data
    switch direction {
      // I'd prefer to use ListFormatStyle, but the grouping separator is not customizable.
      case .leftToRight: components.joined(separator: separator)
      case .rightToLeft: components.reversed().joined(separator: separator)
    }
  }

  nonisolated static func format(string: String, name: String, path: String) -> String {
    let tokens = TokenFieldView
      .parse(token: string, enclosing: keywordEnclosing)
      .map { token in
        switch token {
          case nameKeyword: name
          case pathKeyword: path
          default: token
        }
      }

    return TokenFieldView.string(tokens: tokens)
  }
}
