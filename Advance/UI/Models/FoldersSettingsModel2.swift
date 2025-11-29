//
//  FoldersSettingsModel2.swift
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
  var source: URLSource?
  var isResolved: Bool
  var icon: NSImage
  var path: AttributedString
  var helpPath: AttributedString

  init(
    id: RowID,
    source: URLSource?,
    isResolved: Bool,
    icon: NSImage,
    path: AttributedString,
    helpPath: AttributedString,
  ) {
    self.id = id
    self.source = source
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
  let items: [FoldersSettingsModelCopyImagesItemInfo]
}

@Observable
@MainActor
final class FoldersSettingsModel2 {
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

  func isInvalidFinderSelection(of ids: Set<FoldersSettingsItemModel.ID>) -> Bool {
    ids.isEmpty || !ids.isSubset(of: resolved.ids)
  }

  func showFinder(items: Set<FoldersSettingsItemModel.ID>) {
    NSWorkspace.shared.activateFileViewerSelecting(items.compactMap { self.items[id: $0]?.source?.url })
  }

  func openFinder(item: FoldersSettingsItemModel) {
    openFinder(source: item.source!)
  }

  func openFinder(items: Set<FoldersSettingsItemModel.ID>) {
    items
      .compactMap { self.items[id: $0]?.source }
      .forEach { openFinder(source: $0) }
  }

  func copy(to folder: FoldersSettingsItemModel, items: Set<ImagesItemModel2.ID>) async {
    await _copy(to: folder.id, items: items)
  }

  func copyFolder(destination url: URL, items: Set<ImagesItemModel2.ID>) async {

  }

  nonisolated private func load(
    connection: DatabasePool,
    folders: [FoldersSettingsModelLoadFolderInfo],
    locale: Locale,
  ) async {
    struct State1ItemBookmark {
      let bookmark: AssignedBookmark
    }

    struct State1Item {
      let folder: FoldersSettingsModelLoadFolderInfo
      let bookmark: State1ItemBookmark?
    }

    struct State2Item {
      let folder: FoldersSettingsModelLoadFolderInfo
      let source: URLSource?
      let icon: NSImage
      let path: AttributedString
      let helpPath: AttributedString
    }

    struct State2ItemItem {
      let folder: FoldersSettingsModelLoadFolderInfo
      let source: URLSource?
      let icon: NSImage
      let pathComponents: [String]
    }

    let items = folders.map { folder in
      let bookmark: AssignedBookmark

      do {
        bookmark = try AssignedBookmark(
          data: folder.fileBookmark.bookmark.bookmark.data!,
          options: folder.fileBookmark.bookmark.bookmark.options!,
          relativeTo: nil,
        )
      } catch let error as CocoaError where error.code == .fileNoSuchFile {
        return State1Item(folder: folder, bookmark: nil)
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return State1Item(folder: folder, bookmark: nil)
      }

      return State1Item(folder: folder, bookmark: State1ItemBookmark(bookmark: bookmark))
    }

    guard items.compactMap(\.bookmark).allSatisfy(\.bookmark.resolved.isStale.inverted) else {
      do {
        try await connection.write { db in
          try items.forEach { item in
            guard let bookmark = item.bookmark else {
              return
            }

            var bookmark2 = BookmarkRecord(
              rowID: item.folder.fileBookmark.bookmark.bookmark.rowID,
              data: bookmark.bookmark.data,
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

    // TODO: De-duplicate.
    var separator = AttributedString(localized: "Settings.Accessory.Folders.Item.Path.Separator", locale: locale)
    separator.foregroundColor = .tertiaryLabelColor

    var helpSeparator = AttributedString(
      localized: "Settings.Accessory.Folders.Item.Path.Help.Separator",
      locale: locale,
    )

    helpSeparator.foregroundColor = .tertiaryLabelColor

    let items2 = items
      .map { item in
        let defaultPathComponents = item.folder.pathComponents.map(\.pathComponent.component!)

        guard let bookmark = item.bookmark else {
          return State2ItemItem(
            folder: item.folder,
            source: nil,
            icon: NSImage(),
            pathComponents: defaultPathComponents,
          )
        }

        let source = URLSource(
          url: bookmark.bookmark.resolved.url,
          options: item.folder.fileBookmark.bookmark.bookmark.options!,
        )

        let item = source.accessingSecurityScopedResource {
          State2ItemItem(
            folder: item.folder,
            source: source,
            icon: NSWorkspace.shared.icon(forFileAt: bookmark.bookmark.resolved.url),
            pathComponents: FileManager.default.componentsToDisplay(forPath: bookmark.bookmark.resolved.url.pathString)
              ?? defaultPathComponents,
          )
        }

        return item
      }
      .finderSort(by: \.pathComponents)
      .map { item in
        let path = item.pathComponents
          .map { AttributedString($0) }
          .interspersed(with: separator)
          .reduce(AttributedString(), +)

        let helpPath = item.pathComponents
          .map { AttributedString($0) }
          .interspersed(with: helpSeparator)
          .reduce(AttributedString(), +)

        return State2Item(folder: item.folder, source: item.source, icon: item.icon, path: path, helpPath: helpPath)
      }

    Task { @MainActor in
      self.items = IdentifiedArray(
        uniqueElements: items2.map { item in
          let id = item.folder.folder.rowID!
          let isResolved = item.source != nil

          guard let model = self.items[id: id] else {
            let model = FoldersSettingsItemModel(
              id: id,
              source: item.source,
              isResolved: isResolved,
              icon: item.icon,
              path: item.path,
              helpPath: item.helpPath
            )

            return model
          }

          model.source = item.source
          model.isResolved = isResolved
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
      .removeDuplicates()

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

  private func openFinder(source: URLSource) {
    let opened = source.accessingSecurityScopedResource {
      NSWorkspace.shared.open(source.url)
    }

    guard opened else {
      Logger.model.log("Could not open folder at file URL '\(source.url.pathString)'")

      return
    }
  }

  nonisolated private func _copy(
    to folder: FoldersSettingsItemModel.ID,
    items: Set<ImagesItemModel2.ID>,
  ) async {
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
          .fetchAll(db)

        return FoldersSettingsModelCopyState1(folder: folder, items: items)
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

    let items = state1.items.map { item in
      ImagesItemInfo(
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

    var state2 = ImagesItemAssignment()
    await state2.assign(items: items)

    if bookmark.resolved.isStale || !state2.isSatisified(with: items) {
      do {
        try await connection.write { [state2] db in
          let bookmark = BookmarkRecord(
            rowID: folder.fileBookmark.bookmark.bookmark.rowID,
            data: bookmark.data,
            options: nil,
          )

          try bookmark.update(db, columns: [BookmarkRecord.Columns.data])
          try state2.write(db, items: items)
        }
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }
    }

    Logger.model.debug("Done.")
  }
}
