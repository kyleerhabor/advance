//
//  UI+Model.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/29/25.
//

import AdvanceCore
import AdvanceData
import Foundation
import GRDB
import OSLog

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
  // underlying resource has changed (e.g., a file we think is available is still available, but has new data
  // represent it).
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
  init(data: Data, options: URL.BookmarkCreationOptions, relativeTo relative: URL?) throws {
    try self.init(
      data: data,
      // In my experience, if the user has a volume that was created as an image in Disk Utility and it's not mounted,
      // resolution will fail while prompting the user to unlock the volume. Now, we're not a file managing app, so we
      // don't need to invest in making that work.
      //
      // Note there is also a withoutUI option, but I haven't checked whether or not it performs the same action.
      options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
      relativeTo: nil,
    ) { url in
      let source = URLSource(url: url, options: options)
      let bookmark = try source.accessingSecurityScopedResource {
        try source.url.bookmarkData(options: source.options)
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
  case relativeUnresolved
}

struct ImagesItemAssignment {
  var bookmarks: [RowID: AssignedBookmark]

  func addTask(
    to taskGroup: inout ThrowingTaskGroup<ImagesItemAssignmentTaskResult, any Error>,
    from relatives: inout some IteratorProtocol<ImagesItemFileBookmarkRelativeInfo>,
  ) {
    guard let relative = relatives.next() else {
      return
    }

    taskGroup.addTask {
      let item = relative.relative
      let bookmark = try AssignedBookmark(data: item.data!, options: item.options!, relativeTo: nil)

      return ImagesItemAssignmentTaskResult(item: item, bookmark: bookmark)
    }
  }

  func addTask(
    to taskGroup: inout ThrowingTaskGroup<ImagesItemAssignmentTaskResult, any Error>,
    from items: inout some IteratorProtocol<ImagesItemInfo>,
  ) {
    guard let item = items.next() else {
      return
    }

    taskGroup.addTask {
      let relative: URLSource?

      if let r = item.fileBookmark.relative {
        guard let bookmark = bookmarks[r.relative.rowID!] else {
          throw ImagesItemAssignmentError.relativeUnresolved
        }

        relative = URLSource(url: bookmark.resolved.url, options: r.relative.options!)
      } else {
        relative = nil
      }

      let item = item.fileBookmark.bookmark.bookmark
      let bookmark = try relative.accessingSecurityScopedResource {
        try AssignedBookmark(data: item.data!, options: item.options!, relativeTo: relative?.url)
      }

      return ImagesItemAssignmentTaskResult(item: item, bookmark: bookmark)
    }
  }

  mutating func assign(items: [ImagesItemInfo]) async {
    await withThrowingTaskGroup { group in
      let count = ProcessInfo.processInfo.activeProcessorCount / 2
      var relatives = items
        .compactMap(\.fileBookmark.relative)
        .uniqued(on: \.relative.rowID)
        .makeIterator()

      count.times {
        addTask(to: &group, from: &relatives)
      }

      while let result = await group.nextResult() {
        switch result {
          case let .success(child):
            bookmarks[child.item.rowID!] = child.bookmark
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }

        addTask(to: &group, from: &relatives)
      }

      var items = items.makeIterator()
      count.times {
        addTask(to: &group, from: &items)
      }

      while let result = await group.nextResult() {
        switch result {
          case let .success(child):
            bookmarks[child.item.rowID!] = child.bookmark
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }

        addTask(to: &group, from: &items)
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

  func relative(_ relative: ImagesItemFileBookmarkRelativeInfo?) throws(ImagesItemAssignmentError) -> URLSource? {
    guard let relative else {
      return nil
    }

    guard let bookmark = bookmarks[relative.relative.rowID!] else {
      throw .relativeUnresolved
    }

    return URLSource(url: bookmark.resolved.url, options: relative.relative.options!)
  }
}

extension ImagesItemAssignment {
  init() {
    self.init(bookmarks: [:])
  }
}
