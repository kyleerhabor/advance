//
//  ImagesModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/12/24.
//

import AppKit
import AdvanceCore
import AdvanceData
import Algorithms
import BigInt
import Combine
import CoreGraphics
import Dependencies
import Foundation
import GRDB
import IdentifiedCollections
import ImageIO
import Observation
import OSLog
import VisionKit

extension URL {
  static let imagesDirectory = Self.dataDirectory.appending(component: "Images", directoryHint: .isDirectory)
}

protocol ImagesItemModelSource: CustomStringConvertible {
  var url: URL? { get }

  func resampleImage(length: Int) async -> CGImage?
}

struct AnyImagesItemModelSource {
  let source: any ImagesItemModelSource & Sendable
}

extension AnyImagesItemModelSource: Sendable {}

extension AnyImagesItemModelSource: ImagesItemModelSource {
  var description: String {
    source.description
  }

  var url: URL? {
    source.url
  }

  func resampleImage(length: Int) async -> CGImage? {
    await source.resampleImage(length: length)
  }
}

extension ImagesItemModelSource {
  // MARK: - Convenience

  func showFinder() {
    guard let url else {
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

  static func resampleImage(source imageSource: CGImageSource, length: Int) -> CGImage? {
    let iimage = CGImageSourceGetPrimaryImageIndex(imageSource)
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      // TODO: Document.
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceThumbnailMaxPixelSize: length
    ]

    guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, iimage, options as CFDictionary) else {
      return nil
    }

    return image

//    return CGImageSourceCreateThumbnailAtIndex(imageSource, iimage, options as CFDictionary)
  }
}

struct ImagesItemModelDataSource {}

extension ImagesItemModelDataSource: ImagesItemModelSource {
  var description: String {
    // Not implemented.
    ""
  }

  var url: URL? {
    // Not implemented.
    nil
  }

  func resampleImage(length: Int) async -> CGImage? {
    // Not implemented.
    nil
  }
}

struct ImagesItemModelFileSource {
  let document: URLSourceDocument
}

extension ImagesItemModelFileSource: ImagesItemModelSource {
  var description: String {
    document.source.url.pathString
  }

  var url: URL? {
    document.source.url
  }

  func resampleImage(length: Int) async -> CGImage? {
    let url = document.source.url
    let thumbnail = document.accessingSecurityScopedResource { () -> CGImage? in
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        return nil
      }

      return Self.resampleImage(source: source, length: length)
    }

    guard let thumbnail else {
      return nil
    }

    Logger.model.info("Created a resampled image for image at URL \"\(url.pathString)\" with dimensions \(thumbnail.width) x \(thumbnail.height) for length \(length)")

    return thumbnail
  }
}

struct ImagesItemModelProperties {
  let aspectRatio: Double
}

extension ImagesItemModelProperties: Sendable {}

@Observable
final class ImagesItemModel {
  let id: RowID
  // A generic parameter would be nice, but heavily infects views as a consequence.
  var source: AnyImagesItemModelSource
  var properties: ImagesItemModelProperties
  @ObservationIgnored var info: LibraryModelTrackImagesItemsImagesItemInfo
  var isBookmarked: Bool

  init(
    id: RowID,
    source: AnyImagesItemModelSource,
    properties: ImagesItemModelProperties,
    info: LibraryModelTrackImagesItemsImagesItemInfo,
    isBookmarked: Bool
  ) {
    self.id = id
    self.source = source
    self.properties = properties
    self.info = info
    self.isBookmarked = isBookmarked
  }
}

extension ImagesItemModel: Identifiable {}

extension ImagesItemModel: Equatable {
  static func ==(lhs: ImagesItemModel, rhs: ImagesItemModel) -> Bool {
    lhs.id == rhs.id
  }
}

extension ImagesItemModel: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
}

struct ImagesModelSource {
  let dataStack: DataStackDependencyKey.DataStack
  let id: LibraryModelIDImagesInfo
}

enum ImagesModelFetchPhase<Value> {
  case end, none, value(Value)

  var isEnd: Bool {
    switch self {
      case .end: true
      default: false
    }
  }
}

