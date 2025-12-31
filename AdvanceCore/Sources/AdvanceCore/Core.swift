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

public func unreachable() -> Never {
  fatalError("Reached supposedly unreachable code")
}

extension Bool {
  public var inverted: Self {
    !self
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

extension BinaryInteger {
  public func times(_ body: () -> Void) {
    for _ in stride(from: Self.zero, to: self, by: 1) {
      body()
    }
  }
}

extension Sequence {
  public func sum() -> Element where Element: AdditiveArithmetic {
    self.reduce(.zero, +)
  }

  public func filter(in set: some SetAlgebra<Element>) -> [Element] {
    self.filter { set.contains($0) }
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

public struct BidirectionalCollectionItem<C> where C: BidirectionalCollection {
  public let element: C.Element
  public let index: C.Index
}

extension BidirectionalCollection {
  func item(at index: Index) -> BidirectionalCollectionItem<Self> {
    BidirectionalCollectionItem(element: self[index], index: index)
  }

  func indexBefore(_ index: Index) -> Index? {
    guard index > self.startIndex else {
      return nil
    }

    return self.index(before: index)
  }

  func indexAfter(_ index: Index) -> Index? {
    guard index < self.endIndex else {
      return nil
    }

    return self.index(after: index)
  }

  public func before(index: Index) -> BidirectionalCollectionItem<Self>? {
    indexBefore(index).map { item(at: $0) }
  }

  public func after(index: Index) -> BidirectionalCollectionItem<Self>? {
    indexAfter(index).map { item(at: $0) }
  }
}

extension RangeReplaceableCollection {
  public init(reservingCapacity capacity: Int) {
    self.init()
    self.reserveCapacity(capacity)
  }
}

extension SetAlgebra {
  public func isNonEmptySubset(of other: Self) -> Bool {
    !self.isEmpty && self.isSubset(of: other)
  }
}

extension Bundle {
  public static let appID = Bundle.main.bundleIdentifier!
}

extension Logger {
  public static let sandbox = Self(subsystem: Bundle.appID, category: "Sandbox")
}

extension UTType {
  public static let jxl = Self(filenameExtension: "jxl", conformingTo: .image)!
}

extension URL {
  // $ getconf DARWIN_USER_TEMP_DIR
  public static let localTemporaryDirectory = Self(filePath: "/var/folders/", directoryHint: .isDirectory)

  public var pathString: String {
    self.path(percentEncoded: false)
  }

  public func title(extensionHidden: Bool) -> String {
    var url = self

    if !extensionHidden {
      url.deletePathExtension()
    }

    return url.lastPathComponent
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
  public func enumerate(
    at url: URL,
    resourceKeys: [URLResourceKey]? = nil,
    options: FileManager.DirectoryEnumerationOptions,
  ) throws(DirectoryEnumerationError) -> some Sequence<URL> {
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

    let iterator = CurrentValueIterator(TypedIterator<NSFastEnumerationIterator, URL>(enumerator.makeIterator()))

    if let error {
      throw .iterationFailed(error)
    }

    return iterator
  }

  public enum DirectoryEnumerationError: Error {
    case creationFailed, iterationFailed(any Error)
  }
}

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
  public func measure<T>(
//    isolation: isolated (any Actor)? = #isolation,
    _ body: () async throws -> T,
  ) async rethrows -> ClockMeasurement<T, Duration> {
    var value: T!
    let duration = try await self.measure {
      value = try await body()
    }

    let measurement = ClockMeasurement(value: value!, duration: duration)

    return measurement
  }
}

extension CGSize {
  public var length: Double {
    max(self.width, self.height)
  }
}

public struct Run<T, E> where E: Error {
  let continuation: CheckedContinuation<T, E>
  let body: @Sendable () async throws(E) -> T

  public init(continuation: CheckedContinuation<T, E>, _ body: @Sendable @escaping () async throws(E) -> T) {
    self.continuation = continuation
    self.body = body
  }

  func run() async {
    let value: T

    do {
      value = try await body()
    } catch {
      continuation.resume(throwing: error)

      return
    }

    continuation.resume(returning: value)
  }
}

extension Run: Sendable {}

public func run<T, E, Base>(base: Base, count: Int) async throws where Base: AsyncSequence,
                                                                       Base.Element == Run<T, E>,
                                                                       E: Error {
  try await withThrowingTaskGroup { group in
    for try await element in base.prefix(count) {
      group.addTask {
        await element.run()
      }
    }

    var iterator = base.makeAsyncIterator()

    for try await _ in group {
      guard let element = try await iterator.next() else {
        return
      }

      group.addTask {
        await element.run()
      }
    }
  }
}
