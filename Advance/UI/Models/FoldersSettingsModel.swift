//
//  FoldersSettingsModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/26/25.
//

import AdvanceCore
import AdvanceData
import Algorithms
import AppKit
import Foundation
import GRDB
import IdentifiedCollections
import Observation
import OSLog

struct FoldersSettingsModelLoadFolderFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension FoldersSettingsModelLoadFolderFileBookmarkBookmarkInfo: Decodable, Equatable, FetchableRecord {}

struct FoldersSettingsModelLoadFolderFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: FoldersSettingsModelLoadFolderFileBookmarkBookmarkInfo
}

extension FoldersSettingsModelLoadFolderFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark"
  }
}

extension FoldersSettingsModelLoadFolderFileBookmarkInfo: Equatable, FetchableRecord {}

struct FoldersSettingsModelLoadFolderPathComponentInfo {
  let pathComponent: FolderPathComponentRecord
}

extension FoldersSettingsModelLoadFolderPathComponentInfo: Decodable, Equatable, FetchableRecord {}

struct FoldersSettingsModelLoadFolderInfo {
  let folder: FolderRecord
  let fileBookmark: FoldersSettingsModelLoadFolderFileBookmarkInfo
  let pathComponents: [FoldersSettingsModelLoadFolderPathComponentInfo]
}

extension FoldersSettingsModelLoadFolderInfo: Decodable {
  enum CodingKeys: CodingKey {
    case folder, fileBookmark, pathComponents
  }
}

extension FoldersSettingsModelLoadFolderInfo: Equatable, FetchableRecord {}

@Observable
@MainActor
final class FoldersSettingsItemModel {
  let id: RowID
  var isResolved: Bool
  var icon: NSImage
  var path: AttributedString
  var helpPath: AttributedString

  init(
    id: RowID,
    isResolved: Bool,
    icon: NSImage,
    path: AttributedString,
    helpPath: AttributedString,
  ) {
    self.id = id
    self.isResolved = isResolved
    self.icon = icon
    self.path = path
    self.helpPath = helpPath
  }
}

extension FoldersSettingsItemModel: Identifiable {}

struct FoldersSettingsModelStoreItem {
  let bookmark: Bookmark
  let pathComponents: [String]
}

struct FoldersSettingsModelLoadState1Item {
  let folder: FoldersSettingsModelLoadFolderInfo
  let bookmark: AssignedBookmark?
}

struct FoldersSettingsModelLoadState2Item {
  let id: RowID
  let isResolved: Bool
  let icon: NSImage
  let pathComponents: [String]
}

struct FoldersSettingsModelLoadState3Item {
  let id: RowID
  let isResolved: Bool
  let icon: NSImage
  let path: AttributedString
  let helpPath: AttributedString
}

struct FoldersSettingsModelShowFinderState1 {
  let folders: [RowID: FoldersSettingsModelShowFinderFolderInfo]
}

struct FoldersSettingsModelShowFinderState2 {
  var bookmarks: [RowID: AssignedBookmark]
}

struct FoldersSettingsModelOpenFinderState1 {
  let folders: [RowID: FoldersSettingsModelOpenFinderFolderInfo]
}

struct FoldersSettingsModelOpenFinderState2 {
  var bookmarks: [RowID: AssignedBookmark]
}

@Observable
@MainActor
final class FoldersSettingsModel {
  var items: IdentifiedArrayOf<FoldersSettingsItemModel>
  var resolved: IdentifiedArrayOf<FoldersSettingsItemModel>

  init() {
    self.items = []
    self.resolved = []
  }

  func load(locale: Locale) async {
    await _load(locale: locale)
  }

  func store(urls: [URL]) async {
    await _store(urls: urls)
  }

  func store(items: [FoldersSettingsItemTransfer]) async {
    await _store(items: items)
  }

  func remove(items: IndexSet) async {
    // I feel like there's a way to use set algebra on the ID indicies to retrieve the IDs without looping, but I can't
    // be asked to test that hypothesis.
    await _remove(items: items.map { self.items[$0].id })
  }

