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

extension Logger {
  static let data = Self(subsystem: Bundle.appID, category: "Data")
}

extension URL {
  static let databaseFile = Self.dataDirectory
    .appending(component: "Data", directoryHint: .notDirectory)
    .appendingPathExtension("sqlite")
}

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

    configuration.prepareDatabase { db in
      guard !db.configuration.readonly else {
        return
      }

      try db.execute(literal: "VACUUM")
    }

    return configuration
  }
}

let databaseConnection = Once {
  let url = URL.databaseFile
  let configuration = GRDB.Configuration.standard
  let connection: DatabasePool

  do {
    connection = try DatabasePool(path: url.pathString, configuration: configuration)
  } catch let error as DatabaseError where error.resultCode == .SQLITE_CANTOPEN {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    connection = try DatabasePool(path: url.pathString, configuration: configuration)
  }

  try await createSchema(connection: connection)

  return connection
}

enum DataStackDependencyKey: DependencyKey {
  typealias DataStack = AdvanceData.DataStack<DatabasePool>

  // TC
  static let liveValue: Once<DataStack> = Once {
    let connection = try await databaseConnection()

    return DataStack(connection: connection)
  }
}

extension DependencyValues {
  var dataStack: DataStackDependencyKey.Value {
    get { self[DataStackDependencyKey.self] }
    set { self[DataStackDependencyKey.self] = newValue }
  }
}
