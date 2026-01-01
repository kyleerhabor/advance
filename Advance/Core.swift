//
//  Core.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/31/25.
//

import Foundation

// MARK: - Swift

// https://www.swiftbysundell.com/articles/the-power-of-key-paths-in-swift/
func setter<Object, Value>(
  on keyPath: WritableKeyPath<Object, Value>,
  value: Value,
) -> (inout Object) -> Void {
  { object in
    object[keyPath: keyPath] = value
  }
}

func setter<Object: AnyObject, Value>(
  on keyPath: ReferenceWritableKeyPath<Object, Value>,
  value: Value,
) -> (Object) -> Void {
  { object in
    object[keyPath: keyPath] = value
  }
}

// MARK: - Foundation

extension URL {
  #if DEBUG
  static let dataDirectory = Self.applicationSupportDirectory.appending(
    components: Bundle.appID, "DebugData",
    directoryHint: .isDirectory,
  )

  #else
  static let dataDirectory = Self.applicationSupportDirectory.appending(
    components: Bundle.appID, "Data",
    directoryHint: .isDirectory,
  )

  #endif
}
