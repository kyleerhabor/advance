//
//  UI+Model.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import Algorithms
import AsyncAlgorithms
@preconcurrency import BigInt
import Foundation
import GRDB
import ImageIO
import OSLog
import UniformTypeIdentifiers
import VisionKit

// MARK: - Swift

struct ClockMeasurement<T, Duration> where Duration: DurationProtocol {
  let value: T
  let duration: Duration
}

extension Clock {
  func measure<T>(_ body: () async throws -> T) async rethrows -> ClockMeasurement<T, Duration> {
    var value: T!
    let duration = try await self.measure {
      value = try await body()
    }

    let measurement = ClockMeasurement(value: value!, duration: duration)

    return measurement
  }
}

// MARK: - Swift Concurrency

struct Run<T, E> where E: Error {
  let continuation: CheckedContinuation<T, E>
  let body: @Sendable () async throws(E) -> T

  init(continuation: CheckedContinuation<T, E>, _ body: @escaping @Sendable () async throws(E) -> T) {
    self.continuation = continuation
    self.body = body
  }

  func run() async {
    do {
      self.continuation.resume(returning: try await self.body())
    } catch {
      self.continuation.resume(throwing: error)
    }
  }
}

extension Run: Sendable {}

func run<T, E, Base>(_ base: Base, count: Int) async throws where Base: AsyncSequence,
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
        break
      }

      group.addTask {
        await element.run()
      }
    }
  }
}

// MARK: - Foundation

struct TypedIterator<Base, T>: IteratorProtocol where Base: IteratorProtocol {
  private var base: Base

  init(_ base: Base, as type: T.Type = T.self) {
    self.base = base
  }

  mutating func next() -> T? {
    self.base.next() as? T
  }
}

extension TypedIterator: Sequence {}

extension FileManager {
  func enumerate(
    at url: URL,
    includingPropertiesForKeys keys: [URLResourceKey]?,
    options: FileManager.DirectoryEnumerationOptions,
  ) -> (some Sequence<URL>)? {
    guard let enumerator = self.enumerator(at: url, includingPropertiesForKeys: keys, options: options) else {
      return nil as TypedIterator<NSFastEnumerationIterator, URL>?
    }

    let iterator = TypedIterator(enumerator.makeIterator(), as: URL.self)

    return iterator
  }
}

// MARK: - Core Graphics

extension CGSize {
  var length: Double {
    max(self.width, self.height)
  }
}

// MARK: - Image I/O

extension CGImagePropertyOrientation {
  static let identity = Self.up

  var isRotated90Degrees: Bool {
    switch self {
      case .leftMirrored, .right, .rightMirrored, .left: true
      default: false
    }
  }
}

// MARK: - VisionKit

extension ImageAnalyzer {
  static let maxLength: CGFloat = 8192
}

// MARK: - Uniform Type Identifiers

extension UTType {
  static let settingsAccessorySearchItem = Self(exportedAs: "com.kyleerhabor.AdvanceSettingsAccessorySearchItem")
}

// MARK: -

let analyses = AsyncChannel<Run<ImageAnalysis, any Error>>()

func delta(lowerBound: BigFraction, upperBound: BigFraction, base: BInt) -> BigFraction {
  let denominator = lowerBound.denominator * upperBound.denominator
  let d = BigFraction(.ONE, denominator)
  let c = lowerBound + d

  guard (c - upperBound).isZero else {
    return d
  }

  return BigFraction(.ONE, denominator * base)
}

struct SizeOrientation {
  let size: CGSize
  let orientation: CGImagePropertyOrientation

  var orientedSize: CGSize {
    guard orientation.isRotated90Degrees else {
      return size
    }

    return CGSize(width: size.height, height: size.width)
  }
}

enum BookmarkStatus {
  case old, current, new
}

func bookmark(data: Data, assigned: AssignedBookmark?) -> BookmarkStatus {
  // If the bookmark wasn't assigned, return the same bookmark data to notify observers that the state of the underlying
  // resource has changed (e.g., a file we think is available is no longer available).
  guard let assigned else {
    return .old
  }

  // If the bookmark was resolved and is not stale, return to signal that the state of the underlying resource hasn't
  // changed (e.g., a file we think is available is still available).
  guard assigned.resolved.isStale else {
    return .current
  }

  // If the bookmark was resolved and is stale, return the new bookmark data to notify observers that the state of the
  // underlying resource has changed (e.g., a file we think is available is still available, but has new bookmark data).
  return .new
}

func write(_ db: Database, bookmark: BookmarkRecord, assigned: AssignedBookmark?) throws {
  let id = bookmark.rowID!

  switch Advance.bookmark(data: bookmark.data!, assigned: assigned) {
    case .old:
      try db.notifyChanges(in: BookmarkRecord.all())
    case .current:
      break
    case .new:
      let bookmark = BookmarkRecord(rowID: id, data: assigned?.data, options: nil)
      try bookmark.update(db, columns: [BookmarkRecord.Columns.data])
  }
}

extension Logger {
  static let model = Self(subsystem: Bundle.appID, category: "Model")
}

struct ImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

struct ImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

struct ImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesItemFileBookmarkRelativeInfo?
}

struct ImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesItemFileBookmarkInfo
}

extension URL.BookmarkResolutionOptions {
  init(_ options: URL.BookmarkCreationOptions) {
    self.init()

    if options.contains(.withSecurityScope) {
      self.insert(.withSecurityScope)
    }

    if options.contains(.withoutImplicitSecurityScope) {
      self.insert(.withoutImplicitStartAccessing)
    }
  }
}

