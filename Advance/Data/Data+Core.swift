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

enum DataStackDependencyKey: DependencyKey {
  typealias DataStack = AdvanceData.DataStack<DatabasePool>

  // TC
  static let liveValue: Once<DataStack> = Once {
    // Should we use a separate file during development?
    let url = URL.databaseFile
    let configuration = GRDB.Configuration.standard
    let connection: DatabasePool

    do {
      connection = try DatabasePool(path: url.pathString, configuration: configuration)
    } catch let error as DatabaseError where error.resultCode == .SQLITE_CANTOPEN {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

      connection = try DatabasePool(path: url.pathString, configuration: configuration)
    }

    let dataStack = DataStack(connection: connection)
    try await DataStack.createSchema(dataStack.connection)

    return dataStack
  }
}

extension DependencyValues {
  var dataStack: DataStackDependencyKey.Value {
    get { self[DataStackDependencyKey.self] }
    set { self[DataStackDependencyKey.self] = newValue }
  }
}
