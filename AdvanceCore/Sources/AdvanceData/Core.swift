//
//  Core.swift
//  
//
//  Created by Kyle Erhabor on 6/11/24.
//

import AdvanceCore
import BigDecimal
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

public struct LibraryModelUpdateImagesItemImageImageInfo {
  let image: ImageRecord
}

extension LibraryModelUpdateImagesItemImageImageInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemImageInfo {
  let image: ImagesItemImageRecord
  let image2: LibraryModelUpdateImagesItemImageImageInfo?
}

extension LibraryModelUpdateImagesItemImageInfo: Decodable {
  enum CodingKeys: CodingKey {
    case image, image2
  }
}

extension LibraryModelUpdateImagesItemImageInfo: Sendable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemFileBookmarkFileBookmarkBookmarkInfo {
  public let bookmark: BookmarkRecord
}

extension LibraryModelUpdateImagesItemFileBookmarkFileBookmarkBookmarkInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemFileBookmarkFileBookmarkRelativeInfo {
  public let relative: BookmarkRecord
}

extension LibraryModelUpdateImagesItemFileBookmarkFileBookmarkRelativeInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemFileBookmarkFileBookmarkInfo {
  public let fileBookmark: FileBookmarkRecord
  public let bookmark: LibraryModelUpdateImagesItemFileBookmarkFileBookmarkBookmarkInfo?
  public let relative: LibraryModelUpdateImagesItemFileBookmarkFileBookmarkRelativeInfo?
}

extension LibraryModelUpdateImagesItemFileBookmarkFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension LibraryModelUpdateImagesItemFileBookmarkFileBookmarkInfo: Sendable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemFileBookmarkInfo {
  public let fileBookmark: ImagesItemFileBookmarkRecord
  public let fileBookmark2: LibraryModelUpdateImagesItemFileBookmarkFileBookmarkInfo?
}

extension LibraryModelUpdateImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: CodingKey {
    case fileBookmark, fileBookmark2
  }
}

extension LibraryModelUpdateImagesItemFileBookmarkInfo: Sendable, FetchableRecord {}

public struct LibraryModelUpdateImagesItemInfo {
  public let item: ImagesItemRecord
  public let image: LibraryModelUpdateImagesItemImageInfo?
  public let fileBookmark: LibraryModelUpdateImagesItemFileBookmarkInfo?
}

extension LibraryModelUpdateImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, image, fileBookmark
  }
}

extension LibraryModelUpdateImagesItemInfo: Sendable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemImageImageInfo {
  let image: ImageRecord
}

extension LibraryModelTrackImagesItemsImagesItemImageImageInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemImageInfo {
  let image: ImagesItemImageRecord
  let image2: LibraryModelTrackImagesItemsImagesItemImageImageInfo?
}

extension LibraryModelTrackImagesItemsImagesItemImageInfo: Decodable {
  enum CodingKeys: CodingKey {
    case image, image2
  }
}

