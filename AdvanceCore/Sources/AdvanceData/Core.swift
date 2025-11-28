//
//  Core.swift
//  
//
//  Created by Kyle Erhabor on 6/11/24.
//

import AdvanceCore
import BigInt
import Foundation
import GRDB
import OSLog

public struct DataBookmark {
  public let bookmark: AssignedBookmark
  public let hash: Data

  public init(bookmark: AssignedBookmark, hash: Data) {
    self.bookmark = bookmark
    self.hash = hash
  }

  static func hash(data: Data) -> Data {
    AdvanceData.hash(data: data)
  }
}

extension DataBookmark {
  public init(
    data: Data,
    options: URL.BookmarkResolutionOptions,
    hash: Data,
    relativeTo relative: URL?,
    create: (URL) throws -> Data,
  ) throws {
    var hash = hash
    let resolved = try AssignedBookmark(
      data: data,
      options: options,
      relativeTo: relative
    ) { url in
      let data = try create(url)
      hash = Self.hash(data: data)

      return data
    }

    self.init(bookmark: resolved, hash: hash)
  }
}

extension DataBookmark: Sendable {}

public struct LibraryModelUpdateImagesItemFileBookmarkBookmarkInfo {
  public let bookmark: BookmarkRecord
}

extension LibraryModelUpdateImagesItemFileBookmarkBookmarkInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemFileBookmarkRelativeInfo {
  public let relative: BookmarkRecord
}

extension LibraryModelUpdateImagesItemFileBookmarkRelativeInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemFileBookmarkInfo {
  public let fileBookmark: FileBookmarkRecord
  public let bookmark: LibraryModelUpdateImagesItemFileBookmarkBookmarkInfo
  public let relative: LibraryModelUpdateImagesItemFileBookmarkRelativeInfo?
}

extension LibraryModelUpdateImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension LibraryModelUpdateImagesItemFileBookmarkInfo: Sendable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemInfo {
  public let item: ImagesItemRecord
  public let fileBookmark: LibraryModelUpdateImagesItemFileBookmarkInfo
}

extension LibraryModelUpdateImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, fileBookmark
  }
}

extension LibraryModelUpdateImagesItemInfo: Sendable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemFileBookmarkBookmarkInfo {
  public let bookmark: BookmarkRecord
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkBookmarkInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemFileBookmarkRelativeInfo {
  public let relative: BookmarkRecord
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkRelativeInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo {
  public let fileBookmark: FileBookmarkRecord
  public let bookmark: LibraryModelTrackImagesItemsImagesItemFileBookmarkBookmarkInfo
  public let relative: LibraryModelTrackImagesItemsImagesItemFileBookmarkRelativeInfo?
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo: Sendable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemInfo {
  public let item: ImagesItemRecord
  public let fileBookmark: LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo
}

extension LibraryModelTrackImagesItemsImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, fileBookmark
  }
}

extension LibraryModelTrackImagesItemsImagesItemInfo: Sendable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesInfo {
  public let images: ImagesRecord
  public let items: [LibraryModelTrackImagesItemsImagesItemInfo]
}

extension LibraryModelTrackImagesItemsImagesInfo: Decodable {
  enum CodingKeys: CodingKey {
    case images, items
  }
}

extension LibraryModelTrackImagesItemsImagesInfo: Sendable, FetchableRecord {}

public struct LibraryModelIDImagesInfo {
  public let images: ImagesRecord
}

extension LibraryModelIDImagesInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelTrackImagesPropertiesImagesCurrentItemInfo {
  public let item: ImagesItemRecord
}

extension LibraryModelTrackImagesPropertiesImagesCurrentItemInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelTrackImagesPropertiesImagesInfo {
  public let images: ImagesRecord
  public let currentItem: LibraryModelTrackImagesPropertiesImagesCurrentItemInfo
}

extension LibraryModelTrackImagesPropertiesImagesInfo: Decodable {
  enum CodingKeys: CodingKey {
    case images, currentItem
  }
}

extension LibraryModelTrackImagesPropertiesImagesInfo: Sendable, FetchableRecord {}

public struct FoldersSettingsModelTrackFoldersFolderFileBookmarkBookmarkInfo {
  public let bookmark: BookmarkRecord
}

extension FoldersSettingsModelTrackFoldersFolderFileBookmarkBookmarkInfo: Sendable, Decodable, FetchableRecord {}

public struct FoldersSettingsModelTrackFoldersFolderFileBookmarkInfo {
  public let fileBookmark: FileBookmarkRecord
  public let bookmark: FoldersSettingsModelTrackFoldersFolderFileBookmarkBookmarkInfo
}

extension FoldersSettingsModelTrackFoldersFolderFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark"
  }
}

