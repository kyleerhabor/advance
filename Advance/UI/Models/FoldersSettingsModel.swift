//
//  FoldersSettingsModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import AdvanceCore
import AdvanceData
import Algorithms
import AppKit
import Dependencies
import Foundation
import GRDB
import IdentifiedCollections
import Observation
import OSLog

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
  @ObservationIgnored @Dependency(\.dataStack) private var dataStack

  var items: IdentifiedArrayOf<FoldersSettingsItem>
  var resolved: [FoldersSettingsItem]

  init() {
    self.items = []
    self.resolved = []
  }

  nonisolated func _add(url: URL) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      try await connection.write { db in
        
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  func add(url: URL) async {
    await _add(url: url)
  }

  private static func submit(_ dataStack: DataStackDependencyKey.DataStack, urls: [URL]) async throws {
    let urbs = try await withThrowingTaskGroup(of: URLBookmark.self) { group in
      urls.forEach { url in
        group.addTask {
          try url.accessingSecurityScopedResource {
            try URLBookmark(url: url, options: [.withSecurityScope, .withoutImplicitSecurityScope], relativeTo: nil)
          }
        }
      }

      return try await group.reduce(into: [URLBookmark](reservingCapacity: urls.count)) { partialResult, urb in
        partialResult.append(urb)
      }
    }

    let urls = try await dataStack.connection.write { db in
      try urbs.reduce(into: [Data: URL](minimumCapacity: urbs.count)) { partialResult, urb in
        let bookmark = try DataStackDependencyKey.DataStack.submitBookmark(
          db,
          data: urb.bookmark.data,
          options: urb.bookmark.options,
          // TODO: Don't do this in the writer.
          hash: hash(data: urb.bookmark.data),
        )

        let fileBookmark = try DataStackDependencyKey.DataStack.submitFileBookmark(
          db,
          bookmark: bookmark.rowID!,
          relative: nil,
        )

        do {
          _ = try DataStackDependencyKey.DataStack.createFolder(db, fileBookmark: fileBookmark.rowID!)
        } catch let error as DatabaseError where error.extendedResultCode == .SQLITE_CONSTRAINT_UNIQUE {
          // The folder's file bookmark is likely associated with some other folder.
          return
        }

        partialResult[bookmark.hash!] = urb.url
      }
    }

    await dataStack.isolated { dataStack in
      dataStack.urls.merge(urls) { $1 }
    }
  }

  private static func submitItemsRemoval(_ dataStack: DataStackDependencyKey.DataStack, folders: [RowID]) async throws {
    try await dataStack.connection.write { db in
      try DataStackDependencyKey.DataStack.deleteFolders(db, folders: folders)
    }
  }

  static func resolve(
    _ dataStack: DataStackDependencyKey.DataStack,
    responses: [FoldersSettingsModelTrackFoldersFolderInfo]
  ) async throws -> [URL: FoldersSettingsItemData] {
    struct States {
      var results: [URL: FoldersSettingsItemData]
      var unresolved: [FoldersSettingsModelTrackFoldersFolderInfo]
      var unresolvedBookmarks: [RowID]
    }

    let urls = await dataStack.urls
    let states = responses.reduce(into: States(
      results: Dictionary(minimumCapacity: responses.count),
      unresolved: Array(reservingCapacity: responses.count),
      unresolvedBookmarks: Array(reservingCapacity: responses.count)
    )) { partialResult, response in
      let bookmark = response.fileBookmark.bookmark.bookmark

      guard let url = urls[bookmark.hash!] else {
        partialResult.unresolved.append(response)
        partialResult.unresolvedBookmarks.append(bookmark.rowID!)

        return
      }

      partialResult.results[url] = FoldersSettingsItemData(
        info: response.folder,
        source: URLSource(url: url, options: bookmark.options!),
        isResolved: true
      )
    }

    let bookmarks = try await dataStack.connection.read { db in
      try DataStackDependencyKey.DataStack.fetchBookmarks(db, bookmarks: states.unresolvedBookmarks)
    }

    struct Resolved {
      var items: [(FoldersSettingsModelTrackFoldersFolderInfo, DataBookmark, Bool)]
      var urls: [Data: URL]
    }

    let unresolved = states.unresolved
    let resolved = await withTaskGroup(of: (FoldersSettingsModelTrackFoldersFolderInfo, DataBookmark, Bool).self) { group in
      unresolved.forEach { response in
        guard let bookmark = bookmarks[response.fileBookmark.bookmark.bookmark.rowID!] else {
          return
        }

        group.addTask {
          let data = bookmark.data!
          let options = bookmark.options!
          let hash = bookmark.hash!
          let dataBookmark: DataBookmark
          let isResolved: Bool

          do {
            dataBookmark = try DataBookmark(
              data: data,
              options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
              hash: hash,
              relativeTo: nil
            ) { url in
              let source = URLSource(url: url, options: options)
              let bookmark = try source.accessingSecurityScopedResource {
                try url.bookmarkData(options: options, relativeTo: nil)
              }

              return bookmark
            }

            isResolved = true
          } catch {
            if ((error as? CocoaError)?.code == .fileNoSuchFile) != true {
              Logger.model.error("\(error)")
            }

            dataBookmark = DataBookmark(
              bookmark: AssignedBookmark(url: .homeDirectory /*response.folder.url!*/, data: data),
              hash: hash
            )

            isResolved = false
          }

          return (response, dataBookmark, isResolved)
        }
      }

      return await group.reduce(into: Resolved(
        items: [(FoldersSettingsModelTrackFoldersFolderInfo, DataBookmark, Bool)](reservingCapacity: unresolved.count),
        urls: [Data: URL](minimumCapacity: unresolved.count)
      )) { partialResult, item in
        let data = item.1
        let isResolved = item.2
        let url = data.bookmark.url

        if isResolved {
          partialResult.urls[data.hash] = url
        }

        partialResult.items.append(item)
      }
    }

    await dataStack.isolated { dataStack in
      dataStack.urls.merge(resolved.urls) { $1 }
    }

    let created = try await dataStack.connection.write { db in
      let items = resolved.items

      return items.reduce(into: [URL: FoldersSettingsItemData](minimumCapacity: items.count)) { partialResult, item in
        let response = item.0
        let data = item.1
        let isResolved = item.2
        let options = response.fileBookmark.bookmark.bookmark.options!

        if isResolved {
          let bookmark: BookmarkRecord

          do {
            bookmark = try DataStackDependencyKey.DataStack.submitBookmark(
              db,
              data: data.bookmark.data,
              options: options,
              hash: data.hash,
            )
          } catch {
            Logger.model.error("\(error)")

            return
          }

          do {
            _ = try DataStackDependencyKey.DataStack.submitFileBookmark(db, bookmark: bookmark.rowID!, relative: nil)
          } catch {
            Logger.model.error("\(error)")

            return
          }
        }

        partialResult[data.bookmark.url] = FoldersSettingsItemData(
          info: response.folder,
          source: URLSource(url: data.bookmark.url, options: options),
          isResolved: isResolved
        )
      }
    }

    return states.results.merging(created) { $1 }
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

  @MainActor
  func load(_ dataStack: DataStackDependencyKey.DataStack, responses: [FoldersSettingsModelTrackFoldersFolderInfo]) async {
    let results: [URL: FoldersSettingsItemData]

    do {
      results = try await Self.resolve(dataStack, responses: responses)
    } catch {
      Logger.model.error("\(error)")

      return
    }

    struct Result {
      var items: [FoldersSettingsItem]
      var resolved: [FoldersSettingsItem]
    }

    // TODO: Reference symbol by name instead of codepoint.
    //
    // I tried using an NSTextAttachment + NSAttributedString combo, but it wouldn't render in SwiftUI's Text.
    var separator = AttributedString("􀰇")
    separator.foregroundColor = .tertiaryLabelColor

    let space = AttributedString(" ") // Yes, this is just a space character.
    var divider = AttributedString()
    divider.append(space)
    divider.append(separator)
    divider.append(space)

    let urls = results.keys
    let formatted = urls.reduce(into: [[String]: URL](minimumCapacity: urls.count)) { partialResult, url in
      let components = Self.formatPathComponents(components: url.pathComponents)

      partialResult[components] = url
    }

    let components = formatted.keys.sorted { a, b in
      guard let distinct = zip(a, b).first(where: !=) else {
        return a.count < b.count
      }

      return distinct.0.localizedStandardCompare(distinct.1) == .orderedAscending
    }

    let reduced = components.reduce(into: Result(
      items: [FoldersSettingsItem](reservingCapacity: results.count),
      resolved: [FoldersSettingsItem](reservingCapacity: results.count)
    )) { partialResult, components in
      guard let url = formatted[components],
            let data = results[url] else {
        return
      }

      let attributed = components.dropFirst()
        .map { AttributedString($0) }
        .interspersed(with: divider)
        .reduce(AttributedString(), +)

      let item = FoldersSettingsItem(
        data: data,
        icon: NSWorkspace.shared.icon(forFileAt: url),
        string: attributed
      )

      if data.isResolved {
        partialResult.resolved.append(item)
      }

      partialResult.items.append(item)
    }

    self.items = IdentifiedArray(uniqueElements: reduced.items)
    self.resolved = reduced.resolved
  }

  func load() async throws {
    let dataStack = try await dataStack()

    for try await responses in dataStack.trackFolders() {
      await load(dataStack, responses: responses)
    }
  }

  func submit(urls: [URL]) async throws {
    try await Self.submit(try await dataStack(), urls: urls)
  }

  func submit(removalOf items: some Sequence<FoldersSettingsItem>) async throws {
    // TODO: Don't map on the main actor.
    try await Self.submitItemsRemoval(try await dataStack(), folders: items.map(\.data.info.rowID!))
  }
}
