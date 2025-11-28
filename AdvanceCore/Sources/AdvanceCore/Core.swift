//
//  File.swift
//  
//
//  Created by Kyle Erhabor on 6/10/24.
//

@preconcurrency import BigInt
import Combine
import Foundation
import ImageIO
import OSLog
import UniformTypeIdentifiers

//public typealias SubjectPublisher<Output, Error> = Subject<Output, Error> & Publisher<Output, Error>

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

extension BInt {
  // https://stackoverflow.com/a/63538016/14695788
  public var size: BInt {
    var n = self
    var count = BInt.ZERO

    while n > 1 {
      if n % 10 != 0 {
        break
      }

      n /= 10
      count += 1
    }

    return count
  }
}

public struct BigFraction {
  public static let zero = Self(BInt.ZERO, BInt.ONE)
  public static let one = Self(BInt.ONE, BInt.ONE)

  public var numerator: BInt
  public var denominator: BInt

  public var isNegative: Bool {
    return self.numerator.isNegative
  }

  public var isZero: Bool {
    return self.numerator.isZero
  }

  public var simplified: Self {
    let g = self.numerator.gcd(self.denominator)
    var f = Self(
      self.numerator.quotientExact(dividingBy: g),
      self.denominator.quotientExact(dividingBy: g),
    )

    if f.denominator.isNegative {
      f.denominator.negate()
      f.numerator.negate()
    }

    return f
  }

  public init(_ n: BInt, _ d: BInt) {
    precondition(d.isNotZero)
    self.numerator = n
    self.denominator = d
  }

  public init?(_ x: String) {
    guard let (m, e) = Self.parseString(x) else {
      return nil
    }
    if e < 0 {
      self.init(m, BInt.TEN ** -e)
    } else {
      self.init(m * (BInt.TEN ** e), BInt.ONE)
    }
  }

  public func asString() -> String {
    return self.numerator.asString() + "/" + self.denominator.asString()
  }

  public func asDecimalString(precision: Int, exponential: Bool = false) -> String {
    precondition(precision > 0)
    if self.isZero {
      return Self.displayString(BInt.ZERO, -precision, exponential)
    }
    let P = BInt.TEN ** precision
    var exp = 0
    var q = self.numerator.abs
    while q.quotientAndRemainder(dividingBy: self.denominator).quotient < P {
      q *= BInt.TEN
      exp -= 1
    }
    while q.quotientAndRemainder(dividingBy: self.denominator).quotient >= P {
      q /= BInt.TEN
      exp += 1
    }
    let x = q.quotientAndRemainder(dividingBy: self.denominator).quotient
    return Self.displayString(self.isNegative ? -x : x, exp, exponential)
  }

  public func asDouble() -> Double {
    var (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
    var d = q.asDouble()
    if !d.isInfinite {
      var pow10 = 1.0
      for _ in 0 ..< 18 {
        r *= 10
        pow10 *= 10.0
        (q, r) = r.quotientAndRemainder(dividingBy: self.denominator)
        d += q.asDouble() / pow10
      }
    }
    return d
  }

  public static func +(x: Self, y: Self) -> Self {
    if x.denominator == y.denominator {
      return Self(x.numerator + y.numerator, x.denominator)
    } else {
      return Self(x.numerator * y.denominator + y.numerator * x.denominator, x.denominator * y.denominator)
    }
  }

  public static func ==(x: Self, y: Self) -> Bool {
    return x.numerator == y.numerator && x.denominator == y.denominator
  }

  public static func ==(x: Self, y: BInt) -> Bool {
    return x.numerator == y && x.denominator.isOne
  }

  public static func ==(x: Self, y: Int) -> Bool {
    return x.numerator == y && x.denominator.isOne
  }

  static func parseString(_ s: String) -> (mantissa: BInt, exponent: Int)? {
    enum State {
      case start
      case inInteger
      case inFraction
      case startExponent
      case inExponent
    }
    var state: State = .start
    var digits = 0
    var expDigits = 0
    var exp = ""
    var scale = 0
    var val = ""
    var negValue = false
    var negExponent = false
    for c in s {
      switch c {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
          if state == .start {
            state = .inInteger
            digits += 1
            val.append(c)
          } else if state == .inInteger {
            digits += 1
            val.append(c)
          } else if state == .inFraction {
            digits += 1
            scale += 1
            val.append(c)
          } else if state == .inExponent {
            expDigits += 1
            exp.append(c)
          } else if state == .startExponent {
            state = .inExponent
            expDigits += 1
            exp.append(c)
          }
          break
        case ".":
          if state == .start || state == .inInteger {
            state = .inFraction
          } else {
            return nil
          }
          break
        case "E", "e":
          if state == .inInteger || state == .inFraction {
            state = .startExponent
          } else {
            return nil
          }
          break
        case "+":
          if state == .start {
            state = .inInteger
          } else if state == .startExponent {
            state = .inExponent
          } else {
            return nil
          }
          break
        case "-":
          if state == .start {
            state = .inInteger
            negValue = true
          } else if state == .startExponent {
            state = .inExponent
            negExponent = true
          } else {
            return nil
          }
          break
        default:
          return nil
      }
    }
    if digits == 0 {
      return nil
    }
    if (state == .startExponent || state == .inExponent) && expDigits == 0 {
      return nil
    }
    let w = negValue ? -BInt(val)! : BInt(val)!
    let E = Int(exp)
    if E == nil && expDigits > 0 {
      return nil
    }
    let e = expDigits == 0 ? 0 : (negExponent ? -E! : E!)
    return (w, e - scale)
  }

  static func displayString(_ significand: BInt, _ exponent: Int, _ exponential: Bool) -> String {
    var s = significand.abs.asString()
    let precision = s.count
    if exponential {

      // exponential notation

      let exp = precision + exponent - 1
      if s.count > 1 {
        s.insert(".", at: s.index(s.startIndex, offsetBy: 1))
      }
      s.append("E")
      if exp > 0 {
        s.append("+")
      }
      s.append(exp.description)
    } else {

      // plain notation

      if exponent > 0 {
        if !significand.isZero {
          for _ in 0 ..< exponent {
            s.append("0")
          }
        }
      } else if exponent < 0 {
        if -exponent < precision {
          s.insert(".", at: s.index(s.startIndex, offsetBy: precision + exponent))
        } else {
          for _ in 0 ..< -(exponent + precision) {
            s.insert("0", at: s.startIndex)
          }
          s.insert(".", at: s.startIndex)
          s.insert("0", at: s.startIndex)
        }
      }
    }
    if significand.isNegative {
      s.insert("-", at: s.startIndex)
    }
    return s
  }
}

extension BigFraction: Sendable, Equatable {}

extension BigFraction: CustomStringConvertible {
  public var description: String {
    self.asString()
  }
}