extension FoldersSettingsModelTrackFoldersFolderFileBookmarkInfo: Sendable, FetchableRecord {}

public struct FoldersSettingsModelTrackFoldersFolderInfo {
  public let folder: FolderRecord
  public let fileBookmark: FoldersSettingsModelTrackFoldersFolderFileBookmarkInfo
}

extension FoldersSettingsModelTrackFoldersFolderInfo: Decodable {
  enum CodingKeys: CodingKey {
    case folder, fileBookmark
  }
}

extension FoldersSettingsModelTrackFoldersFolderInfo: Sendable, FetchableRecord {}

public typealias DatabaseConnection = DatabaseReader & DatabaseWriter

public actor DataStack<Connection> where Connection: DatabaseConnection {
  nonisolated public let connection: Connection

  public var urls = [Data: URL]()

  public init(connection: Connection) {
    self.connection = connection
  }

  public func register(hash: Data, url: URL) {
    urls[hash] = url
  }

  public func register(urls: [Data: URL]) -> [Data: URL] {
    self.urls.merge(urls) { $1 }

    return urls
  }

  // MARK: - Reading

  nonisolated static func buildBookmarkRequest<Request>(_ bookmark: Request) -> Request where Request: DerivableRequest {
    bookmark.select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options, BookmarkRecord.Columns.hash)
  }

  nonisolated static func buildLimitedBookmarkRequest<Request>(_ bookmark: Request) -> Request where Request: DerivableRequest {
    bookmark.select(.rowID, BookmarkRecord.Columns.options, BookmarkRecord.Columns.hash)
  }

  nonisolated public static func fetch(_ db: Database, items: some Sequence<RowID>) throws -> [LibraryModelUpdateImagesItemInfo] {
    try ImagesItemRecord
      .select(.rowID, ImagesItemRecord.Columns.isBookmarked)
      .filter(items.contains(Column.rowID))
      .including(
        required: ImagesItemRecord.fileBookmark
          .forKey(LibraryModelUpdateImagesItemInfo.CodingKeys.fileBookmark)
          .select(.rowID)
          .including(
            required: buildBookmarkRequest(FileBookmarkRecord.bookmark)
              .forKey(LibraryModelUpdateImagesItemFileBookmarkInfo.CodingKeys.bookmark),
          )
          .including(
            optional: buildBookmarkRequest(FileBookmarkRecord.relative)
              .forKey(LibraryModelUpdateImagesItemFileBookmarkInfo.CodingKeys.relative),
          ),
      )
      .asRequest(of: LibraryModelUpdateImagesItemInfo.self)
      .fetchAll(db)
  }

  nonisolated public func trackImagesItems(images: RowID) -> AsyncValueObservation<LibraryModelTrackImagesItemsImagesInfo?> {
    ValueObservation
      .trackingConstantRegion { db in
        try ImagesRecord
          .select(.rowID)
          .filter(key: images)
          .including(
            all: ImagesRecord.items
              .forKey(LibraryModelTrackImagesItemsImagesInfo.CodingKeys.items)
              .select(.rowID, ImagesItemRecord.Columns.isBookmarked)
              .order(ImagesItemRecord.Columns.priority)
              .including(
                required: ImagesItemRecord.fileBookmark
                  .forKey(LibraryModelTrackImagesItemsImagesItemInfo.CodingKeys.fileBookmark)
                  .select(.rowID)
                  .including(
                    required: Self.buildLimitedBookmarkRequest(FileBookmarkRecord.bookmark)
                      .forKey(LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo.CodingKeys.bookmark),
                  )
                  .including(
                    optional: Self.buildLimitedBookmarkRequest(FileBookmarkRecord.relative)
                      .forKey(LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo.CodingKeys.relative),
                  ),
              ),
          )
          .asRequest(of: LibraryModelTrackImagesItemsImagesInfo.self)
          .fetchOne(db)
      }
      .values(in: connection, bufferingPolicy: .bufferingNewest(1))
  }

  nonisolated public func trackImagesProperties(
    images: RowID,
  ) -> AsyncValueObservation<LibraryModelTrackImagesPropertiesImagesInfo?> {
    ValueObservation
      .trackingConstantRegion { db in
        try ImagesRecord
          .select(.rowID)
          .filter(key: images)
          .including(
            required: ImagesRecord.currentItem
              .forKey(LibraryModelTrackImagesPropertiesImagesInfo.CodingKeys.currentItem)
              .select(.rowID),
          )
          .asRequest(of: LibraryModelTrackImagesPropertiesImagesInfo.self)
          .fetchOne(db)
      }
      .values(in: connection, bufferingPolicy: .bufferingNewest(1))
  }

  nonisolated public static func fetchBookmarks(
    _ db: Database,
    bookmarks: some Sequence<RowID>,
  ) throws -> Dictionary<RowID, BookmarkRecord> {
    let cursor = try buildBookmarkRequest(BookmarkRecord.filter(bookmarks.contains(Column.rowID)))
      .fetchCursor(db)
      .map { ($0.rowID!, $0) }

    return try Dictionary(uniqueKeysWithValues: cursor)
  }

  nonisolated public func trackFolders() -> AsyncValueObservation<[FoldersSettingsModelTrackFoldersFolderInfo]> {
    ValueObservation
      .trackingConstantRegion { db in
        try FolderRecord
          .select(.rowID)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(FoldersSettingsModelTrackFoldersFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: Self.buildLimitedBookmarkRequest(FileBookmarkRecord.bookmark)
                  .forKey(FoldersSettingsModelTrackFoldersFolderFileBookmarkInfo.CodingKeys.bookmark),
              ),
          )
          .asRequest(of: FoldersSettingsModelTrackFoldersFolderInfo.self)
          .fetchAll(db)
      }
      .values(in: connection, bufferingPolicy: .bufferingNewest(1))
  }

  // MARK: - Writing

  nonisolated public static func idImages(_ db: Database, id: UUID) throws -> LibraryModelIDImagesInfo {
    if let images = try ImagesRecord
      .select(.rowID, ImagesRecord.Columns.id)
      .filter(ImagesRecord.Columns.id == id)
      .asRequest(of: LibraryModelIDImagesInfo.self)
      .fetchOne(db) {
      return images
    }

    var images = ImagesRecord(id: id, currentItem: nil)
    try images.insert(db)

    // This is probably not good.
    return LibraryModelIDImagesInfo(images: images)
  }

  nonisolated public static func submitBookmark(
    _ db: Database,
    data: Data,
    options: URL.BookmarkCreationOptions,
    hash: Data,
  ) throws -> BookmarkRecord {
    var bookmark = BookmarkRecord(data: data, options: options, hash: hash)
    try bookmark.upsert(db)

    return bookmark
  }

  nonisolated public static func submitFileBookmark(
    _ db: Database,
    bookmark: RowID,
    relative: RowID?,
  ) throws -> FileBookmarkRecord {
    var fileBookmark = FileBookmarkRecord(bookmark: bookmark, relative: relative)
    try fileBookmark.upsert(db)

    return fileBookmark
  }

  // TODO: Refactor.
  //
  // Creating a method for each column to update will get unwieldly real quick.
  nonisolated public static func submitImagesItemBookmark(
    _ db: Database,
    item: RowID,
    isBookmarked: Bool,
  ) throws {
    let imagesItem = ImagesItemRecord(
      rowID: item,
      position: nil,
      priority: nil,
      isBookmarked: isBookmarked,
      fileBookmark: nil,
    )

    try imagesItem.update(db, columns: [ImagesItemRecord.Columns.isBookmarked])
  }

  nonisolated public static func submitImagesItems(
    _ db: Database,
    bookmark: Source<some RangeReplaceableCollection<Bookmark>>,
    images: RowID,
    priority: Int,
  ) throws -> [(bookmark: BookmarkRecord, item: ImagesItemRecord?)] {
    var data: [(bookmark: BookmarkRecord, item: ImagesItemRecord?)]

    switch bookmark {
      case .source(let bookmark):
        var bookmark = BookmarkRecord(
          data: bookmark.data,
          options: bookmark.options,
          hash: hash(data: bookmark.data),
        )

        try bookmark.upsert(db)

        var fileBookmark = FileBookmarkRecord(bookmark: bookmark.rowID, relative: nil)
        try fileBookmark.upsert(db)

        let priority = priority.incremented()
        var imagesItem = ImagesItemRecord(
          position: BigFraction.zero,
          priority: priority,
          isBookmarked: false,
          fileBookmark: fileBookmark.rowID,
        )

        try imagesItem.insert(db)

        var itemImages = ItemImagesRecord(images: images, item: imagesItem.rowID)
        try itemImages.insert(db)

        data = [(bookmark: bookmark, item: imagesItem)]
      case .document(let document):
        var bookmark = BookmarkRecord(
          data: document.source.data,
          options: document.source.options,
          hash: hash(data: document.source.data),
        )

        try bookmark.upsert(db)

        var fileBookmark = FileBookmarkRecord(bookmark: bookmark.rowID, relative:  nil)
        try fileBookmark.upsert(db)

        let values = try document.items.reduce(
          into: [(bookmark: BookmarkRecord, item: ImagesItemRecord?)](),
        ) { partialResult, book in
          var bookmark2 = BookmarkRecord(
            data: book.data,
            options: book.options,
            hash: hash(data: book.data),
          )

          try bookmark2.upsert(db)

          var fileBookmark = FileBookmarkRecord(bookmark: bookmark2.rowID, relative: bookmark.rowID)
          try fileBookmark.upsert(db)

          let priority = (partialResult.last?.item?.priority ?? priority).incremented()
          var imagesItem = ImagesItemRecord(
            position: BigFraction.zero,
            priority: priority,
            isBookmarked: false,
            fileBookmark: fileBookmark.rowID,
          )

          try imagesItem.insert(db)

          var itemImages = ItemImagesRecord(images: images, item: imagesItem.rowID)
          try itemImages.insert(db)

          partialResult.append((bookmark: bookmark2, item: imagesItem))
        }

        data = Array(reservingCapacity: values.count.incremented())
        data.append((bookmark: bookmark, item: nil))
        data.append(contentsOf: values)
    }

    return data
  }

  nonisolated public static func submitImagesCurrentItem(
    _ db: Database,
    images: RowID,
    currentItem: RowID?,
  ) throws {
    let images = ImagesRecord(rowID: images, id: nil, currentItem: currentItem)
    try images.update(db, columns: [ImagesRecord.Columns.currentItem])
  }

  nonisolated public static func createFolder(_ db: Database, fileBookmark: RowID) throws -> FolderRecord {
    var folder = FolderRecord(fileBookmark: fileBookmark)
    try folder.insert(db)

    return folder
  }

  nonisolated public static func deleteFolders(_ db: Database, folders: [RowID]) throws {
    try FolderRecord.deleteAll(db, keys: folders)
  }

  // MARK: - Old
}

