//
//  Data+Core.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/12/24.
//

import Foundation
import GRDB
import OSLog

extension Logger {
  static let data = Self(subsystem: Bundle.appID, category: "Data")
}

extension URL {
  static let databaseFile = Self.dataDirectory
    .appending(components: "Database", "Data", directoryHint: .notDirectory)
    .appendingPathExtension("sqlite3")
}

actor Once<Success, Failure, each Argument> where Failure: Error {
  private let body: (repeat each Argument) throws(Failure) -> Success
  private var value: Success?

  init(body: @escaping (repeat each Argument) throws(Failure) -> Success) {
    self.body = body
  }

  func callAsFunction(_ args: repeat each Argument) throws(Failure) -> Success {
    if let value {
      return value
    }

    let value = try self.body(repeat each args)
    self.value = value

    return value
  }
}

func createFileBookmarkSchemaAction(_ db: Database) throws {
  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(FileBookmarkRecord.databaseTableName)_ad".quotedDatabaseIdentifier)
      AFTER DELETE ON \(FileBookmarkRecord.self)
      FOR EACH ROW
      BEGIN
        DELETE FROM \(BookmarkRecord.self)
        WHERE \(BookmarkRecord.self).\(.rowID) = OLD.\(FileBookmarkRecord.Columns.bookmark);
      END
      """,
  )
}

func createImagesItemSchemaAction(_ db: Database) throws {
  let when: SQL = """
    SELECT 1
    FROM \(FileBookmarkRecord.self)
    LEFT JOIN \(ImagesItemRecord.self)
      ON \(ImagesItemRecord.self).\(ImagesItemRecord.Columns.fileBookmark) = \(FileBookmarkRecord.self).\(.rowID)
    LEFT JOIN \(FolderRecord.self)
      ON \(FolderRecord.self).\(FolderRecord.Columns.fileBookmark) = \(FileBookmarkRecord.self).\(.rowID)
    WHERE \(FileBookmarkRecord.self).\(.rowID) = OLD.\(ImagesItemRecord.Columns.fileBookmark)
      AND \(ImagesItemRecord.self).\(.rowID) IS NULL
      AND \(FolderRecord.self).\(.rowID) IS NULL
    """

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(ImagesItemRecord.databaseTableName)_ad".quotedDatabaseIdentifier)
      AFTER DELETE ON \(ImagesItemRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        DELETE FROM \(FileBookmarkRecord.self)
        WHERE \(FileBookmarkRecord.self).\(.rowID) = OLD.\(ImagesItemRecord.Columns.fileBookmark);
      END
      """,
  )
}

func createImagesItemPositionSchemaCheck(_ db: Database) throws {
  let name = "\(ItemImagesRecord.databaseTableName).\(ItemImagesRecord.Columns.item.name).\(ImagesItemRecord.Columns.position.name)"
  let message = "(\(ItemImagesRecord.databaseTableName).\(ItemImagesRecord.Columns.images.name), \(name)) must be unique"
  let when: SQL = """
    SELECT 1
    FROM \(ImagesItemRecord.self)
    LEFT JOIN \(ItemImagesRecord.self) other
      ON other.\(.rowID) != NEW.\(.rowID)
    LEFT JOIN \(ImagesItemRecord.self) other_images_item
      ON other_images_item.\(.rowID) = other.\(ItemImagesRecord.Columns.item)
    WHERE \(ImagesItemRecord.self).\(.rowID) = NEW.\(ItemImagesRecord.Columns.item)
      AND other.\(ItemImagesRecord.Columns.images) = NEW.\(ItemImagesRecord.Columns.images)
      AND \(ImagesItemRecord.self).\(ImagesItemRecord.Columns.position) = other_images_item.\(ImagesItemRecord.Columns.position)
    """

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(name)_ai".quotedDatabaseIdentifier)
      AFTER INSERT ON \(ItemImagesRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        SELECT RAISE(ABORT, \(sql: message.quotedDatabaseIdentifier));
      END
      """,
  )

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(name)_au".quotedDatabaseIdentifier)
      AFTER UPDATE ON \(ItemImagesRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        SELECT RAISE(ABORT, \(sql: message.quotedDatabaseIdentifier));
      END
      """,
  )
}

