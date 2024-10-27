//
//  Data+Core.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/12/24.
//

import AdvanceCore
import AdvanceData
import Dependencies
import Foundation
import GRDB
import OSLog

extension GRDB.Configuration {
  static var standard: Self {
    var configuration = Self()

    #if DEBUG
    configuration.publicStatementArguments = true
    configuration.prepareDatabase { db in
      db.trace(options: .profile) { trace in
        Logger.data.debug("SQL> \(trace)")
      }
    }

    #endif

    return configuration
  }
}

func retry<T>(
  body: () throws -> T,
  retry: (DatabaseError) -> Bool,
  recover: () throws -> Void
) throws -> T {
  do {
    return try body()
  } catch let error as DatabaseError where retry(error) {
    try recover()

    return try body()
  }
}

func retry<T>(
  on code: ResultCode,
  body: () throws -> T,
  recovery recover: () throws -> Void
) throws -> T {
  try retry(body: body) { error in
    error.resultCode == code
  } recover: {
    try recover()
  }
}

enum DataStackDependencyKey: DependencyKey {
  typealias DataStack = AdvanceData.DataStack<DatabasePool>

  // TC
  static let liveValue: Once<DataStack> = Once {
    // Should we use a separate file during development?
    let url = URL.databaseFile
    let configuration = GRDB.Configuration.standard
    let connection = try retry(on: .SQLITE_CANTOPEN) {
      try DatabasePool(path: url.pathString, configuration: configuration)
    } recovery: {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    let dataStack = DataStack(connection: connection)

    // This step should probably be made explicit by the caller.

    let context = try await dataStack.connection.write { db in
      var context = CreateSchemaContext()
      try DataStack.createSchema(db, context: &context)

      return context
    }

    #if DEBUG
    if context.modifiedEntry {
      Logger.data.info("Schema for connection was modified; erasing and recreating...")

      try await dataStack.connection.erase()
      try await dataStack.connection.write { db in
        var context = CreateSchemaContext()

        try DataStack.createSchema(db, context: &context)
      }
    }

    #endif

    return dataStack
  }
}

extension DependencyValues {
  var dataStack: DataStackDependencyKey.Value {
    get { self[DataStackDependencyKey.self] }
    set { self[DataStackDependencyKey.self] = newValue }
  }
}
