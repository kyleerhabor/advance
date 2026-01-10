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

actor Once<Value, each Argument> where Value: Sendable {
  private let body: (repeat each Argument) async throws -> Value
  private var task: Task<Value, any Error>?

  init(_ body: @escaping (repeat each Argument) async throws -> Value) {
    self.body = body
  }

  func callAsFunction(_ args: repeat each Argument) async throws -> Value {
    if let task = self.task {
      return try await task.value
    }

    let task = Task {
      try await self.body(repeat each args)
    }

    self.task = task

    do {
      return try await task.value
    } catch {
      // We didn't get a value, so we can try again on the next call.
      self.task = nil

      throw error
    }
  }
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

    try db.create(table: ImagesItemRecord.databaseTableName) { table in
      table.primaryKey(Column.rowID.name, .integer)

      // TODO: Enforce uniqueness via trigger.
      table
        .column(ImagesItemRecord.Columns.position.name, .text)
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

      try db.execute(literal: "VACUUM")
    }

    return configuration
  }
}

func createDatabaseConnection(at url: URL, configuration: GRDB.Configuration) throws -> DatabasePool {
  do {
    return try DatabasePool(path: url.pathString, configuration: configuration)
  } catch let error as DatabaseError where error.resultCode == .SQLITE_CANTOPEN {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    return try DatabasePool(path: url.pathString, configuration: configuration)
  }
}

let databaseConnection = Once {
  let url = URL.databaseFile
  let configuration = GRDB.Configuration.standard
  let connection = try createDatabaseConnection(at: url, configuration: configuration)
  try createSchema(connection: connection)

  return connection
}