extension AssignedBookmark {
  @available(*, noasync)
  init(data: Data, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    try self.init(
      data: data,
      // In my experience, if the user has a volume that was created as an image in Disk Utility and it's not mounted,
      // resolution will fail while prompting the user to unlock the volume. Now, we're not a file managing app, so we
      // don't need to invest in making that work.
      //
      // Note there is also a withoutUI option, but I haven't checked whether or not it performs the same action.
      options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
      relativeTo: relative,
    ) { url in
      Logger.model.log("Bookmark for file URL '\(url.pathString)' is stale: re-creating...")

      let source = URLSource(url: url, options: options)
      let bookmark = try source.accessingSecurityScopedResource {
        try source.url.bookmark(options: source.options, relativeTo: relative)
      }

      return bookmark
    }
  }

  init(data: Data, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) async throws {
    try await self.init(
      data: data,
      options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
      relativeTo: relative,
    ) { url in
      Logger.model.log("Bookmark for file URL '\(url.pathString)' is stale: re-creating...")

      let source = URLSource(url: url, options: options)
      let bookmark = try await source.accessingSecurityScopedResource {
        try await source.url.bookmark(options: source.options, relativeTo: relative)
      }

      return bookmark
    }
  }
}

struct ImagesItemAssignmentTaskResult {
  let item: BookmarkRecord
  let bookmark: AssignedBookmark
}

enum ImagesItemAssignmentError: Error {
  case unresolvedRelative
}

struct ImagesItemAssignment {
  var bookmarks: [RowID: AssignedBookmark]

  mutating func assign(items: [ImagesItemInfo]) async {
    await withThrowingTaskGroup { group in
      items
        .compactMap(\.fileBookmark.relative)
        .uniqued(on: \.relative.rowID)
        .forEach { relative in
          group.addTask {
            let bookmark = try await AssignedBookmark(
              data: relative.relative.data!,
              options: relative.relative.options!,
              relativeTo: nil,
            )

            let result = ImagesItemAssignmentTaskResult(item: relative.relative, bookmark: bookmark)

            return result
          }
        }

      while let result = await group.nextResult() {
        switch result {
          case let .success(child):
            self.bookmarks[child.item.rowID!] = child.bookmark
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }
      }

      items.forEach { item in
        group.addTask { [self] in
          let relative = try self.relative(item.fileBookmark.relative)
          let bookmark = try await relative.accessingSecurityScopedResource {
            try await AssignedBookmark(
              data: item.fileBookmark.bookmark.bookmark.data!,
              options: item.fileBookmark.bookmark.bookmark.options!,
              relativeTo: relative?.url,
            )
          }

          let result = ImagesItemAssignmentTaskResult(item: item.fileBookmark.bookmark.bookmark, bookmark: bookmark)

          return result
        }
      }

      while let result = await group.nextResult() {
        switch result {
          case let .success(child):
            bookmarks[child.item.rowID!] = child.bookmark
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }
      }
    }
  }

  private func isSatisified(with bookmark: BookmarkRecord) -> Bool {
    guard let bookmark = bookmarks[bookmark.rowID!] else {
      // It's possible resolving the bookmark failed, in which we don't want to potentially spin in an infinite loop.
      return true
    }

    return !bookmark.resolved.isStale
  }

  func isSatisified(with items: [ImagesItemInfo]) -> Bool {
    items.allSatisfy { item in
      // We don't need to test this if the relative is not satisfied.
      var isBookmarkSatisfied: Bool {
        isSatisified(with: item.fileBookmark.bookmark.bookmark)
      }

      guard let relative = item.fileBookmark.relative else {
        return isBookmarkSatisfied
      }

      return isSatisified(with: relative.relative) && isBookmarkSatisfied
    }
  }

  func write(_ db: Database, items: [ImagesItemInfo]) throws {
    try items
      .compactMap(\.fileBookmark.relative)
      .uniqued(on: \.relative.rowID)
      .forEach { relative in
        let item = relative.relative
        try Advance.write(db, bookmark: item, assigned: bookmarks[item.rowID!])
      }

    try items.forEach { item in
      let item = item.fileBookmark.bookmark.bookmark
      try Advance.write(db, bookmark: item, assigned: bookmarks[item.rowID!])
    }
  }

  private func relative(_ relative: ImagesItemFileBookmarkRelativeInfo?) throws(ImagesItemAssignmentError) -> URLSource? {
    guard let relative else {
      return nil
    }

    guard let bookmark = bookmarks[relative.relative.rowID!] else {
      throw .unresolvedRelative
    }

    let source = URLSource(url: bookmark.resolved.url, options: relative.relative.options!)

    return source
  }

  func document(fileBookmark: ImagesItemFileBookmarkInfo) throws(ImagesItemAssignmentError) -> URLSourceDocument? {
    let relative = try self.relative(fileBookmark.relative)

    guard let bookmark = self.bookmarks[fileBookmark.bookmark.bookmark.rowID!] else {
      return nil
    }

    let document = URLSourceDocument(
      source: URLSource(url: bookmark.resolved.url, options: fileBookmark.bookmark.bookmark.options!),
      relative: relative,
    )

    return document
  }
}

extension ImagesItemAssignment {
  init() {
    self.init(bookmarks: [:])
  }
}