func createImagesItemFileBookmarkSchemaCheck(_ db: Database) throws {
  let name = "\(ItemImagesRecord.databaseTableName).\(ItemImagesRecord.Columns.item.name).\(ImagesItemRecord.Columns.fileBookmark.name)"
  let message = "(\(ItemImagesRecord.databaseTableName).\(ItemImagesRecord.Columns.images.name), \(name)) must be unique"
  let when: SQL = """
    SELECT 1
    FROM \(ImagesItemRecord.self)
    LEFT JOIN \(ItemImagesRecord.self) other
      ON other.\(.rowID) != NEW.\(.rowID)
    LEFT JOIN \(ImagesItemRecord.self) other_images_item
      ON other_images_item.\(.rowID) = other.\(ItemImagesRecord.Columns.item)
    WHERE \(ImagesItemRecord.self).\(.rowID) = NEW.\(ItemImagesRecord.Columns.item)
      AND other.\(ItemImagesRecord.Columns.images) = NEW.\(ItemImagesRecord.Columns.images)
      AND \(ImagesItemRecord.self).\(ImagesItemRecord.Columns.fileBookmark) = other_images_item.\(ImagesItemRecord.Columns.fileBookmark)
    """

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(name)_ai".quotedDatabaseIdentifier)
      AFTER INSERT ON \(ItemImagesRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        SELECT RAISE(ABORT, \(sql: message.quotedDatabaseIdentifier));
      END
      """,
  )

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(name)_au".quotedDatabaseIdentifier)
      AFTER UPDATE ON \(ItemImagesRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        SELECT RAISE(ABORT, \(sql: message.quotedDatabaseIdentifier));
      END
      """,
  )
}