struct ItemDirectory<File>: Sendable where File: Sendable {
  let item: File
  let files: [File]
}

enum Item<File>: Sendable where File: Sendable {
  case file(File), directory(ItemDirectory<File>)
}

struct ImagesModelLoadImagesItemFileBookmarkBookmarkInfo {
  let bookmark: BookmarkRecord
}

extension ImagesModelLoadImagesItemFileBookmarkBookmarkInfo: Sendable, Equatable, Decodable, FetchableRecord {}

struct ImagesModelLoadImagesItemFileBookmarkRelativeInfo {
  let relative: BookmarkRecord
}

extension ImagesModelLoadImagesItemFileBookmarkRelativeInfo: Sendable, Equatable, Decodable, FetchableRecord {}

struct ImagesModelLoadImagesItemFileBookmarkInfo {
  let fileBookmark: FileBookmarkRecord
  let bookmark: ImagesModelLoadImagesItemFileBookmarkBookmarkInfo
  let relative: ImagesModelLoadImagesItemFileBookmarkRelativeInfo?
}

extension ImagesModelLoadImagesItemFileBookmarkInfo: Decodable {
  enum CodingKeys: String, CodingKey {
    case fileBookmark,
         bookmark = "_bookmark",
         relative = "_relative"
  }
}

extension ImagesModelLoadImagesItemFileBookmarkInfo: Sendable, Equatable, FetchableRecord {}

struct ImagesModelLoadImagesItemInfo {
  let item: ImagesItemRecord
  let fileBookmark: ImagesModelLoadImagesItemFileBookmarkInfo
}

extension ImagesModelLoadImagesItemInfo: Decodable {
  enum CodingKeys: CodingKey {
    case item, fileBookmark
  }
}

extension ImagesModelLoadImagesItemInfo: Sendable, Equatable, FetchableRecord {}

struct ImagesModelLoadImagesInfo {
  let images: ImagesRecord
  let items: [ImagesModelLoadImagesItemInfo]
}

extension ImagesModelLoadImagesInfo: Decodable {
  enum CodingKeys: CodingKey {
    case images, items
  }
}

extension ImagesModelLoadImagesInfo: Sendable, Equatable, FetchableRecord {}

struct ImagesModelStoreImagesItemsImagesItemInfo {
  let item: ImagesItemRecord
}

extension ImagesModelStoreImagesItemsImagesItemInfo: Decodable, FetchableRecord {}

struct ImagesModelStoreImagesItemsImagesInfo {
  let images: ImagesRecord
  let items: [ImagesModelStoreImagesItemsImagesItemInfo]
}

extension ImagesModelStoreImagesItemsImagesInfo: Decodable {
  enum CodingKeys: CodingKey {
    case images, items
  }
}

extension ImagesModelStoreImagesItemsImagesInfo: FetchableRecord {}

@Observable
@MainActor
final class ImagesItemModel2 {
  let id: RowID
  var source: URLSource
  var title: String
  var isBookmarked: Bool
  var aspectRatio: Double

  init(id: RowID, source: URLSource, title: String, isBookmarked: Bool, aspectRatio: Double) {
    self.id = id
    self.source = source
    self.title = title
    self.isBookmarked = isBookmarked
    self.aspectRatio = aspectRatio
  }
}

extension ImagesItemModel2: Identifiable {}

struct ImagesModelStoreState {
  var bookmarks: [URL: Bookmark]
}

@Observable
@MainActor
final class ImagesModel {
  typealias ID = UUID
  typealias Resampler = AsyncStream<Runner<CGImage?, Never>>
  typealias Analyzer = AsyncStream<Runner<ImageAnalysis, any Error>>

  let id: UUID

