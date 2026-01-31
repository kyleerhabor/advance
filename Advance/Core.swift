//
//  Core.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/31/25.
//

import BigInt
import Foundation

// MARK: - Swift

func unreachable() -> Never {
  fatalError("Reached supposedly unreachable code")
}

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

extension Bool {
  var inverted: Self {
    !self
  }
}

extension Sequence {
  func filter<T>(in set: some SetAlgebra<T>, by transform: (Element) -> T) -> [Element] {
    self.filter { set.contains(transform($0)) }
  }

  func sum() -> Element where Element: AdditiveArithmetic {
    self.reduce(.zero, +)
  }
}

extension Collection {
  func subscriptIndex(after index: Index) -> Index? {
    guard index < self.endIndex else {
      return nil
    }

    let index = self.index(after: index)

    guard index != self.endIndex else {
      return nil
    }

    return index
  }
}

extension Collection where Index: FixedWidthInteger {
  // This is obviously invalid for discontiguous collections.
  var middleIndex: Index {
    let start = self.startIndex
    let end = self.endIndex
    let middle = start + ((end - start) / 2)

    return middle
  }

  var middleItem: Element? {
    let index = self.middleIndex

    guard index != self.endIndex else {
      return nil
    }

    return self[index]
  }
}

extension BidirectionalCollection {
  func subscriptIndex(before index: Index) -> Index? {
    guard index > self.startIndex else {
      return nil
    }
    
    return self.index(before: index)
  }
}

extension RangeReplaceableCollection {
  init(reservingCapacity capacity: Int) {
    self.init()
    self.reserveCapacity(capacity)
  }
}

extension SetAlgebra {
  func isNonEmptySubset(of other: Self) -> Bool {
    !self.isEmpty && self.isSubset(of: other)
  }
}

// MARK: - Swift Concurrency

// In some settings, calling a synchronous function from an asynchronous one can block the underlying cooperative thread,
// deadlocking the system when all cooperative threads are blocked (e.g., calling URL/bookmarkData(options:includingResourceValuesForKeys:relativeTo:)
// from a task group). I presume this is caused by a function:
//
//   1. Not being preconcurrency
//   2. Being I/O bound
//   3. Blocking a cooperative thread
//
// The solution, then, is to not block cooperative threads.
//
// See https://forums.swift.org/t/cooperative-pool-deadlock-when-calling-into-an-opaque-subsystem/70685
func schedule<T>(on queue: DispatchQueue, _ body: @Sendable @escaping () throws -> T) async throws -> T {
  try await withCheckedThrowingContinuation { continuation in
    queue.async {
      do {
        continuation.resume(returning: try body())
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}

extension DispatchQueue {
  static let bookmark = DispatchQueue(label: "\(Bundle.appID).Bookmark", target: .global())
}

// MARK: - Foundation

extension URL {
  // $ getconf DARWIN_USER_TEMP_DIR
  static let localTemporaryDirectory = Self(filePath: "/var/folders", directoryHint: .isDirectory)
  static let dataDirectory = Self.applicationSupportDirectory.appending(
    components: Bundle.appID,
    directoryHint: .isDirectory,
  )

  var pathString: String {
    self.path(percentEncoded: false)
  }

  var debugString: String {
    let absoluteString = self.absoluteString
    let string = absoluteString.removingPercentEncoding ?? absoluteString

    return string
  }
}

extension Bundle {
  static let appID = Bundle.main.bundleIdentifier!
}

// MARK: - Core Graphics

extension CGSize {
  func scale(width: Double) -> Self {
    Self(width: width, height: width * (self.height / self.width))
  }
}

// MARK: - BigInt

extension BInt {
  func digitCount(base: Self) -> Int {
    var n = self
    var count = 1

    while n >= base {
      guard n % base == Self.ZERO else {
        break
      }

      n /= base
      count += 1
    }

    return count
  }
}