extension LibraryModelTrackImagesItemsImagesItemImageInfo: Sendable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkBookmarkInfo {
  public let bookmark: BookmarkRecord
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkBookmarkInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkRelativeInfo {
  public let relative: BookmarkRecord
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkRelativeInfo: Sendable, Decodable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkInfo {
  public let fileBookmark: FileBookmarkRecord
  public let bookmark: LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkBookmarkInfo?
  public let relative: LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkRelativeInfo?
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkInfo: Sendable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo {
  public let fileBookmark: ImagesItemFileBookmarkRecord
  public let fileBookmark2: LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkInfo?
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: CodingKey {
    case fileBookmark, fileBookmark2
  }
}

extension LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo: Sendable, FetchableRecord {}

public struct LibraryModelTrackImagesItemsImagesItemInfo {
  public let item: ImagesItemRecord
  public let image: LibraryModelTrackImagesItemsImagesItemImageInfo?
  public let fileBookmark: LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo?
}

extension LibraryModelTrackImagesItemsImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, image, fileBookmark
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
    bookmark.select(Column.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options, BookmarkRecord.Columns.hash)
  }

  nonisolated static func buildLimitedBookmarkRequest<Request>(_ bookmark: Request) -> Request where Request: DerivableRequest {
    bookmark.select(Column.rowID, BookmarkRecord.Columns.options, BookmarkRecord.Columns.hash)
  }

  nonisolated public static func fetch(_ db: Database, items: some Sequence<RowID>) throws -> [LibraryModelUpdateImagesItemInfo] {
    try ImagesItemRecord
      .select(Column.rowID, ImagesItemRecord.Columns.type, ImagesItemRecord.Columns.isBookmarked)
      .filter(items.contains(Column.rowID))
      .including(
        optional: ImagesItemRecord.image
          .forKey(LibraryModelUpdateImagesItemInfo.CodingKeys.image)
          .select(Column.rowID)
          .including(
            // This should be required, but is optional to workaround the unimplemented feature:
            //
            // "Not implemented: chaining a required association behind an optional association"
            optional: ImagesItemImageRecord.image
              .forKey(LibraryModelUpdateImagesItemImageInfo.CodingKeys.image2)
              .select(Column.rowID, ImageRecord.Columns.data, ImageRecord.Columns.hash),
          ),
      )
      .including(
        optional: ImagesItemRecord.fileBookmark
          .forKey(LibraryModelUpdateImagesItemInfo.CodingKeys.fileBookmark)
          .select(Column.rowID)
          .including(
            // This should be required, but is optional to workaround the unimplemented feature:
            //
            // "Not implemented: chaining a required association behind an optional association"
            optional: ImagesItemFileBookmarkRecord.fileBookmark
              .forKey(LibraryModelUpdateImagesItemFileBookmarkInfo.CodingKeys.fileBookmark2)
              .including(
                optional: buildBookmarkRequest(FileBookmarkRecord.bookmark)
                  .forKey(LibraryModelUpdateImagesItemFileBookmarkFileBookmarkInfo.CodingKeys.bookmark),
              )
              .including(
                optional: buildBookmarkRequest(FileBookmarkRecord.relative)
                  .forKey(LibraryModelUpdateImagesItemFileBookmarkFileBookmarkInfo.CodingKeys.relative),
              ),
          ),
      )
      .asRequest(of: LibraryModelUpdateImagesItemInfo.self)
      .fetchAll(db)
  }

  nonisolated public func trackImagesItems(images: RowID) -> AsyncValueObservation<LibraryModelTrackImagesItemsImagesInfo?> {
    ValueObservation
      .trackingConstantRegion { db in
        try ImagesRecord
          .select(Column.rowID)
          .filter(key: images)
          .including(
            all: ImagesRecord.items
              .forKey(LibraryModelTrackImagesItemsImagesInfo.CodingKeys.items)
              .select(Column.rowID, ImagesItemRecord.Columns.id, ImagesItemRecord.Columns.isBookmarked, ImagesItemRecord.Columns.type)
              .order(ImagesItemRecord.Columns.priority)
              .including(
                optional: ImagesItemRecord.image
                  .forKey(LibraryModelTrackImagesItemsImagesItemInfo.CodingKeys.image)
                  .select(Column.rowID)
                  .including(
                    // This should be required, but is optional to workaround the unimplemented feature:
                    //
                    // "Not implemented: chaining a required association behind an optional association"
                    optional: ImagesItemImageRecord.image
                      .forKey(LibraryModelTrackImagesItemsImagesItemImageInfo.CodingKeys.image2)
                      // TODO: Implement.
                      .select(Column.rowID)
                  )
              )
              .including(
                optional: ImagesItemRecord.fileBookmark
                  .forKey(LibraryModelTrackImagesItemsImagesItemInfo.CodingKeys.fileBookmark)
                  .select(Column.rowID)
                  .including(
                    // This should be required, but is optional to workaround the unimplemented feature:
                    //
                    // "Not implemented: chaining a required association behind an optional association"
                    optional: ImagesItemFileBookmarkRecord.fileBookmark
                      .forKey(LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo.CodingKeys.fileBookmark2)
                      .including(
                        optional: Self.buildLimitedBookmarkRequest(FileBookmarkRecord.bookmark)
                          .forKey(LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkInfo.CodingKeys.bookmark),
                      )
                      .including(
                        optional: Self.buildLimitedBookmarkRequest(FileBookmarkRecord.relative)
                          .forKey(LibraryModelTrackImagesItemsImagesItemFileBookmarkFileBookmarkInfo.CodingKeys.relative),
                      ),
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
          .select(Column.rowID)
          .filter(key: images)
          .including(
            required: ImagesRecord.currentItem
              .forKey(LibraryModelTrackImagesPropertiesImagesInfo.CodingKeys.currentItem)
              .select(Column.rowID, ImagesItemRecord.Columns.id),
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
          .select(Column.rowID, FolderRecord.Columns.url)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(FoldersSettingsModelTrackFoldersFolderInfo.CodingKeys.fileBookmark)
              .select(Column.rowID)
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
      .select(Column.rowID, ImagesRecord.Columns.id)
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
      id: nil,
      position: nil,
      priority: nil,
      isBookmarked: isBookmarked,
      type: nil,
      image: nil,
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

        var imagesItemFileBookmark = ImagesItemFileBookmarkRecord(fileBookmark: fileBookmark.rowID)
        try imagesItemFileBookmark.insert(db)

        let priority = priority.incremented()
        var imagesItem = ImagesItemRecord(
          id: UUID(),
          position: BigDecimal(priority),
          priority: priority,
          isBookmarked: false,
          type: .fileBookmark,
          image: nil,
          fileBookmark: imagesItemFileBookmark.rowID,
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

          var imagesItemFileBookmark = ImagesItemFileBookmarkRecord(fileBookmark: fileBookmark.rowID)
          try imagesItemFileBookmark.insert(db)

          let priority = (partialResult.last?.item?.priority ?? priority).incremented()
          var imagesItem = ImagesItemRecord(
            id: UUID(),
            position: BigDecimal(priority),
            priority: priority,
            isBookmarked: false,
            type: .fileBookmark,
            image: nil,
            fileBookmark: imagesItemFileBookmark.rowID,
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

  nonisolated public static func createFolder(_ db: Database, fileBookmark: RowID, url: URL) throws -> FolderRecord {
    var folder = FolderRecord(fileBookmark: fileBookmark, url: url)
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

    try db.create(table: ImageRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ImageRecord.Columns.data.name, .blob)
        .unique()
        .notNull()

      table
        .column(ImageRecord.Columns.hash.name, .blob)
        .unique()
        .notNull()
    }

    try db.create(table: ImagesItemImageRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ImagesItemImageRecord.Columns.image.name, .integer)
        .notNull()
        .references(ImageRecord.databaseTableName)
        .indexed()
    }

    try db.create(table: ImagesItemFileBookmarkRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ImagesItemFileBookmarkRecord.Columns.fileBookmark.name, .integer)
        .notNull()
        .references(BookmarkRecord.databaseTableName)
        .indexed()
    }

    try db.create(table: ImagesItemRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ImagesItemRecord.Columns.id.name, .blob)
        .notNull()
        .unique()

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
        .column(ImagesItemRecord.Columns.type.name, .integer)
        .notNull()

      table
        .column(ImagesItemRecord.Columns.image.name, .integer)
        .unique()
        .references(ImagesItemImageRecord.databaseTableName)

      table
        .column(ImagesItemRecord.Columns.fileBookmark.name, .integer)
        .unique()
        .references(ImagesItemFileBookmarkRecord.databaseTableName)
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

    try db.create(table: FolderRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)

      table
        .column(FolderRecord.Columns.fileBookmark.name, .integer)
        .notNull()
        .unique()
        .references(BookmarkRecord.databaseTableName)

      // If we ever need to store file bookmark URLs for the same bookmark in other tables, we'll need to denormalize
      // this. This would probably be a file bookmark URL table mapping file bookmarks to URLs.
      table
        .column(FolderRecord.Columns.url.name, .text)
        .notNull()
    }

    // TODO: Use SQL literals.

    try db.execute(
      sql: """
        CREATE TRIGGER remove_orphaned_images_from_image_collection_images
        AFTER DELETE ON \(ImagesItemImageRecord.databaseTableName)
        BEGIN
          DELETE FROM \(ImageRecord.databaseTableName) WHERE \(ImageRecord.databaseTableName).\(Column.rowID.name) = OLD.\(ImagesItemImageRecord.Columns.image.name);
        END
        """
    )

//    try db.execute(
//      sql: """
//        CREATE TRIGGER remove_orphaned_bookmarks_from_image_collection_bookmarks
//        AFTER DELETE ON \(ImagesItemFileBookmarkRecord.databaseTableName)
//        WHEN NOT EXISTS (SELECT 1 FROM \(FolderRecord.databaseTableName) WHERE \(FolderRecord.databaseTableName).\(FolderRecord.Columns.fileBookmark.name) = OLD.\(ImagesItemFileBookmarkRecord.Columns.fileBookmark.name))
//        BEGIN
//          DELETE FROM \(BookmarkRecord.databaseTableName)
//          WHERE \(BookmarkRecord.databaseTableName).\(Column.rowID.name) = OLD.\(ImagesItemFileBookmarkRecord.Columns.fileBookmark.name);
//        END
//        """
//    )
//
//    try db.execute(
//      sql: """
//        CREATE TRIGGER remove_orphaned_bookmarks_from_folders
//        AFTER DELETE ON \(FolderRecord.databaseTableName)
//        WHEN NOT EXISTS (SELECT 1 FROM \(ImagesItemFileBookmarkRecord.databaseTableName) WHERE \(ImagesItemFileBookmarkRecord.databaseTableName).\(ImagesItemFileBookmarkRecord.Columns.fileBookmark.name) = OLD.\(FolderRecord.Columns.fileBookmark.name))
//        BEGIN
//          DELETE FROM \(BookmarkRecord.databaseTableName)
//          WHERE \(BookmarkRecord.databaseTableName).\(Column.rowID.name) = OLD.\(FolderRecord.Columns.bookmark.name);
//        END
//        """
//    )
  }

  try migrator.migrate(connection)

  // MARK: - Triggers

  //    try Self.creatingSchema(context: &context) {
  //      let subQuery = """
  //      SELECT 0
  //      FROM \(ImagesItemRecord.databaseTableName)
  //        LEFT JOIN \(ImagesBookmarkRecord.databaseTableName)
  //          ON \(ImagesBookmarkRecord.databaseTableName).\(Column.rowID.name) = NEW.\(ImagesItemRecord.Columns.bookmark.name)
  //        LEFT JOIN \(BookmarkRecord.databaseTableName)
  //          ON \(BookmarkRecord.databaseTableName).\(Column.rowID.name) = \(ImagesBookmarkRecord.databaseTableName).\(ImagesBookmarkRecord.Columns.bookmark.name)
  //      WHERE \(ImagesItemRecord.databaseTableName).\(Column.rowID.name) != NEW.\(Column.rowID.name)
  //      """
  //
  //      try db.execute(
  //        sql: """
  //        CREATE TRIGGER check_bookmarks_from_image_collection_items
  //        AFTER INSERT ON \(ImagesItemRecord.databaseTableName)
  //        WHEN (\(subQuery))
  //        BEGIN
  //          SELECT RAISE(ABORT, "\(ImagesItemRecord.databaseTableName).\(ImagesItemRecord.Columns.bookmark.name).\(ImagesBookmarkRecord.Columns.bookmark.name) must be unique");
  //        END
  //        """
  //      )
  //    }
}
