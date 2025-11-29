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
      // Note there is also a .withoutUI option, but I haven't checked whether or not it performs the same action.
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

enum ImagesItemAssignmentTaskError: Error {
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
          throw ImagesItemAssignmentTaskError.relativeUnresolved
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

  func isSatisified(with items: [ImagesItemInfo]) -> Bool {
    items.allSatisfy { item in
      if let relative = item.fileBookmark.relative {
        guard let bookmark = bookmarks[relative.relative.rowID!] else {
          // It's possible resolving the bookmark failed, in which we don't want to potentially spin in an infinite loop.
          return true
        }

        return !bookmark.resolved.isStale
      }

      guard let bookmark = bookmarks[item.fileBookmark.bookmark.bookmark.rowID!] else {
        // It's possible resolving the bookmark failed.
        return true
      }

      return !bookmark.resolved.isStale
    }
  }

  func write(_ db: Database, items: [ImagesItemInfo]) throws {
    try items
      .compactMap(\.fileBookmark.relative)
      .uniqued(on: \.relative.rowID)
      .forEach { relative in
        let rowID = relative.relative.rowID!

        guard let assigned = bookmarks[rowID] else {
          return
        }

        let bookmark = BookmarkRecord(rowID: rowID, data: assigned.data, options: nil)
        try bookmark.update(db, columns: [BookmarkRecord.Columns.data])
      }

    try items.forEach { item in
      let rowID = item.fileBookmark.bookmark.bookmark.rowID!

      guard let assigned = bookmarks[rowID] else {
        return
      }

      let bookmark = BookmarkRecord(rowID: rowID, data: assigned.data, options: nil)
      try bookmark.update(db, columns: [BookmarkRecord.Columns.data])
    }
  }
}

extension ImagesItemAssignment {
  init() {
    self.init(bookmarks: [:])
  }
}
