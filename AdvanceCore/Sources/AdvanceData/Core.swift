//
//  Core.swift
//  
//
//  Created by Kyle Erhabor on 6/11/24.
//

import Foundation
import GRDB

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

public typealias DatabaseConnection = DatabaseReader & DatabaseWriter

public actor DataStack<Connection> where Connection: DatabaseConnection {
  nonisolated public let connection: Connection

  public var urls = [Data: URL]()

  public init(connection: Connection) {
    self.connection = connection
  }

  public func register(urls: [Data: URL]) -> [Data: URL] {
    self.urls.merge(urls) { $1 }

    return urls
  }

  // MARK: - Reading

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
      isBookmarked: isBookmarked,
      fileBookmark: nil,
    )

    try imagesItem.update(db, columns: [ImagesItemRecord.Columns.isBookmarked])
  }

  nonisolated public static func submitImagesCurrentItem(
    _ db: Database,
    images: RowID,
    currentItem: RowID?,
  ) throws {
    let images = ImagesRecord(rowID: images, id: nil, currentItem: currentItem)
    try images.update(db, columns: [ImagesRecord.Columns.currentItem])
  }
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
