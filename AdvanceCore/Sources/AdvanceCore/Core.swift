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

public func noop<each Argument>(_ args: repeat each Argument) {}

public func constantly<Value, each Argument>(_ value: Value) -> (repeat each Argument) -> Value {
  func result<each Arg>(_ args: repeat each Arg) -> Value {
    value
  }

  return result
}

public func applying<Value, each Argument>(_ args: repeat each Argument) -> ((repeat each Argument) -> Value) -> Value {
  { f in
    f(repeat each args)
  }
}
extension Numeric {
  public func incremented() -> Self {
    self + 1
  }

  public func decremented() -> Self {
    self - 1
  }
}

extension Sequence {
  public func sum() -> Element where Element: AdditiveArithmetic {
    self.reduce(.zero, +)
  }

  public func filter<T>(in set: some SetAlgebra<T>, by transform: (Element) -> T) -> [Element] {
    self.filter { set.contains(transform($0)) }
  }

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

extension Collection {
  public subscript(safe index: Index) -> Element? {
    // I believe, internally, Swift represents indicies as a Range collection with two elements (the start index and
    // end index). Consequently, this should not be slow.
    guard self.indices.contains(index) else {
      return nil
    }

    return self[index]
  }
}

extension Collection where Index: FixedWidthInteger {
  var middleIndex: Index {
    let start = self.startIndex
    let end = self.endIndex
    let distance = end - start // No one mandated indexes start at zero!
    let middle = start + (distance / 2)

    return middle
  }

  var middle: Element? {
    if self.isEmpty {
      return nil
    }

    return self[middleIndex]
  }
}

extension BidirectionalCollection {
  // The index is valid for any non-empty collection.
  public var lastIndex: Index {
    self.index(before: self.endIndex)
  }
}

extension RangeReplaceableCollection {
  public init(reservingCapacity capacity: Int) {
    self.init()
    self.reserveCapacity(capacity)
  }
}

extension Bundle {
  public static let appID = Bundle.main.bundleIdentifier!
}

extension Logger {
  public static let sandbox = Self(subsystem: Bundle.appID, category: "Sandbox")
  public static let data = Self(subsystem: Bundle.appID, category: "Data")
}

extension UTType {
  public static let jxl = Self(filenameExtension: "jxl", conformingTo: .image)!
}

extension URL {
  public var pathString: String {
    self.path(percentEncoded: false)
  }
}

public struct TypedIterator<Base, T>: IteratorProtocol where Base: IteratorProtocol {
  private var base: Base

  public init(_ base: Base) {
    self.base = base
  }

  public mutating func next() -> T? {
    base.next() as? T
  }
}

extension TypedIterator: Sequence {}

public struct CurrentValueIterator<Base>: IteratorProtocol where Base: IteratorProtocol {
  private var base: Base
  private var value: Element?

  public init(_ base: Base, value: Element?) {
    self.base = base
    self.value = value
  }

  public init(_ base: Base) {
    self.base = base
    self.value = self.base.next()
  }

  public mutating func next() -> Base.Element? {
    let next = base.next()
    let value = value
    self.value = next

    return value
  }
}

extension CurrentValueIterator: Sequence {}

extension FileManager {
  public typealias DirectoryEnumerationIterator = CurrentValueIterator<TypedIterator<NSFastEnumerationIterator, URL>>

  public func enumerate(
    at url: URL,
    resourceKeys: [URLResourceKey]? = nil,
    options: FileManager.DirectoryEnumerationOptions
  ) throws -> DirectoryEnumerationIterator {
    var error: (any Error)?
    let enumerator = self.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: options) { eurl, err in
      // We only care about the error on the initial enumeration (for example, the URL doesn't point to a directory).
      if eurl == url {
        error = err
      }

      return true
    }

    guard let enumerator else {
      throw DirectoryEnumerationError.creationFailed
    }

    let iterator: DirectoryEnumerationIterator = CurrentValueIterator(TypedIterator(enumerator.makeIterator()))

    if let error {
      throw error
    }

    return iterator
  }

  public enum DirectoryEnumerationError: Error {
    case creationFailed
  }
}

// TODO: Modify.
//
// "Source" and "document" in a generic context is highly confusing.
public struct SourceDocument<Items> where Items: RangeReplaceableCollection {
  public let source: Items.Element
  public let items: Items

  public init(source: Items.Element, items: Items) {
    self.source = source
    self.items = items
  }
}