  var items2: IdentifiedArrayOf<ImagesItemModel2>
  private(set) var hasLoadedNoImages: Bool
  var items: IdentifiedArrayOf<ImagesItemModel>
  var itemID: ImagesItemModel.ID?
  var bookmarkedItems: Set<ImagesItemModel.ID>
  var item: ImagesItemModel? {
    itemID.flatMap { items[id: $0] } ?? items.first
  }
  var isReady: Bool {
    performedItemsFetch && performedPropertiesFetch
  }
  @ObservationIgnored var incomingItemID = PassthroughSubject<ImagesItemModel.ID, Never>()
  @ObservationIgnored private var source: Once<ImagesModelSource>
  @ObservationIgnored var resampler: (stream: Resampler, continuation: Resampler.Continuation)
  @ObservationIgnored var analyzer: (stream: Analyzer, continuation: Analyzer.Continuation)
  private var performedItemsFetch = false
  private var performedPropertiesFetch = false

  init(id: UUID) {
    self.id = id
    self.items = []
    self.items2 = []
    self.hasLoadedNoImages = false
    self.bookmarkedItems = []
    self.source = Once {
      @Dependency(\.dataStack) var dataStack

      let ds = try await dataStack()
      let id = try await ds.connection.write { db in
        try DataStackDependencyKey.DataStack.idImages(db, id: id)
      }

      return ImagesModelSource(dataStack: ds, id: id)
    }
    // Should we set an explicit buffering policy?
    self.resampler = AsyncStream.makeStream()
    self.analyzer = AsyncStream.makeStream()
  }

  func load2() async {
    await _load()
  }

  func store(urls: [URL], directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions) async {
    await _store(urls: urls, directoryEnumerationOptions: directoryEnumerationOptions)
  }

  func store(items: [ImagesItemTransfer], enumerationOptions: FileManager.DirectoryEnumerationOptions) async {
    await _store(items: items, enumerationOptions: enumerationOptions)
  }

  func showFinder(items: Set<ImagesItemModel2.ID>) {
    NSWorkspace.shared.activateFileViewerSelecting(_urls(forItems: items))
  }

  func isInvalidSelection(of items: Set<ImagesItemModel2.ID>) -> Bool {
    items.isEmpty
  }

  func urls(forItems items: Set<ImagesItemModel2.ID>) -> [URL] {
    _urls(forItems: items)
  }

  func copy(items: Set<ImagesItemModel2.ID>) {
    NSPasteboard.general.prepareForNewContents()
    NSPasteboard.general.writeObjects(_urls(forItems: items) as [NSURL])
  }

