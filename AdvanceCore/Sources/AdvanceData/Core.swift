//
//  Core.swift
//  
//
//  Created by Kyle Erhabor on 6/11/24.
//

import AdvanceCore
import Dispatch
import Foundation
import GRDB
import OSLog

extension DispatchQueue {
  static let observation = DispatchQueue(label: "\(Bundle.appID).DatabaseObservation", qos: .default)
}

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
    creating create: (URL) throws -> Data
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

  nonisolated public static func fetch(_ db: Database, items: some Sequence<ImagesItemInfo>) throws -> [ImagesItemFetchResponse] {
    try ImagesItemRecord
      .select(Column.rowID, ImagesItemRecord.Columns.type, ImagesItemRecord.Columns.isBookmarked)
      .filter(items.contains(Column.rowID))
      .including(
        optional: ImagesItemRecord.imageAssociation
          .forKey(ImagesItemFetchResponse.CodingKeys.image)
          .select(Column.rowID)
          .including(
            // This should be required, but is optional to workaround the unimplemented feature:
            //
            // "Not implemented: chaining a required association behind an optional association"
            optional: ImagesImageRecord.imageAssociation
              .forKey(ImagesItemFetchImageResponse.CodingKeys.image)
              .select(Column.rowID, ImageRecord.Columns.data, ImageRecord.Columns.hash)
          )
      )
      .including(
        optional: ImagesItemRecord.bookmarkAssociation
          .forKey(ImagesItemFetchResponse.CodingKeys.bookmark)
          .select(Column.rowID)
          .including(
            // This should be required, but is optional to workaround the unimplemented feature:
            //
            // "Not implemented: chaining a required association behind an optional association"
            optional: buildBookmarkRequest(ImagesBookmarkRecord.bookmarkAssociation)
              .forKey(ImagesItemFetchBookmarkResponse.CodingKeys.bookmark)
              .including(
                optional: buildBookmarkRequest(BookmarkRecord.relativeAssociation)
                  .forKey(ImagesItemFetchBookmarkSourceResponse.CodingKeys.relative)
              )
          )
      )
      .asRequest(of: ImagesItemFetchResponse.self)
      .fetchAll(db)
  }

  public nonisolated static func fetchBookmarks(
    _ db: Database,
    bookmarks: some Sequence<BookmarkInfo>
  ) throws -> Dictionary<BookmarkInfo, BookmarkResponse> {
    let cursor = try buildBookmarkRequest(BookmarkRecord.filter(bookmarks.contains(Column.rowID)))
      .asRequest(of: BookmarkResponse.self)
      .fetchCursor(db)
      .map { ($0.bookmark, $0) }

    return try Dictionary(uniqueKeysWithValues: cursor)
  }

  nonisolated public func track(itemsForImages: ImagesInfo) -> AsyncValueObservation<ImagesItemsTrackerResponse?> {
    let record = ImagesRecord.filter(key: itemsForImages.rowID)
    let observation = ValueObservation.trackingConstantRegion { db in
      try record
        .select(Column.rowID)
        .including(
          all: ImagesRecord.items
            .forKey(ImagesItemsTrackerResponse.CodingKeys.items)
            .select(Column.rowID, ImagesItemRecord.Columns.id, ImagesItemRecord.Columns.isBookmarked, ImagesItemRecord.Columns.type)
            .order(ImagesItemRecord.Columns.priority)
            .including(
              optional: ImagesItemRecord.imageAssociation
                .forKey(ImagesItemTrackerResponse.CodingKeys.image)
                .select(Column.rowID)
                .including(
                  // This should be required, but is optional to workaround the unimplemented feature:
                  //
                  // "Not implemented: chaining a required association behind an optional association"
                  optional: ImagesImageRecord.imageAssociation
                    .forKey(ImagesImageTrackerResponse.CodingKeys.image)
                    .select(Column.rowID)
                )
            )
            .including(
              optional: ImagesItemRecord.bookmarkAssociation
                .forKey(ImagesItemTrackerResponse.CodingKeys.bookmark)
                .select(Column.rowID)
                .including(
                  // This should be required, but is optional to workaround the unimplemented feature:
                  //
                  // "Not implemented: chaining a required association behind an optional association"
                  optional: Self.buildLimitedBookmarkRequest(ImagesBookmarkRecord.bookmarkAssociation)
                    .forKey(ImagesBookmarkTrackerResponse.CodingKeys.bookmark)
                    .including(
                      optional: Self.buildLimitedBookmarkRequest(BookmarkRecord.relativeAssociation)
                        .forKey(BookmarkTrackerResponse.CodingKeys.relative)
                    )
                )
            )
        )
        .asRequest(of: ImagesItemsTrackerResponse.self)
        .fetchOne(db)
    }
    
    return observation.values(in: connection, scheduling: .async(onQueue: .observation), bufferingPolicy: .bufferingNewest(4))
  }

  nonisolated public func track(propertiesForImages images: ImagesInfo) -> AsyncValueObservation<ImagesPropertiesTrackerResponse?> {
    let record = ImagesRecord.filter(key: images.rowID)
    let observation = ValueObservation.tracking(regions: [
      record.select(ImagesRecord.Columns.item)
    ]) { db in
      try record
        .select(Column.rowID)
        .including(
          required: ImagesRecord.itemAssociation
            .forKey(ImagesPropertiesTrackerResponse.CodingKeys.item)
            .select(Column.rowID, ImagesItemRecord.Columns.id)
        )
        .asRequest(of: ImagesPropertiesTrackerResponse.self)
        .fetchOne(db)
    }
    
    return observation.values(in: connection, scheduling: .async(onQueue: .observation), bufferingPolicy: .bufferingNewest(1))
  }

  nonisolated public func trackCopyings() -> AsyncValueObservation<[CopyingResponse]> {
    ValueObservation
      .tracking { db in
        try FolderRecord
          .select(Column.rowID, FolderRecord.Columns.id, FolderRecord.Columns.url)
          .including(
            required: Self.buildLimitedBookmarkRequest(FolderRecord.bookmarkAssociation)
              .forKey(FolderRecord.CodingKeys.bookmark)
          )
          .asRequest(of: CopyingResponse.self)
          .fetchAll(db)
      }
      .values(in: connection, scheduling: .async(onQueue: .observation), bufferingPolicy: .bufferingNewest(1))
  }

  // MARK: - Writing

  nonisolated public static func createSchema(_ connection: DatabaseConnection) async throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("v1") { db in
      try db.create(table: BookmarkRecord.databaseTableName) { table in
        table.primaryKey(Column.rowID.name, .integer)

        table
          .column(BookmarkRecord.Columns.data.name, .blob)
          .unique()
          .notNull()

        table
          .column(BookmarkRecord.Columns.options.name, .integer)
          .notNull()

        table
          .column(BookmarkRecord.Columns.hash.name, .blob)
          .unique()
          .notNull()

        table
          .column(BookmarkRecord.Columns.relative.name, .integer)
          .references(BookmarkRecord.databaseTableName)
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

      try db.create(table: ImagesImageRecord.databaseTableName) { table in
        table.primaryKey(Column.rowID.name, .integer)

        table
          .column(ImagesImageRecord.Columns.image.name, .integer)
          .notNull()
          .references(ImageRecord.databaseTableName)

        table
          .column(ImagesImageRecord.Columns.source.name, .text)
          .notNull()
      }

      try db.create(table: ImagesBookmarkRecord.databaseTableName) { table in
        table.primaryKey(Column.rowID.name, .integer)

        table
          .column(ImagesBookmarkRecord.Columns.bookmark.name, .integer)
          .notNull()
          .references(BookmarkRecord.databaseTableName)
      }

      try db.create(table: ImagesItemRecord.databaseTableName) { table in
        table.primaryKey(Column.rowID.name, .integer)

        table
          .column(ImagesItemRecord.Columns.id.name, .blob)
          .unique()
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
          .references(ImagesImageRecord.databaseTableName)

        table
          .column(ImagesItemRecord.Columns.bookmark.name, .integer)
          .references(ImagesBookmarkRecord.databaseTableName)
      }

      try db.create(table: ImagesRecord.databaseTableName) { table in
        table.primaryKey(Column.rowID.name, .integer)

        table
          .column(ImagesRecord.Columns.id.name, .blob)
          .notNull()
          .unique()

        table
          .column(ImagesRecord.Columns.item.name, .integer)
          .references(ImagesItemRecord.databaseTableName)
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
          .column(FolderRecord.Columns.id.name, .blob)
          .notNull()
          .unique()

        table
          .column(FolderRecord.Columns.bookmark.name, .integer)
          .notNull()
          .unique()
          .references(BookmarkRecord.databaseTableName)

        table
          .column(FolderRecord.Columns.url.name, .text)
          .notNull()
      }

      try db.execute(
        sql: """
        CREATE TRIGGER remove_orphaned_images_from_image_collection_images
        AFTER DELETE ON \(ImagesImageRecord.databaseTableName)
        BEGIN
          DELETE FROM \(ImageRecord.databaseTableName) WHERE \(ImageRecord.databaseTableName).\(Column.rowID.name) = OLD.\(ImagesImageRecord.Columns.image.name);
        END
        """
      )

      try db.execute(
        sql: """
        CREATE TRIGGER remove_orphaned_bookmarks_from_image_collection_bookmarks
        AFTER DELETE ON \(ImagesBookmarkRecord.databaseTableName)
        WHEN NOT EXISTS (SELECT 1 FROM \(FolderRecord.databaseTableName) WHERE \(FolderRecord.databaseTableName).\(FolderRecord.Columns.bookmark.name) = OLD.\(ImagesBookmarkRecord.Columns.bookmark.name))
        BEGIN
          DELETE FROM \(BookmarkRecord.databaseTableName)
          WHERE \(BookmarkRecord.databaseTableName).\(Column.rowID.name) = OLD.\(ImagesBookmarkRecord.Columns.bookmark.name);
        END
        """
      )

      try db.execute(
        sql: """
        CREATE TRIGGER remove_orphaned_bookmarks_from_folders
        AFTER DELETE ON \(FolderRecord.databaseTableName)
        WHEN NOT EXISTS (SELECT 1 FROM \(ImagesBookmarkRecord.databaseTableName) WHERE \(ImagesBookmarkRecord.databaseTableName).\(ImagesBookmarkRecord.Columns.bookmark.name) = OLD.\(FolderRecord.Columns.bookmark.name))
        BEGIN
          DELETE FROM \(BookmarkRecord.databaseTableName)
          WHERE \(BookmarkRecord.databaseTableName).\(Column.rowID.name) = OLD.\(FolderRecord.Columns.bookmark.name);
        END
        """
      )
    }

    #if DEBUG
    if try await connection.read(migrator.hasSchemaChanges) {
      try await connection.erase()
    }

    #endif

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

  nonisolated public static func id(
    _ db: Database,
    images id: UUID
  ) throws -> ImagesIDResponse {
    try ImagesRecord
      .select(Column.rowID, ImagesRecord.Columns.id)
      .filter(ImagesRecord.Columns.id == id)
      .asRequest(of: ImagesIDResponse.self)
      .fetchOne(db) ?? ImagesIDResponse(images: ImagesInfo(submitImages(db, images: id)))
  }

  nonisolated static func commit(_ db: Database, bookmark: BookmarkRecord) throws -> BookmarkRecord {
    var bookmark = bookmark

    // This upsert is redundant since bookmark is initialized without a rowid. The reason we're performing it
    // nevertheless is because it's the only query I'm aware of that performs an INSERT while returning rows regardless
    // of the conflict policy. If you insert(_:onConflict:) and SQLite raises, you don't get a rowid. How are you
    // supposed to know, then, which row caused the violation without querying its columns?
    //
    // This expression effectively translates to "insert this record, and if a row causes a violation, perform a
    // redundant update on said row while returning it; otherwise, return the inserted row."
    try bookmark.upsert(db)

    return bookmark
  }

  nonisolated static func createBookmark(
    _ db: Database,
    data: Data,
    options: URL.BookmarkCreationOptions,
    hash: Data,
    relative: RowID?
  ) throws -> BookmarkRecord {
    return try commit(db, bookmark: BookmarkRecord(data: data, options: options, hash: hash, relative: relative))
  }

  nonisolated static func createBookmark(_ db: Database, bookmark: Bookmark, relative: RowID?) throws -> BookmarkRecord {
    return try commit(db, bookmark: BookmarkRecord(bookmark: bookmark, relative: relative))
  }

  nonisolated public static func createBookmark(
    _ db: Database,
    data: Data,
    options: URL.BookmarkCreationOptions,
    hash: Data,
    relative: BookmarkInfo?
  ) throws -> BookmarkInfo {
    BookmarkInfo(record: try createBookmark(db, data: data, options: options, hash: hash, relative: relative?.rowID))
  }

  nonisolated public static func createBookmark(_ db: Database, bookmark: Bookmark, relative: BookmarkInfo?) throws -> BookmarkInfo {
    BookmarkInfo(record: try createBookmark(db, bookmark: bookmark, relative: relative?.rowID))
  }

  // TODO: Refactor.
  //
  // Creating a method for each column to update will get unwieldly real quick.
  nonisolated public static func saveImagesItem(
    _ db: Database,
    item: ImagesItemInfo,
    isBookmarked: Bool,
  ) throws {
    let item = ImagesItemRecord(
      rowID: item.rowID,
      id: nil,
      priority: nil,
      isBookmarked: isBookmarked,
      type: nil,
      image: nil,
    )

    try item.update(db, columns: [ImagesItemRecord.Columns.isBookmarked])
  }

  nonisolated static func createCopying(_ db: Database, id: UUID, bookmark: RowID, url: URL?) throws -> FolderRecord {
    var copying = FolderRecord(id: id, bookmark: bookmark, url: url)
    try copying.insert(db)

    return copying
  }

  nonisolated public static func createCopying(
    _ db: Database,
    id: UUID,
    bookmark: BookmarkInfo,
    url: URL?
  ) throws -> CopyingInfo {
    CopyingInfo(record: try createCopying(db, id: id, bookmark: bookmark.rowID, url: url))
  }

  nonisolated static func deleteCopying(_ db: Database, rowID: RowID) throws -> Bool {
    let copying = FolderRecord(rowID: rowID, id: nil, bookmark: nil, url: nil)

    return try copying.delete(db)
  }

  nonisolated public static func deleteCopying(_ db: Database, copying: CopyingInfo) throws -> Bool {
    try deleteCopying(db, rowID: copying.rowID)
  }

  nonisolated static func insertItemImages(
    _ db: Database,
    images: RowID,
    item: RowID,
  ) throws -> ItemImagesRecord {
    var itemImages = ItemImagesRecord(rowID: nil, images: images, item: item)
    try itemImages.insert(db)

    return itemImages
  }

  // MARK: - Old

  nonisolated static func submitImagesBookmark(_ db: Database, bookmark: RowID) throws -> ImagesBookmarkRecord {
    let bookmark = ImagesBookmarkRecord(bookmark: bookmark)

    return try bookmark.inserted(db)
  }

  nonisolated static func submitImagesItem(
    _ db: Database,
    id: UUID,
    priority: Int,
    isBookmarked: Bool,
    type: ImagesItemType,
    bookmark: RowID
  ) throws -> ImagesItemRecord {
    let image = ImagesItemRecord(
      id: id,
      priority: priority,
      isBookmarked: isBookmarked,
      type: type,
      bookmark: bookmark
    )

    return try image.inserted(db)
  }

  nonisolated static func submitImages(
    _ db: Database,
    images id: UUID
  ) throws -> ImagesRecord {
    var images = ImagesRecord(id: id, item: nil)
    try images.insert(db)

    return images
  }

  nonisolated static func submit(
    _ db: Database,
    id: UUID,
    priority: Int,
    isBookmarked: Bool,
    bookmark: RowID
  ) throws -> ImagesItemRecord {
    let bookmark = try submitImagesBookmark(db, bookmark: bookmark)
    let item = try submitImagesItem(
      db,
      id: id,
      priority: priority,
      isBookmarked: isBookmarked,
      type: .bookmark,
      bookmark: bookmark.rowID!
    )

    return item
  }

  nonisolated static func submit(
    _ db: Database,
    bookmark: Source<some RangeReplaceableCollection<Bookmark>>,
    images: RowID,
    priority: Int
  ) throws -> [(bookmark: BookmarkInfo, item: ImagesItemInfo?)] {
    var data: [(bookmark: BookmarkInfo, item: ImagesItemInfo?)]

    switch bookmark {
      case .source(let bookmark):
        let bookmark: BookmarkRecord = try Self.createBookmark(db, bookmark: bookmark, relative: nil)
        let item = try Self.submit(db, id: UUID(), priority: priority.incremented(), isBookmarked: false, bookmark: bookmark.rowID!)
        _ = try Self.insertItemImages(db, images: images, item: item.rowID!)

        data = [(bookmark: BookmarkInfo(record: bookmark), item: ImagesItemInfo(item: item))]
      case .document(let document):
        let bookmark: BookmarkRecord = try Self.createBookmark(db, bookmark: document.source, relative: nil)
        let values = try document.items.reduce(into: [(bookmark: BookmarkInfo, item: ImagesItemInfo?)]()) { partialResult, book in
          let bookmark = try Self.createBookmark(db, bookmark: book, relative: bookmark.rowID)
          let item = try Self.submit(
            db,
            id: UUID(),
            priority: (partialResult.last?.item?.priority ?? priority).incremented(),
            isBookmarked: false,
            bookmark: bookmark.rowID!
          )

          _ = try Self.insertItemImages(db, images: images, item: item.rowID!)

          partialResult.append((bookmark: BookmarkInfo(record: bookmark), item: ImagesItemInfo(item: item)))
        }

        data = Array(reservingCapacity: values.count.incremented())
        data.append((bookmark: BookmarkInfo(record: bookmark), item: nil))
        data.append(contentsOf: values)
    }

    return data
  }

  nonisolated public static func submit(
    _ db: Database,
    bookmark: Source<some RangeReplaceableCollection<Bookmark>>,
    images: ImagesInfo,
    priority: Int
  ) throws -> [(bookmark: BookmarkInfo, item: ImagesItemInfo?)] {
    try submit(db, bookmark: bookmark, images: images.rowID, priority: priority)
  }

  nonisolated public static func submit(_ db: Database, bookmark: BookmarkInfo, relative: BookmarkInfo?) throws {
    let bookmark = BookmarkRecord(
      rowID: bookmark.rowID,
      data: bookmark.data!,
      options: bookmark.options!,
      hash: bookmark.hash!,
      relative: relative?.rowID
    )

    try bookmark.update(db)
  }

  nonisolated public static func submit(
    _ db: Database,
    images: ImagesInfo,
    item: ImagesItemInfo?
  ) throws {
    let images = ImagesRecord(rowID: images.rowID, id: nil, item: item?.rowID)
    try images.update(db, columns: [ImagesRecord.Columns.item.name])
  }
}

extension DataStack: Sendable where Connection: Sendable {}