extension SourceDocument: Sendable where Items: Sendable,
                                         Items.Element: Sendable {}

public enum Source<Items> where Items: RangeReplaceableCollection {
  case source(Items.Element), document(SourceDocument<Items>)

  public var sources: Items {
    switch self {
      case .source(let item):
        var items = Items(reservingCapacity: 1)
        items.append(item)

        return items
      case .document(let document):
        return document.items
    }
  }

  public var items: Items {
    switch self {
      case .source(let item):
        var items = Items(reservingCapacity: 1)
        items.append(item)

        return items
      case .document(let document):
        var items = Items(reservingCapacity: document.items.count.incremented())
        items.append(document.source)
        items.append(contentsOf: document.items)

        return items
    }
  }
}

extension Source: Sendable where Items: Sendable,
                                 Items.Element: Sendable {}

// Ideally, we'd use a function for this; but because Swift loves typing everything, using parameter packs effectively
// makes it impossible.
public actor Once<Value, each Argument> where Value: Sendable,
                                              repeat each Argument: Sendable {
  public typealias Producer = (repeat each Argument) async throws -> Value

  private let producer: Producer

  private var task: Task<Value, any Error>?

  public init(producer: @escaping Producer) {
    self.producer = producer
  }

  public func callAsFunction(_ args: repeat each Argument) async throws -> Value {
    if let task {
      return try await task.value
    }

    let task = Task {
      try await producer(repeat each args)
    }

    self.task = task

    do {
      return try await task.value
    } catch {
      // We didn't get a value, try again on the next invocation
      self.task = nil

      throw error
    }
  }
}

public struct Runner<T, E>: Sendable where E: Error {
  public typealias Run = @Sendable () async throws(E) -> T

  public let run: Run
  public let continuation: CheckedContinuation<T, E>

  public func execute() async {
    do {
      continuation.resume(returning: try await run())
    } catch {
      continuation.resume(throwing: error)
    }
  }
}

extension Runner {
  public init(continuation: CheckedContinuation<T, E>, _ run: @escaping Run) {
    self.init(run: run, continuation: continuation)
  }
}

public func run<L, T, E, S>(limit: L, iterator: inout S) async throws where L: AdditiveArithmetic & Strideable,
                                                                            S: AsyncIteratorProtocol,
                                                                            S.Element == Runner<T, E>,
                                                                            E: Error {
  try await withThrowingTaskGroup(of: Void.self) { group in
    for _ in stride(from: L.zero, to: limit, by: 1) {
      guard let runner = try await iterator.next() else {
        return
      }

      group.addTask {
        await runner.execute()
      }
    }

    while try await group.next() != nil,
          let runner = try await iterator.next() {
      group.addTask {
        await runner.execute()
      }
    }
  }
}

public func run<T>(
  in runGroup: AsyncStream<Runner<T, Never>>.Continuation,
  _ body: @escaping Runner<T, Never>.Run
) async -> T {
  await withCheckedContinuation { continuation in
    runGroup.yield(Runner(continuation: continuation, body))
  }
}

public func run<T>(
  in runGroup: AsyncStream<Runner<T, any Error>>.Continuation,
  _ body: @escaping Runner<T, any Error>.Run
) async throws -> T {
  try await withCheckedThrowingContinuation { continuation in
    runGroup.yield(Runner(continuation: continuation, body))
  }
}

public struct ClockMeasurement<T, D> where D: DurationProtocol {
  public let value: T
  public let duration: D
}

extension Clock {
  // This should only be used for very basic diagnostics since Instruments is more informative.
  public func time<T>(
    _ body: @isolated(any) () async throws -> T
  ) async rethrows -> ClockMeasurement<T, Duration> where T: Sendable {
    var value: T!
    let duration = try await self.measure {
      value = try await body()
    }

    return ClockMeasurement(value: value, duration: duration)
  }
}

extension Data {
  public func hexEncodedString() -> String {
    self.reduce("") { partialResult, byte in
      partialResult + String(format: "%02hhx", byte)
    }
  }
}

extension CGImagePropertyOrientation {
  public var isReflected: Bool {
    switch self {
      case .leftMirrored, .right, .rightMirrored, .left: true
      default: false
    }
  }
}

extension Actor {
  public func isolated<T, Failure>(
    _ body: @Sendable (isolated Self) throws(Failure) -> T
  ) throws(Failure) -> T {
    try body(self)
  }
}