  func remove(items: Set<FoldersSettingsItemModel.ID>) async {
    await _remove(items: items)
  }

  func isInvalidSelection(of ids: Set<FoldersSettingsItemModel.ID>) -> Bool {
    ids.isEmpty
  }

  func showFinder(items: Set<FoldersSettingsItemModel.ID>) async {
    await _showFinder(items: items)
  }

  func openFinder(item: FoldersSettingsItemModel) async {
    await _openFinder(item: item.id)
  }

  func openFinder(items: Set<FoldersSettingsItemModel.ID>) async {
    await _openFinder(items: items)
  }

  nonisolated private func separator(from separator: AttributedString) -> AttributedString {
    var separator = separator
    separator.foregroundColor = .tertiaryLabelColor

    return separator
  }

  nonisolated private func path(components: [AttributedString], separator: AttributedString) -> AttributedString {
    components
      .interspersed(with: separator)
      .reduce(AttributedString(), +)
  }

  nonisolated private func load(
    connection: DatabasePool,
    folders: [FoldersSettingsModelLoadFolderInfo],
    locale: Locale,
  ) async {
    let items = folders.map { folder in
      let bookmark: AssignedBookmark?

      do {
        bookmark = try AssignedBookmark(
          data: folder.fileBookmark.bookmark.bookmark.data!,
          options: folder.fileBookmark.bookmark.bookmark.options!,
          relativeTo: nil,
        )
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        bookmark = nil
      }

      return FoldersSettingsModelLoadState1Item(folder: folder, bookmark: bookmark)
    }

    guard items.compactMap(\.bookmark).allSatisfy(\.resolved.isStale.inverted) else {
      do {
        try await connection.write { db in
          try items.forEach { item in
            guard let bookmark = item.bookmark else {
              return
            }

            var bookmark2 = BookmarkRecord(
              rowID: item.folder.fileBookmark.bookmark.bookmark.rowID,
              data: bookmark.data,
              options: item.folder.fileBookmark.bookmark.bookmark.options,
            )

            try bookmark2.upsert(db)
          }
        }
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }

      return
    }

    let separator = self.separator(from: AttributedString(
      localized: "Settings.Accessory.Folders.Item.Path.Separator",
      locale: locale,
    ))

    let helpSeparator = self.separator(from: AttributedString(
      localized: "Settings.Accessory.Folders.Item.Path.Help.Separator",
      locale: locale,
    ))

    let items2 = items
      .map { item in
        let defaultPathComponents = item.folder.pathComponents.map(\.pathComponent.component!)

        guard let bookmark = item.bookmark else {
          return FoldersSettingsModelLoadState2Item(
            id: item.folder.folder.rowID!,
            isResolved: false,
            icon: NSImage(),
            pathComponents: defaultPathComponents,
          )
        }

        let source = URLSource(
          url: bookmark.resolved.url,
          options: item.folder.fileBookmark.bookmark.bookmark.options!,
        )

        let item = source.accessingSecurityScopedResource {
          FoldersSettingsModelLoadState2Item(
            id: item.folder.folder.rowID!,
            isResolved: true,
            icon: NSWorkspace.shared.icon(forFileAt: bookmark.resolved.url),
            pathComponents: FileManager.default.componentsToDisplay(forPath: bookmark.resolved.url.pathString)
              ?? defaultPathComponents,
          )
        }

        return item
      }
      .finderSort(by: \.pathComponents)
      .map { item in
        let pathComponents = item.pathComponents.map { AttributedString($0) }
        let path = self.path(components: pathComponents, separator: separator)
        let helpPath = self.path(components: pathComponents, separator: helpSeparator)

        return FoldersSettingsModelLoadState3Item(
          id: item.id,
          isResolved: item.isResolved,
          icon: item.icon,
          path: path,
          helpPath: helpPath,
        )
      }

    Task { @MainActor in
      self.items = IdentifiedArray(
        uniqueElements: items2.map { item in
          guard let model = self.items[id: item.id] else {
            let model = FoldersSettingsItemModel(
              id: item.id,
              isResolved: item.isResolved,
              icon: item.icon,
              path: item.path,
              helpPath: item.helpPath
            )

            return model
          }

          model.isResolved = item.isResolved
          model.icon = item.icon
          model.path = item.path
          model.helpPath = item.helpPath

          return model
        },
      )

      self.resolved = self.items.filter(\.isResolved)
    }
  }

