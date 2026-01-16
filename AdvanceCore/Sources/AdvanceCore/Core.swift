//
//  File.swift
//  
//
//  Created by Kyle Erhabor on 6/10/24.
//

import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

public func identity<T>(_ value: T) -> T {
  value
}

public func constantly<Value, each Argument>(_ value: Value) -> (repeat each Argument) -> Value {
  func result<each Arg>(_ args: repeat each Arg) -> Value {
    value
  }

  return result
}

extension Numeric {
  public static var one: Self { 1 }

  public func incremented() -> Self {
    self + Self.one
  }

  public func decremented() -> Self {
    self - Self.one
  }
}

extension Sequence {
  public func finderSort(
    by transform: (Element) throws -> [String],
    _ predicate: (String, String) -> Bool
  ) rethrows -> [Element] {
    try self.sorted { a, b in
      let ap = try transform(a)
      let bp = try transform(b)

      // First, we need to find a and b's common directory, then compare which one is a file or directory (since Finder
      // sorts folders first). Finally, if they're the same type, we do a localized standard comparison (the same Finder
      // applies when sorting by name) to sort by ascending order.
      let tags = zip(ap, bp).enumerated()
      let (index, (ac, bc)) = tags.first { _, pair in
        pair.0 != pair.1
      } ?? Array(tags).last!

      let count = index.incremented()

      if ap.count > count && bp.count == count {
        return true
      }

      if ap.count == count && bp.count > count {
        return false
      }

      return predicate(ac, bc)
    }
  }

  public func finderSort(by transform: (Element) throws -> [String]) rethrows -> [Element] {
    try finderSort(by: transform) { a, b in
      a.localizedStandardCompare(b) == .orderedAscending
    }
  }
}

extension UTType {
  public static let jxl = Self(filenameExtension: "jxl", conformingTo: .image)!
}
