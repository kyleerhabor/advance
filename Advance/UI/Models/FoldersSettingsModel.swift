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

struct FoldersSettingsModelCopyState1 {
  let folder: FoldersSettingsModelCopyFolderInfo?
  let items: [RowID: FoldersSettingsModelCopyImagesItemInfo]
}

struct FoldersSettingsModelCopyFileExistsError {
  let source: String
  let destination: String
}

extension FoldersSettingsModelCopyFileExistsError: Equatable, Error {}

enum FoldersSettingsModelCopyErrorType {
  case fileExists(FoldersSettingsModelCopyFileExistsError)
}

extension FoldersSettingsModelCopyErrorType: Equatable, Error {}

struct FoldersSettingsModelCopyError {
  let locale: Locale
  let type: FoldersSettingsModelCopyErrorType
}

extension FoldersSettingsModelCopyError: Equatable, Error {}

extension FoldersSettingsModelCopyError: LocalizedError {
  var errorDescription: String? {
    switch type {
      case let .fileExists(error):
        String(
          localized: "Settings.Accessory.Folders.Item.Copy.Error.FileExists.Source.\(error.source).Destination.\(error.destination)",
          locale: locale,
        )
    }
  }
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

  func copy(
    to folder: FoldersSettingsItemModel,
    items: Set<ImagesItemModel2.ID>,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(FoldersSettingsModelCopyError) {
    try await _copy(
      to: folder.id,
      items: items,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
  }

  func copy(
    to source: URLSource,
    items: Set<ImagesItemModel2.ID>,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(FoldersSettingsModelCopyError) {
    try await _copy(
      to: source,
      items: items,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
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

  nonisolated private func copy(
    to source: URLSource,
    items: [ImagesItemInfo],
    state: ImagesItemAssignment,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(FoldersSettingsModelCopyError) {
    do {
      try source.accessingSecurityScopedResource {
        try items.forEach { item in
          let relative: URLSource?

          do {
            relative = try state.relative(item.fileBookmark.relative)
          } catch {
            // TODO: Elaborate.
            Logger.model.error("\(error)")

            return
          }

          guard let bookmark = state.bookmarks[item.fileBookmark.bookmark.bookmark.rowID!] else {
            return
          }

          let item = URLSource(url: bookmark.resolved.url, options: item.fileBookmark.bookmark.bookmark.options!)
          try relative.accessingSecurityScopedResource {
            try item.accessingSecurityScopedResource {
              // I've no idea whether or not this contains characters that are invalid for file paths.
              guard let components = FileManager.default.componentsToDisplay(
                forPath: item.url.deletingLastPathComponent().pathString,
              ) else {
                // TODO: Log.
                return
              }

              let lastPathComponent = item.url.lastPathComponent

              do {
                // TODO: Don't use lastPathComponent.
                do {
                  try FileManager.default.copyItem(
                    at: item.url,
                    to: source.url.appending(component: lastPathComponent, directoryHint: .notDirectory),
                  )
                } catch let error as CocoaError where error.code == .fileWriteFileExists {
                  guard resolveConflicts else {
                    throw error
                  }

                  // TODO: Interpolate separator
                  //
                  // Given that localization supports this, I think it should be safe to assume that a collection of path
                  // components can be strung together by a common separator (in English, a space) embedding the true
                  // separator (say, an inequality sign).
                  let separator = switch (pathSeparator, pathDirection) {
                    case (.inequalitySign, .leading):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.InequalitySign.LeftToLeft",
                        locale: locale,
                      )
                    case (.inequalitySign, .trailing):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.InequalitySign.RightToLeft",
                        locale: locale,
                      )
                    case (.singlePointingAngleQuotationMark, .leading):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.SinglePointingAngleQuotationMark.LeftToRight",
                        locale: locale,
                      )
                    case (.singlePointingAngleQuotationMark, .trailing):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.SinglePointingAngleQuotationMark.RightToLeft",
                        locale: locale,
                      )
                    case (.blackPointingTriangle, .leading):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.BlackPointingTriangle.LeftToRight",
                        locale: locale,
                      )
                    case (.blackPointingTriangle, .trailing):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.BlackPointingTriangle.RightToLeft",
                        locale: locale,
                      )
                    case (.blackPointingSmallTriangle, .leading):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.BlackPointingSmallTriangle.LeftToRight",
                        locale: locale,
                      )
                    case (.blackPointingSmallTriangle, .trailing):
                      String(
                        localized: "Settings.Accessory.Folders.Item.Path.Separator.BlackPointingSmallTriangle.RightToLeft",
                        locale: locale,
                      )
                  }

                  let pathComponents = components
                    .reversed()
                    .reductions(into: []) { $0.append($1) }
                    .dropFirst() // The initial reduction (an empty array)

                  for pathComponents in pathComponents {
                    let path = pathComponents.joined(separator: separator)
                    let component = String(
                      localized: "Settings.Accessory.Folders.Item.Copy.Name.\(item.url.deletingPathExtension().lastPathComponent).Path.\(path)",
                      locale: locale,
                    )

                    do {
                      try FileManager.default.copyItem(
                        at: item.url,
                        to: source.url
                          .appending(component: component, directoryHint: .notDirectory)
                          .appendingPathExtension(item.url.pathExtension),
                      )
                    } catch let error as CocoaError where error.code == .fileWriteFileExists {
                      continue
                    } catch {
                      // TODO: Elaborate.
                      Logger.model.error("\(error)")

                      return
                    }

                    return
                  }

                  throw error
                } catch {
                  // TODO: Elaborate.
                  Logger.model.error("\(error)")

                  return
                }
              } catch {
                throw FoldersSettingsModelCopyError(
                  locale: locale,
                  type: .fileExists(FoldersSettingsModelCopyFileExistsError(
                    source: lastPathComponent,
                    destination: source.url.lastPathComponent,
                  )),
                )
              }
            }
          }
        }
      }
    } catch {
      // I don't see why Swift thinks this is any Error.
      throw error as! FoldersSettingsModelCopyError
    }
  }

  nonisolated private func _copy(
    to folder: FoldersSettingsItemModel.ID,
    items: Set<ImagesItemModel2.ID>,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(FoldersSettingsModelCopyError) {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state1: FoldersSettingsModelCopyState1

    do {
      state1 = try await connection.read { db in
        let folder = try FolderRecord
          .select(.rowID)
          .filter(key: folder)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(FoldersSettingsModelCopyFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(FoldersSettingsModelCopyFolderFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: FoldersSettingsModelCopyFolderInfo.self)
          .fetchOne(db)

        let items = try ImagesItemRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(FoldersSettingsModelCopyImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(FoldersSettingsModelCopyImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(FoldersSettingsModelCopyImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: FoldersSettingsModelCopyImagesItemInfo.self)
          .fetchCursor(db)

        return FoldersSettingsModelCopyState1(
          folder: folder,
          items: try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) }),
        )
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let folder = state1.folder else {
      // TODO: Log.
      return
    }

    let options = folder.fileBookmark.bookmark.bookmark.options!
    let bookmark: AssignedBookmark?

    do {
      bookmark = try AssignedBookmark(
        data: folder.fileBookmark.bookmark.bookmark.data!,
        options: options,
        relativeTo: nil,
      )
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      bookmark = nil
    }

    let items = items.map { item in
      let item = state1.items[item]!

      return ImagesItemInfo(
        item: item.item,
        fileBookmark: ImagesItemFileBookmarkInfo(
          fileBookmark: item.fileBookmark.fileBookmark,
          bookmark: ImagesItemFileBookmarkBookmarkInfo(
            bookmark: item.fileBookmark.bookmark.bookmark,
          ),
          relative: item.fileBookmark.relative.map { relative in
            ImagesItemFileBookmarkRelativeInfo(
              relative: relative.relative,
            )
          },
        ),
      )
    }

    var state2 = ImagesItemAssignment()
    await state2.assign(items: items)

    do {
      try await connection.write { [state2] db in
        try write(db, bookmark: folder.fileBookmark.bookmark.bookmark, assigned: bookmark)
        try state2.write(db, items: items)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let bookmark else {
      return
    }

    try await copy(
      to: URLSource(url: bookmark.resolved.url, options: options),
      items: items,
      state: state2,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
  }

  nonisolated private func _copy(
    to source: URLSource,
    items: Set<ImagesItemModel2.ID>,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(FoldersSettingsModelCopyError) {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    // TODO: De-duplicate.
    let items2: [RowID: FoldersSettingsModelCopyImagesItemInfo]

    do {
      items2 = try await connection.read { db in
        let items = try ImagesItemRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(FoldersSettingsModelCopyImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(FoldersSettingsModelCopyImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(FoldersSettingsModelCopyImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: FoldersSettingsModelCopyImagesItemInfo.self)
          .fetchCursor(db)

        return try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) })
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let items3 = items.map { item in
      let item = items2[item]!

      return ImagesItemInfo(
        item: item.item,
        fileBookmark: ImagesItemFileBookmarkInfo(
          fileBookmark: item.fileBookmark.fileBookmark,
          bookmark: ImagesItemFileBookmarkBookmarkInfo(
            bookmark: item.fileBookmark.bookmark.bookmark,
          ),
          relative: item.fileBookmark.relative.map { relative in
            ImagesItemFileBookmarkRelativeInfo(
              relative: relative.relative,
            )
          },
        ),
      )
    }

    var state2 = ImagesItemAssignment()
    await state2.assign(items: items3)

    do {
      try await connection.write { [state2] db in
        try state2.write(db, items: items3)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    try await copy(
      to: source,
      items: items3,
      state: state2,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
  }
}