func createFolderPathComponentPositionSchemaCheck(_ db: Database) throws {
  let name = "\(PathComponentFolderRecord.databaseTableName).\(PathComponentFolderRecord.Columns.pathComponent.name).\(FolderPathComponentRecord.Columns.position.name)"
  let message = "(\(PathComponentFolderRecord.databaseTableName).\(PathComponentFolderRecord.Columns.folder.name), \(name)) must be unique"
  let when: SQL = """
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

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(name)_ai".quotedDatabaseIdentifier)
      AFTER INSERT ON \(PathComponentFolderRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        SELECT RAISE(ABORT, \(sql: message.quotedDatabaseIdentifier));
      END
      """,
  )

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(name)_au".quotedDatabaseIdentifier)
      AFTER UPDATE ON \(PathComponentFolderRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        SELECT RAISE(ABORT, \(sql: message.quotedDatabaseIdentifier));
      END
      """,
  )
}

func createFolderPathComponentSchemaAction(_ db: Database) throws {
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

func createFolderSchemaAction(_ db: Database) throws {
  // A folder's file bookmark is unique, so we don't need to check it.
  let when: SQL = """
    SELECT 1
    FROM \(FileBookmarkRecord.self)
    LEFT JOIN \(ImagesItemRecord.self)
      ON \(ImagesItemRecord.self).\(ImagesItemRecord.Columns.fileBookmark) = \(FileBookmarkRecord.self).\(.rowID)
    WHERE \(FileBookmarkRecord.self).\(.rowID) = OLD.\(FolderRecord.Columns.fileBookmark)
      AND \(ImagesItemRecord.self).\(.rowID) IS NULL    
    """

  try db.execute(
    literal: """
      CREATE TRIGGER \(sql: "\(FolderRecord.databaseTableName)_ad".quotedDatabaseIdentifier)
      AFTER DELETE ON \(FolderRecord.self)
      FOR EACH ROW WHEN (\(when))
      BEGIN
        DELETE FROM \(FileBookmarkRecord.self)
        WHERE \(FileBookmarkRecord.self).\(.rowID) = OLD.\(FolderRecord.Columns.fileBookmark);
      END
      """,
  )
}

func createSchema(connection: some DatabaseWriter) throws {
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

    try createFileBookmarkSchemaAction(db)
    try db.create(table: ImagesItemRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ImagesItemRecord.Columns.fileBookmark.name, .integer)
        .notNull()
        .references(FileBookmarkRecord.databaseTableName)
        .indexed()

      table
        .column(ImagesItemRecord.Columns.position.name, .text)
        .notNull()

      // If we were to add more boolean columns in the future, it'd probably make more sense to use an option set.
      table
        .column(ImagesItemRecord.Columns.isBookmarked.name, .boolean)
        .notNull()
    }

    try createImagesItemSchemaAction(db)
    try db.create(table: ImagesRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(ImagesRecord.Columns.id.name, .blob)
        .notNull()
        .unique()

      // TODO: Ensure uniqueness.
      table
        .column(ImagesRecord.Columns.currentItem.name, .integer)
        .references(ImagesItemRecord.databaseTableName, onDelete: .setNull)
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
        .references(ImagesItemRecord.databaseTableName, onDelete: .cascade)
    }

    try createImagesItemPositionSchemaCheck(db)
    try createImagesItemFileBookmarkSchemaCheck(db)
    try db.create(table: FolderPathComponentRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      // We could de-duplicate this, but the table only exists so we don't have to encode an array of strings manually.
      // That is, if encoding wasn't a concern, we'd have duplication, regardless.
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
        .references(FileBookmarkRecord.databaseTableName)
    }

    try createFolderSchemaAction(db)
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

    try createFolderPathComponentPositionSchemaCheck(db)
    try createFolderPathComponentSchemaAction(db)
    try db.create(table: SearchEngineRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)
      table
        .column(SearchEngineRecord.Columns.name.name, .text)
        .notNull()
        .unique()

      table
        .column(SearchEngineRecord.Columns.location.name, .text)
        .notNull()

      table
        .column(SearchEngineRecord.Columns.position.name, .text)
        .notNull()
        .unique()
    }

    try db.create(table: ConfigurationRecord.databaseTableName) { table in
      table
        .primaryKey(Column.rowID.name, .integer)
        .check { $0 == ConfigurationRecord.default.rowID }

      table
        .column(ConfigurationRecord.Columns.searchEngine.name, .integer)
        .references(SearchEngineRecord.databaseTableName, onDelete: .setNull)
        .indexed()
    }
  }

  try migrator.migrate(connection)
}


extension GRDB.Configuration {
  static var standard: Self {
    var configuration = Self()

    #if DEBUG
    configuration.publicStatementArguments = true

    #endif

    configuration.prepareDatabase { db in
      #if DEBUG
      db.trace(options: .profile) { trace in
        Logger.data.debug("SQL> \(trace)")
      }

      #endif

      guard !db.configuration.readonly else {
        return
      }

      // This will execute twice: once for creating the database connection, and another for schema migration.
      try db.execute(literal: "VACUUM")
    }

    return configuration
  }
}

func createDatabaseConnection(at url: URL, configuration: GRDB.Configuration) throws -> DatabasePool {
  let path = url.pathString

  do {
    return try DatabasePool(path: path, configuration: configuration)
  } catch let error as DatabaseError where error.resultCode == .SQLITE_CANTOPEN {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    return try DatabasePool(path: path, configuration: configuration)
  }
}

let databaseConnection = Once {
  let url = URL.databaseFile
  let configuration = GRDB.Configuration.standard
  let connection = try createDatabaseConnection(at: url, configuration: configuration)
  try createSchema(connection: connection)

  return connection
}