  nonisolated private func _load(locale: Locale) async {
    let observation = ValueObservation
      .trackingConstantRegion { db in
        try FolderRecord
          .select(.rowID)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(FoldersSettingsModelLoadFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(FoldersSettingsModelLoadFolderFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .including(
            all: FolderRecord.pathComponents
              .forKey(FoldersSettingsModelLoadFolderInfo.CodingKeys.pathComponents)
              .select(.rowID, FolderPathComponentRecord.Columns.component)
              .order(FolderPathComponentRecord.Columns.position),
          )
          .asRequest(of: FoldersSettingsModelLoadFolderInfo.self)
          .fetchAll(db)
      }

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      for try await folders in observation.values(in: connection, bufferingPolicy: .bufferingNewest(1)) {
        await load(connection: connection, folders: folders, locale: locale)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func _store(urls: [URL]) async {
    let items = urls.compactMap { url -> FoldersSettingsModelStoreItem? in
      let source = URLSource(url: url, options: [.withSecurityScope, .withoutImplicitSecurityScope])
      let bookmark: Bookmark

      do {
        bookmark = try source.accessingSecurityScopedResource {
          try Bookmark(url: source.url, options: source.options, relativeTo: nil)
        }
      } catch {
        // TODO: Log.
        Logger.model.error("\(error)")

        return nil
      }

      guard let pathComponents = FileManager.default.componentsToDisplay(forPath: source.url.pathString) else {
        // TODO: Log.
        return nil
      }

      return FoldersSettingsModelStoreItem(bookmark: bookmark, pathComponents: pathComponents)
    }

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
        try items.forEach { item in
          var bookmark = BookmarkRecord(data: item.bookmark.data, options: item.bookmark.options)
          try bookmark.upsert(db)

          var fileBookmark = FileBookmarkRecord(bookmark: bookmark.rowID, relative: nil)
          try fileBookmark.upsert(db)

          var folder = FolderRecord(fileBookmark: fileBookmark.rowID)
          try folder.upsert(db)

          _ = try item.pathComponents.reduce(0) { position, pathComponent in
            var folderPathComponent = FolderPathComponentRecord(component: pathComponent, position: position)
            try folderPathComponent.insert(db)

            var pathComponentFolder = PathComponentFolderRecord(
              folder: folder.rowID,
              pathComponent: folderPathComponent.rowID,
            )

            try pathComponentFolder.insert(db)

            return position.incremented()
          }
        }
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func _store(items: [FoldersSettingsItemTransfer]) async {
    await _store(urls: items.map(\.fileURL))
  }

  nonisolated private func _remove(items: some Collection<FoldersSettingsItemModel.ID> & Sendable) async {
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
        _ = try FolderRecord.deleteAll(db, keys: items)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func _showFinder(items: Set<FoldersSettingsItemModel.ID>) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state1: FoldersSettingsModelShowFinderState1

    do {
      state1 = try await connection.read { db in
        let folders = try FolderRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(FoldersSettingsModelShowFinderFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(FoldersSettingsModelShowFinderFolderFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: FoldersSettingsModelShowFinderFolderInfo.self)
          .fetchCursor(db)

        let state = FoldersSettingsModelShowFinderState1(
          folders: try Dictionary(uniqueKeysWithValues: folders.map { ($0.folder.rowID!, $0) }),
        )

        return state
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state2 = items.reduce(
      into: FoldersSettingsModelShowFinderState2(bookmarks: Dictionary(minimumCapacity: state1.folders.count)),
    ) { state, item in
      let folder = state1.folders[item]!
      let bookmark: AssignedBookmark

      do {
        bookmark = try AssignedBookmark(
          data: folder.fileBookmark.bookmark.bookmark.data!,
          options: folder.fileBookmark.bookmark.bookmark.options!,
          relativeTo: nil,
        )
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }

      state.bookmarks[folder.fileBookmark.bookmark.bookmark.rowID!] = bookmark
    }

    do {
      try await connection.write { db in
        try items.forEach { item in
          let folder = state1.folders[item]!
          let item = folder.fileBookmark.bookmark.bookmark
          try write(db, bookmark: item, assigned: state2.bookmarks[item.rowID!])
        }
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let urls = items.compactMap { item in
      let item = state1.folders[item]!

      return state2.bookmarks[item.fileBookmark.bookmark.bookmark.rowID!]?.resolved.url
    }

    // As of macOS Sequoia 15.7.2 (24G325), this produces error logs relating to App Sandbox's security scoped resources,
    // but otherwise works. I'd rather not use security scopes for this because we'd need them all open to call this
    // method, which is bound to explode on us if the user has many folders.
    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }

  nonisolated private func openFinder(at source: URLSource) {
    let opened = source.accessingSecurityScopedResource {
      NSWorkspace.shared.open(source.url)
    }

    guard opened else {
      Logger.model.log("Could not open folder at file URL '\(source.url.pathString)'")

      return
    }
  }

  nonisolated private func _openFinder(item: FoldersSettingsItemModel.ID) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let folder: FoldersSettingsModelOpenFinderFolderInfo?

    do {
      folder = try await connection.read { db in
        try FolderRecord
          .select(.rowID)
          .filter(key: item)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(FoldersSettingsModelOpenFinderFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(FoldersSettingsModelOpenFinderFolderFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: FoldersSettingsModelOpenFinderFolderInfo.self)
          .fetchOne(db)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let folder else {
      return
    }

    let bookmark: AssignedBookmark?

    do {
      bookmark = try AssignedBookmark(
        data: folder.fileBookmark.bookmark.bookmark.data!,
        options: folder.fileBookmark.bookmark.bookmark.options!,
        relativeTo: nil,
      )
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      bookmark = nil
    }

    do {
      try await connection.write { db in
        try write(db, bookmark: folder.fileBookmark.bookmark.bookmark, assigned: bookmark)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let bookmark else {
      return
    }

    let source = URLSource(
      url: bookmark.resolved.url,
      options: folder.fileBookmark.bookmark.bookmark.options!,
    )

    openFinder(at: source)
  }

  nonisolated private func _openFinder(items: Set<FoldersSettingsItemModel.ID>) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state1: FoldersSettingsModelOpenFinderState1

    do {
      state1 = try await connection.read { db in
        let folders = try FolderRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(FoldersSettingsModelOpenFinderFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(FoldersSettingsModelOpenFinderFolderFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: FoldersSettingsModelOpenFinderFolderInfo.self)
          .fetchCursor(db)

        let state = FoldersSettingsModelOpenFinderState1(
          folders: try Dictionary(uniqueKeysWithValues: folders.map { ($0.folder.rowID!, $0) }),
        )

        return state
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state2 = items.reduce(
      into: FoldersSettingsModelOpenFinderState2(bookmarks: Dictionary(minimumCapacity: state1.folders.count)),
    ) { state, item in
      let folder = state1.folders[item]!
      let bookmark: AssignedBookmark

      do {
        bookmark = try AssignedBookmark(
          data: folder.fileBookmark.bookmark.bookmark.data!,
          options: folder.fileBookmark.bookmark.bookmark.options!,
          relativeTo: nil,
        )
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }

      state.bookmarks[folder.fileBookmark.bookmark.bookmark.rowID!] = bookmark
    }

    do {
      try await connection.write { db in
        try items.forEach { item in
          let folder = state1.folders[item]!
          let item = folder.fileBookmark.bookmark.bookmark
          try write(db, bookmark: item, assigned: state2.bookmarks[item.rowID!])
        }
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    items.forEach { item in
      let folder = state1.folders[item]!

      guard let bookmark = state2.bookmarks[folder.fileBookmark.bookmark.bookmark.rowID!] else {
        return
      }

      let source = URLSource(
        url: bookmark.resolved.url,
        options: folder.fileBookmark.bookmark.bookmark.options!,
      )

      openFinder(at: source)
    }
  }
}