  nonisolated private func loadImages(connection: DatabasePool, images: ImagesModelLoadImagesInfo?) async {
    guard let images else {
      Task { @MainActor in
        hasLoadedNoImages = true
      }

      return
    }

    let items = images.items.map { item in
      ImagesItemInfo(
        item: item.item,
        fileBookmark: ImagesItemFileBookmarkInfo(
          fileBookmark: item.fileBookmark.fileBookmark,
          bookmark: ImagesItemFileBookmarkBookmarkInfo(
            bookmark: item.fileBookmark.bookmark.bookmark,
          ),
          relative: item.fileBookmark.relative.map { relative in
            ImagesItemFileBookmarkRelativeInfo(
              relative: relative.relative,
            )
          },
        ),
      )
    }

    var state1 = ImagesItemAssignment()
    await state1.assign(items: items)

    guard state1.isSatisified(with: items) else {
      do {
        try await connection.write { [state1] db in
          try state1.write(db, items: items)
        }
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }

      return
    }

    struct State2Item {
      let item: ImagesItemInfo
      let title: String
      let aspectRatio: Double
    }

    struct State2 {
      var items: [RowID: State2Item]
    }

    let state2 = await withTaskGroup(of: State2Item?.self) { group in
      // TODO: Rewrite.
      items.forEach { item in
        group.addTask { [state1] in
          let relative: URLSource?

          do {
            relative = try state1.relative(item.fileBookmark.relative)
          } catch {
            // TODO: Elaborate.
            Logger.model.error("\(error)")

            return nil
          }

          guard let bookmark = state1.bookmarks[item.fileBookmark.bookmark.bookmark.rowID!] else {
            return nil
          }

          let source = URLSource(url: bookmark.resolved.url, options: item.fileBookmark.bookmark.bookmark.options!)
          let item = relative.accessingSecurityScopedResource { () -> State2Item? in
            source.accessingSecurityScopedResource {
              let resourceValues: URLResourceValues

              do {
                resourceValues = try source.url.resourceValues(forKeys: [.localizedNameKey, .hasHiddenExtensionKey])
              } catch {
                // TODO: Elaborate.
                Logger.model.error("\(error)")

                return nil
              }

              guard let name = resourceValues.localizedName,
                    let isExtensionHidden = resourceValues.hasHiddenExtension else {
                // TODO: Log.
                return nil
              }

              let title = URL(filePath: name, directoryHint: .notDirectory).title(extensionHidden: isExtensionHidden)

              guard let imageSource = CGImageSourceCreateWithURL(source.url as CFURL, nil) else {
                // TODO: Log.
                return nil
              }

              let options = [kCGImageSourceShouldCache: false]

//              let orientation: CGImagePropertyOrientation? = if let displayOrientation = imageProperties[kCGImagePropertyOrientation] as? UInt32{
//                CGImagePropertyOrientation(rawValue: displayOrientation)
//              } else {
//                .up
//              }
//
//              let aspectRatio = orientation.isReflected
//              ? pixelHeight / pixelWidth
//              : pixelWidth / pixelHeight

              guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(
                imageSource,
                CGImageSourceGetPrimaryImageIndex(imageSource),
                options as CFDictionary,
              ) as? [CFString: Any],
                    let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? Double,
                    let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? Double else {
                // TODO: Log.
                return nil
              }

              let aspectRatio = pixelWidth / pixelHeight

              return State2Item(item: item, title: title, aspectRatio: aspectRatio)
            }
          }

          return item
        }
      }


      return await group.reduce(
        into: State2(items: Dictionary(minimumCapacity: images.items.count)),
      ) { partialResult, child in
        guard let child else {
          return
        }

        partialResult.items[child.item.item.rowID!] = child
      }
    }

    Task { @MainActor in
      items2 = IdentifiedArray(
        uniqueElements: images.items
          .compactMap { item in
            guard let item = state2.items[item.item.rowID!] else {
              return nil
            }

            guard let bookmark = state1.bookmarks[item.item.fileBookmark.bookmark.bookmark.rowID!] else {
              return nil
            }

            return ImagesItemModel2(
              id: item.item.item.rowID!,
              source: URLSource(
                url: bookmark.resolved.url,
                options: item.item.fileBookmark.bookmark.bookmark.options!,
              ),
              title: item.title,
              isBookmarked: item.item.item.isBookmarked!,
              aspectRatio: item.aspectRatio,
            )
          },
      )

      hasLoadedNoImages = items2.isEmpty
    }
  }