extension DataStack: Sendable where Connection: Sendable {}

public func createSchema(connection: DatabaseConnection) async throws {
  var migrator = DatabaseMigrator()

  #if DEBUG
  migrator.eraseDatabaseOnSchemaChange = true

  #endif

  migrator.registerMigration("v1") { db in
    try db.create(table: BookmarkRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(BookmarkRecord.Columns.data.name, .blob)
        .notNull()
        .unique()

      table
        .column(BookmarkRecord.Columns.options.name, .integer)
        .notNull()

      // Do we need to embed this here?
      table
        .column(BookmarkRecord.Columns.hash.name, .blob)
        .notNull()
        .unique()
    }

    try db.create(table: FileBookmarkRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(FileBookmarkRecord.Columns.bookmark.name, .integer)
        .notNull()
        .unique()
        .references(BookmarkRecord.databaseTableName)

      table
        .column(FileBookmarkRecord.Columns.relative.name, .integer)
        .references(BookmarkRecord.databaseTableName)
        .indexed()
    }

    try db.create(table: ImagesItemRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)

      // TODO: Enforce uniqueness via trigger.
      table
        .column(ImagesItemRecord.Columns.position.name, .blob)
        .notNull()

      table
        .column(ImagesItemRecord.Columns.priority.name, .integer)
        .notNull()

      table
        .column(ImagesItemRecord.Columns.isBookmarked.name, .boolean)
        .notNull()

      table
        .column(ImagesItemRecord.Columns.fileBookmark.name, .integer)
        .notNull()
        .references(FileBookmarkRecord.databaseTableName)
        .indexed()
    }

    try db.create(table: ImagesRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ImagesRecord.Columns.id.name, .blob)
        .notNull()
        .unique()

      // TODO: Ensure ItemImagesRecord(images: id, item: currentItem).
      table
        .column(ImagesRecord.Columns.currentItem.name, .integer)
        .references(ImagesItemRecord.databaseTableName)
        .indexed()
    }

    try db.create(table: ItemImagesRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ItemImagesRecord.Columns.images.name, .integer)
        .notNull()
        .references(ImagesRecord.databaseTableName)
        .indexed()

      table
        .column(ItemImagesRecord.Columns.item.name, .integer)
        .notNull()
        .unique()
        .references(ImagesItemRecord.databaseTableName)
    }

    try db.create(table: FolderPathComponentRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      // We could de-duplicate this, but the table only exists so we don't have to encode an array of strings manually.
      // That is, if encoding wasn't a concern, we'd have duplication regardless.
      table
        .column(FolderPathComponentRecord.Columns.component.name, .text)
        .notNull()

      table
        .column(FolderPathComponentRecord.Columns.position.name, .integer)
        .notNull()
    }

    try db.create(table: FolderRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(FolderRecord.Columns.fileBookmark.name, .integer)
        .notNull()
        .unique()
        .references(BookmarkRecord.databaseTableName)
    }

    try db.create(table: PathComponentFolderRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(PathComponentFolderRecord.Columns.folder.name, .integer)
        .notNull()
        .references(FolderRecord.databaseTableName, onDelete: .cascade)
        .indexed()

      table
        .column(PathComponentFolderRecord.Columns.pathComponent.name, .integer)
        .notNull()
        .unique()
        .references(FolderPathComponentRecord.databaseTableName)
    }

    let pathComponentFolderPathComponentPosition = "\(PathComponentFolderRecord.databaseTableName).\(PathComponentFolderRecord.Columns.pathComponent.name).\(FolderPathComponentRecord.Columns.position.name)"
    let pathComponentFolderPathComponentPositionWhen: SQL = """
      SELECT 1
      FROM \(FolderPathComponentRecord.self)
      LEFT JOIN \(PathComponentFolderRecord.self) other
        ON other.\(.rowID) != NEW.\(.rowID)
      LEFT JOIN \(FolderPathComponentRecord.self) other_folder_path_component
        ON other_folder_path_component.\(.rowID) = other.\(PathComponentFolderRecord.Columns.pathComponent)
      WHERE \(FolderPathComponentRecord.self).\(.rowID) = NEW.\(PathComponentFolderRecord.Columns.pathComponent)
        AND other.\(PathComponentFolderRecord.Columns.folder) = NEW.\(PathComponentFolderRecord.Columns.folder)
        AND \(FolderPathComponentRecord.self).\(FolderPathComponentRecord.Columns.position) = other_folder_path_component.\(FolderPathComponentRecord.Columns.position)
      """

    let pathComponentFolderPathComponentPositionMessage = "(\(PathComponentFolderRecord.databaseTableName).\(PathComponentFolderRecord.Columns.folder.name), \(PathComponentFolderRecord.databaseTableName).\(PathComponentFolderRecord.Columns.pathComponent.name).\(FolderPathComponentRecord.Columns.position.name)) must be unique"

    try db.execute(
      literal: """
      CREATE TRIGGER \(sql: "\(pathComponentFolderPathComponentPosition)_ai".quotedDatabaseIdentifier)
      AFTER INSERT ON \(PathComponentFolderRecord.self)
      FOR EACH ROW WHEN (\(pathComponentFolderPathComponentPositionWhen))
      BEGIN
        SELECT RAISE(ABORT, \(sql: pathComponentFolderPathComponentPositionMessage.quotedDatabaseIdentifier));
      END
      """,
    )

    try db.execute(
      literal: """
      CREATE TRIGGER \(sql: "\(pathComponentFolderPathComponentPosition)_au".quotedDatabaseIdentifier)
      AFTER UPDATE ON \(PathComponentFolderRecord.self)
      FOR EACH ROW WHEN (\(pathComponentFolderPathComponentPositionWhen))
      BEGIN
        SELECT RAISE(ABORT, \(sql: pathComponentFolderPathComponentPositionMessage.quotedDatabaseIdentifier));
      END
      """,
    )

    try db.execute(
      literal: """
      CREATE TRIGGER \(sql: "\(PathComponentFolderRecord.databaseTableName)_ad".quotedDatabaseIdentifier)
      AFTER DELETE ON \(PathComponentFolderRecord.self)
      FOR EACH ROW
      BEGIN
        DELETE FROM \(FolderPathComponentRecord.self)
        WHERE \(FolderPathComponentRecord.self).\(.rowID) = OLD.\(PathComponentFolderRecord.Columns.pathComponent);
      END
      """,
    )
  }

  try migrator.migrate(connection)
}
