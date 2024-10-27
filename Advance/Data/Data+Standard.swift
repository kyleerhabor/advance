//
//  Data+Standard.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/12/24.
//

import Foundation

extension URL {
  static let databaseFile = Self.dataDirectory
    .appending(component: "Data", directoryHint: .notDirectory)
    .appendingPathExtension("sqlite")
}