  nonisolated private func _load() async {
    let observation = ValueObservation
      .trackingConstantRegion { db in
        try ImagesRecord
          .select(.rowID)
          .filter(key: [ImagesRecord.Columns.id.name: self.id])
          .including(
            all: ImagesRecord.items
              .forKey(ImagesModelLoadImagesInfo.CodingKeys.items)
              .select(.rowID, ImagesItemRecord.Columns.position, ImagesItemRecord.Columns.isBookmarked)
              .order(ImagesItemRecord.Columns.position)
              .including(
                required: ImagesItemRecord.fileBookmark
                  .forKey(ImagesModelLoadImagesItemInfo.CodingKeys.fileBookmark)
                  .select(.rowID)
                  .including(
                    required: FileBookmarkRecord.bookmark
                      .forKey(ImagesModelLoadImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                      .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
                  )
                  .including(
                    optional: FileBookmarkRecord.relative
                      .forKey(ImagesModelLoadImagesItemFileBookmarkInfo.CodingKeys.relative)
                      .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
                  ),
              ),
          )
          .asRequest(of: ImagesModelLoadImagesInfo.self)
          .fetchOne(db)
      }
      .removeDuplicates()

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      for try await images in observation.values(in: connection, bufferingPolicy: .bufferingNewest(1)) {
        await loadImages(connection: connection, images: images)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func createFileBookmark(
    _ db: Database,
    bookmark: Bookmark,
    relative: RowID?,
  ) throws -> FileBookmarkRecord {
    var bookmark = BookmarkRecord(data: bookmark.data, options: bookmark.options)
    try bookmark.upsert(db)

    var fileBookmark = FileBookmarkRecord(
      bookmark: bookmark.rowID,
      relative: relative,
    )

    try fileBookmark.upsert(db)

    return fileBookmark
  }

  nonisolated private func createItemImages(
    _ db: Database,
    images: RowID,
    fileBookmark: RowID,
    position: BigFraction,
  ) throws -> ItemImagesRecord {
    var imagesItem = ImagesItemRecord(position: position, isBookmarked: false, fileBookmark: fileBookmark)
    try imagesItem.insert(db)

    var itemImages = ItemImagesRecord(images: images, item: imagesItem.rowID)
    try itemImages.insert(db)

    return itemImages
  }

  nonisolated private func addTask(
    to group: inout ThrowingTaskGroup<URLBookmark, any Error>,
    from iterator: inout some IteratorProtocol<URLSource>,
    bookmarkRelativeTo relative: URL,
  ) {
    guard let source = iterator.next() else {
      return
    }

    group.addTask {
      try source.accessingSecurityScopedResource {
        try URLBookmark(url: source.url, options: source.options, relativeTo: relative)
      }
    }
  }

  nonisolated private func addTask(
    to taskGroup: inout ThrowingTaskGroup<Item<URLBookmark>, any Error>,
    from iterator: inout some IteratorProtocol<Item<URLSource>>,
  ) {
    guard let item = iterator.next() else {
      return
    }

    taskGroup.addTask {
      switch item {
        case let .file(source):
          let bookmark = try source.accessingSecurityScopedResource {
            try URLBookmark(url: source.url, options: source.options, relativeTo: nil)
          }

          return .file(bookmark)
        case let .directory(directory):
          return try await directory.item.accessingSecurityScopedResource {
            let bookmark = try URLBookmark(url: directory.item.url, options: directory.item.options, relativeTo: nil)
            let files = await withThrowingTaskGroup { group in
              var iterator = directory.files.makeIterator()
              var items = [URLBookmark](reservingCapacity: directory.files.count)

              // For some reason, adding more than 12 concurrent tasks on my 2019 MacBook Pro causes the task group
              // to hang. I presume this is internal to sub-task groups that execute certain code because it doesn't
              // occur in the parent nor when the code is simple (e.g., sleeping for a second before returning a
              // constant value).
              (ProcessInfo.processInfo.activeProcessorCount / 2).times {
                self.addTask(to: &group, from: &iterator, bookmarkRelativeTo: bookmark.url)
              }

              while let result = await group.nextResult() {
                switch result {
                  case let .success(child):
                    items.append(child)
                  case let .failure(error):
                    // TODO: Elaborate.
                    Logger.model.error("\(error)")
                }

                self.addTask(to: &group, from: &iterator, bookmarkRelativeTo: bookmark.url)
              }

              return items
            }

            return .directory(ItemDirectory(item: bookmark, files: files))
          }
      }
    }
  }

  nonisolated private func store(items: [Item<URLSource>]) async {
    let state1 = await withThrowingTaskGroup { group in
      var state = ImagesModelStoreState(bookmarks: [:])
      var iterator = items.makeIterator()

      (ProcessInfo.processInfo.activeProcessorCount / 2).times {
        addTask(to: &group, from: &iterator)
      }

      while let result = await group.nextResult() {
        switch result {
          case let .success(item):
            switch item {
              case let .file(item):
                state.bookmarks[item.url] = item.bookmark
              case let .directory(directory):
                let item = directory.item

                state.bookmarks[item.url] = item.bookmark

                directory.files.forEach { item in
                  state.bookmarks[item.url] = item.bookmark
                }
            }
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }

        addTask(to: &group, from: &iterator)
      }

      return state
    }

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      try await connection.write { db in
        var images = ImagesRecord(rowID: nil, id: id, currentItem: nil)
        try images.upsert(db)

        let images2 = try ImagesRecord
          .select(.rowID)
          .filter(key: images.rowID)
          .including(
            // TODO: LIMIT 1.
            all: ImagesRecord.items
              .forKey(ImagesModelStoreImagesItemsImagesInfo.CodingKeys.items)
              .select(.rowID)
              .order(ImagesItemRecord.Columns.position.desc),
          )
          .asRequest(of: ImagesModelStoreImagesItemsImagesInfo.self)
          .fetchOne(db)!

        _ = try items.reduce(images2.items.first?.item.position ?? BigFraction.zero) { position, item in
          switch item {
            case let .file(source):
              guard let item = state1.bookmarks[source.url] else {
                return position
              }

              let size = position.denominator.size.asInt()!
              var delta = BigFraction(BInt.ONE, BInt.TEN ** size)

              if (position + delta).simplified == 1 {
                delta = BigFraction(BInt.ONE, BInt.TEN ** (size + 1))
              }

              let position = position + delta
              let fileBookmark = try createFileBookmark(db, bookmark: item, relative: nil)
              _ = try createItemImages(
                db,
                images: images.rowID!,
                fileBookmark: fileBookmark.rowID!,
                position: position,
              )

              return position
            case let .directory(directory):
              guard let item = state1.bookmarks[directory.item.url] else {
                return position
              }

              let fileBookmark = try createFileBookmark(db, bookmark: item, relative: nil)

              return try directory.files.reduce(position) { position, source in
                guard let item = state1.bookmarks[source.url] else {
                  return position
                }

                let size = position.denominator.size.asInt()!
                var delta = BigFraction(BInt.ONE, BInt.TEN ** size)

                if (position + delta).simplified == 1 {
                  delta = BigFraction(BInt.ONE, BInt.TEN ** (size + 1))
                }

                let position = position + delta
                let fileBookmark = try createFileBookmark(db, bookmark: item, relative: fileBookmark.rowID)
                _ = try createItemImages(
                  db,
                  images: images.rowID!,
                  fileBookmark: fileBookmark.rowID!,
                  position: position,
                )

                return position
              }
          }
        }
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func _store(
    urls: [URL],
    directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions,
  ) async {
    let items = urls.compactMap { url -> Item<URLSource>? in
      let source = URLSource(
        url: url,
        options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess, .withoutImplicitSecurityScope],
      )

      do {
        let files = try source.accessingSecurityScopedResource {
          try FileManager.default
            .enumerate(at: source.url, options: directoryEnumerationOptions)
            .finderSort(by: \.pathComponents)
            .map { URLSource(url: $0, options: []) }
        }

        return .directory(ItemDirectory(item: source, files: files))
      } catch {
        guard case let .iterationFailed(error) = error as? FileManager.DirectoryEnumerationError,
              let error = error as? CocoaError, error.code == .fileReadUnknown,
              let error = error.underlying as? POSIXError, error.code == .ENOTDIR else {
          // TODO: Elaborate.
          Logger.model.error("\(error)")

          return nil
        }

        return .file(source)
      }
    }

    await store(items: items)
  }

  nonisolated private func _store(items: [ImagesItemTransfer], enumerationOptions: FileManager.DirectoryEnumerationOptions) async {
    let items = items.compactMap { item -> Item<URLSource>? in
      switch item.contentType {
        case .image:
          return .file(item.source)
        case .folder:
          let files: [URLSource]

          do {
            files = try item.source.accessingSecurityScopedResource {
              try FileManager.default
                .enumerate(at: item.source.url, options: enumerationOptions)
                // TODO: Sort using componentsToDisplay(forPath:)
                .finderSort(by: \.pathComponents)
                .map { URLSource(url: $0, options: []) }
            }
          } catch {
            // TODO: Elaborate.
            Logger.model.error("\(error)")

            return nil
          }

          return .directory(ItemDirectory(item: item.source, files: files))
        default:
          unreachable()
      }
    }

    await store(items: items)
  }

  private func _urls(forItems items: Set<ImagesItemModel2.ID>) -> [URL] {
    items.compactMap { self.items2[id: $0]?.source.url }
  }

  static func submitCurrentItem(
    _ dataStack: DataStackDependencyKey.DataStack,
    images: RowID,
    currentItem: RowID?,
  ) async throws {
    try await dataStack.connection.write { db in
      try DataStackDependencyKey.DataStack.submitImagesCurrentItem(db, images: images, currentItem: currentItem)
    }
  }

  static func submitItemBookmark(
    _ dataStack: DataStackDependencyKey.DataStack,
    item: RowID,
    isBookmarked: Bool,
  ) async throws {
    try await dataStack.connection.write { db in
      try DataStackDependencyKey.DataStack.submitImagesItemBookmark(db, item: item, isBookmarked: isBookmarked)
    }
  }

  @MainActor
  private func load(response: LibraryModelTrackImagesPropertiesImagesInfo) {
    itemID = response.currentItem.item.rowID
  }

  @MainActor
  private func fetch(
    from iterator: inout AsyncValueObservation<LibraryModelTrackImagesPropertiesImagesInfo?>.Iterator
  ) async throws -> ImagesModelFetchPhase<LibraryModelTrackImagesPropertiesImagesInfo> {
    guard let value = try await iterator.next() else {
      return .end
    }

    guard let response = value else {
      return .none
    }

    load(response: response)

    return .value(response)
  }

  private func performFetch(
    from iterator: inout AsyncValueObservation<LibraryModelTrackImagesPropertiesImagesInfo?>.Iterator
  ) async throws -> Bool {
    defer {
      performedPropertiesFetch = true
    }

    switch try await fetch(from: &iterator) {
      case .end:
        return false
      case .none:
        return true
      case let .value(response):
        response.currentItem.item.rowID.map(incomingItemID.send(_:))

        return true
    }
  }

  @MainActor
  private func track(
    from iterator: inout AsyncValueObservation<LibraryModelTrackImagesPropertiesImagesInfo?>.Iterator,
  ) async throws {
    while try await !fetch(from: &iterator).isEnd {}
  }

  private func loadRunGroups() async throws {
    var resampler = resampler.stream.makeAsyncIterator()
    var analyzer = analyzer.stream.makeAsyncIterator()

    async let resamplerRunGroup: () = run(limit: 8, iterator: &resampler)
    async let analyzerRunGroup: () = run(limit: 10, iterator: &analyzer)
    _ = try await [resamplerRunGroup, analyzerRunGroup]
  }

  @MainActor
  private func loadTrackers() async throws {
    let source = try await source()

    // TODO: Decouple properties from items.
    //
    // We currently need to process items first so the UI can be ready to receive the incoming item ID. This should be
    // split so it's sent when both data sources are ready.
    var properties = source.dataStack.trackImagesProperties(images: source.id.images.rowID!).makeAsyncIterator()

    guard try await performFetch(from: &properties) else {
      return
    }

    async let propertiesTracker: () = track(from: &properties)
    _ = try await [propertiesTracker]
  }

  @MainActor
  func load() async throws {
    async let runGroups: () = loadRunGroups()
    async let trackers: () = loadTrackers()
    _ = try await [runGroups, trackers]
  }

  @MainActor
  func submit(currentItem item: ImagesItemModel?) async throws {
    let source = try await source()

    guard let item = item?.info else {
      return
    }

    try await Self.submitCurrentItem(source.dataStack, images: source.id.images.rowID!, currentItem: item.item.rowID)
  }

  @MainActor
  func submitItemBookmark(item: ImagesItemModel, isBookmarked: Bool) async throws {
    let source = try await source()

    try await Self.submitItemBookmark(source.dataStack, item: item.info.item.rowID!, isBookmarked: isBookmarked)
  }
}

extension ImagesModel: @MainActor Equatable {
  static func ==(lhs: ImagesModel, rhs: ImagesModel) -> Bool {
    lhs.id == rhs.id
  }
}

extension ImagesModel: @MainActor Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension ImagesModel: @MainActor Codable {
  convenience init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let id = try container.decode(UUID.self)

    self.init(id: id)
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(id)
  }
}
