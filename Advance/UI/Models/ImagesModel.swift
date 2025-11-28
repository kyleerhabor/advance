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

struct ImagesItemModelSourceCopier {
  let copy: (URL) throws -> Void
  let close: () -> Void
}

protocol ImagesItemModelSource: CustomStringConvertible {
  var url: URL? { get }
  var copier: ImagesItemModelSourceCopier { get async }

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

  var copier: ImagesItemModelSourceCopier {
    get async {
      await source.copier
    }
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

  var copier: ImagesItemModelSourceCopier {
    // Not implemented.
    fatalError()
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

  var copier: ImagesItemModelSourceCopier {
    let scope = document.startSecurityScope()

    return ImagesItemModelSourceCopier { destination in
      try FileManager.default.copyItem(at: document.source.url, to: destination)
    } close: {
      document.endSecurityScope(scope)
    }
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

  // This really has little to do with this class.
  static func source(urls: [Data: URL], hash: Data, options: URL.BookmarkCreationOptions) -> URLSource? {
    urls[hash].map { url in
      URLSource(url: url, options: options)
    }
  }

  static func document(
    urls: [Data: URL],
    response: LibraryModelTrackImagesItemsImagesItemFileBookmarkInfo,
  ) -> URLSourceDocument? {
    guard let source = Self.source(
      urls: urls,
      hash: response.bookmark.bookmark.hash!,
      options: response.bookmark.bookmark.options!,
    ) else {
      return nil
    }

    let relative: URLSource?

    if let rel = response.relative?.relative {
      guard let source = Self.source(urls: urls, hash: rel.hash!, options: rel.options!) else {
        return nil
      }

      relative = source
    } else {
      relative = nil
    }

    return URLSourceDocument(source: source, relative: relative)
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

  func isInvalidSelection(of ids: Set<ImagesItemModel2.ID>) -> Bool {
    ids.isEmpty
  }

  func urls(forItems items: Set<ImagesItemModel2.ID>) -> [URL] {
    _urls(forItems: items)
  }

  func copy(items: Set<ImagesItemModel2.ID>) {
    NSPasteboard.general.prepareForNewContents()
    NSPasteboard.general.writeObjects(_urls(forItems: items) as [NSURL])
  }

  private func _urls(forItems items: Set<ImagesItemModel2.ID>) -> [URL] {
    items.compactMap { self.items2[id: $0]?.source.url }
  }

  nonisolated private func loadImages(connection: DatabasePool, images: ImagesModelLoadImagesInfo?) async {
    guard let images else {
      Task { @MainActor in
        hasLoadedNoImages = true
      }

      return
    }

    struct State1 {
      var bookmarks: [RowID: DataBookmark]
    }

    struct State1ChildResolution {
      let bookmark: BookmarkRecord
      let data: DataBookmark
    }

    enum State1Child {
      case resolved(State1ChildResolution),
           unresolved
    }

    let state1 = await withThrowingTaskGroup(of: State1Child.self) { group in
      images.items
        .compactMap(\.fileBookmark.relative)
        .uniqued(on: \.relative.rowID)
        .forEach { relative in
          group.addTask {
            let options = relative.relative.options!
            let data = try DataBookmark(
              data: relative.relative.data!,
              options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
              hash: relative.relative.hash!,
              relativeTo: nil,
            ) { url in
              let source = URLSource(url: url, options: options)
              let bookmark = try source.accessingSecurityScopedResource {
                try url.bookmarkData(options: options)
              }

              return bookmark
            }

            return .resolved(State1ChildResolution(bookmark: relative.relative, data: data))
          }
        }

      var state = State1(bookmarks: [:])

      while let result = await group.nextResult() {
        switch result {
          case let .success(child):
            switch child {
              case let .resolved(resolved):
                state.bookmarks[resolved.bookmark.rowID!] = resolved.data
              case .unresolved:
                unreachable()
            }
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }
      }

      images.items.forEach { item in
        let state = state

        group.addTask {
          let relative: URLSource?

          if let r = item.fileBookmark.relative {
            guard let data = state.bookmarks[r.relative.rowID!] else {
              return .unresolved
            }

            relative = URLSource(url: data.bookmark.url, options: r.relative.options!)
          } else {
            relative = nil
          }

          let options = item.fileBookmark.bookmark.bookmark.options!
          let data = try relative.accessingSecurityScopedResource {
            try DataBookmark(
              data: item.fileBookmark.bookmark.bookmark.data!,
              options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
              hash: item.fileBookmark.bookmark.bookmark.hash!,
              relativeTo: relative?.url,
            ) { url in
              let source = URLSource(url: url, options: options)
              let bookmark = try source.accessingSecurityScopedResource {
                try url.bookmarkData(options: options, relativeTo: relative?.url)
              }

              return bookmark
            }
          }

          return .resolved(State1ChildResolution(bookmark: item.fileBookmark.bookmark.bookmark, data: data))
        }
      }

      while let result = await group.nextResult() {
        switch result {
          case let .success(child):
            switch child {
              case let .resolved(resolved):
                state.bookmarks[resolved.bookmark.rowID!] = resolved.data
              case .unresolved:
                // TODO: Log.
                break
            }
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }
      }

      return state
    }

    let satisfied = images.items.allSatisfy { item in
      if let relative = item.fileBookmark.relative {
        guard let bookmark = state1.bookmarks[relative.relative.rowID!] else {
          // It's possible resolving the bookmark failed, in which we don't want to potentially spin in an infinite loop.
          return true
        }

        // We could save on performance by running this once, but this only compares 32 bytes, so I imagine it isn't
        // that expensive.
        guard bookmark.hash == relative.relative.hash else {
          return false
        }
      }

      guard let data = state1.bookmarks[item.fileBookmark.bookmark.bookmark.rowID!] else {
        // It's possible resolving the bookmark failed.
        return true
      }

      return data.hash == item.fileBookmark.bookmark.bookmark.hash
    }

    guard satisfied else {
      do {
        try await connection.write { db in
          try images.items
            .compactMap(\.fileBookmark.relative)
            .uniqued(on: \.relative.rowID)
            .forEach { relative in
              let rowID = relative.relative.rowID!

              guard let data = state1.bookmarks[rowID] else {
                return
              }

              let bookmark = BookmarkRecord(
                rowID: rowID,
                data: data.bookmark.data,
                options: nil,
                hash: data.hash,
              )

              try bookmark.update(db, columns: [BookmarkRecord.Columns.data, BookmarkRecord.Columns.hash])
            }

          try images.items.forEach { item in
            let rowID = item.fileBookmark.bookmark.bookmark.rowID!

            guard let data = state1.bookmarks[rowID] else {
              return
            }

            let bookmark = BookmarkRecord(
              rowID: rowID,
              data: data.bookmark.data,
              options: nil,
              hash: data.hash,
            )

            try bookmark.update(db, columns: [BookmarkRecord.Columns.data, BookmarkRecord.Columns.hash])
          }
        }
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }

      return
    }

    struct State2Item {
      let item: ImagesModelLoadImagesItemInfo
      let title: String
      let aspectRatio: Double
    }

    struct State2 {
      var items: [RowID: State2Item]
    }

    let state2 = await withTaskGroup(of: State2Item?.self) { group in
      images.items.forEach { item in
        group.addTask {
          let relative: URLSource?

          if let r = item.fileBookmark.relative {
            guard let data = state1.bookmarks[r.relative.rowID!] else {
              return nil
            }

            relative = URLSource(url: data.bookmark.url, options: r.relative.options!)
          } else {
            relative = nil
          }

          guard let data = state1.bookmarks[item.fileBookmark.bookmark.bookmark.rowID!] else {
            return nil
          }

          let source = URLSource(url: data.bookmark.url, options: item.fileBookmark.bookmark.bookmark.options!)
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

            guard let data = state1.bookmarks[item.item.fileBookmark.bookmark.bookmark.rowID!] else {
              return nil
            }

            return ImagesItemModel2(
              id: item.item.item.rowID!,
              source: URLSource(
                url: data.bookmark.url,
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
                      .select(
                        .rowID,
                        BookmarkRecord.Columns.data,
                        BookmarkRecord.Columns.options,
                        BookmarkRecord.Columns.hash,
                      ),
                  )
                  .including(
                    optional: FileBookmarkRecord.relative
                      .forKey(ImagesModelLoadImagesItemFileBookmarkInfo.CodingKeys.relative)
                      .select(
                        .rowID,
                        BookmarkRecord.Columns.data,
                        BookmarkRecord.Columns.options,
                        BookmarkRecord.Columns.hash,
                      ),
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

  private struct State1Item {
    let bookmark: Bookmark
    let hash: Data
  }

  nonisolated private func createFileBookmark(
    _ db: Database,
    item: State1Item,
    relative: RowID?,
  ) throws -> FileBookmarkRecord {
    var bookmark = BookmarkRecord(
      data: item.bookmark.data,
      options: item.bookmark.options,
      hash: item.hash,
    )

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
    var imagesItem = ImagesItemRecord(
      position: position,
      priority: Int(position.asDouble()), // This should always be 0.
      isBookmarked: false,
      fileBookmark: fileBookmark,
    )

    try imagesItem.insert(db)

    var itemImages = ItemImagesRecord(images: images, item: imagesItem.rowID)
    try itemImages.insert(db)

    return itemImages
  }

  nonisolated private func store(items: [Item<URLSource>]) async {
    struct State1 {
      var items: [URL: State1Item]
    }

    struct State1Child {
      let bookmark: URLBookmark
      let hash: Data
    }

    let state1 = await withThrowingTaskGroup(of: Item<State1Child>.self) { group in
      items.forEach { item in
        group.addTask {
          switch item {
            case let .file(source):
              let urb = try source.accessingSecurityScopedResource {
                try URLBookmark(
                  url: source.url,
                  options: source.options,
                  relativeTo: nil,
                )
              }

              let hash = Advance.hash(data: urb.bookmark.data)

              return .file(State1Child(bookmark: urb, hash: hash))
            case let .directory(directory):
              return try directory.item.accessingSecurityScopedResource {
                let urb = try URLBookmark(url: directory.item.url, options: directory.item.options, relativeTo: nil)
                let hash = Advance.hash(data: urb.bookmark.data)
                let files = try directory.files.map { source in
                  let bookmark = try URLBookmark(
                    url: source.url,
                    options: source.options,
                    relativeTo: urb.url,
                  )

                  let hash = Advance.hash(data: bookmark.bookmark.data)

                  return State1Child(bookmark: bookmark, hash: hash)
                }

                return .directory(ItemDirectory(
                  item: State1Child(bookmark: urb, hash: hash),
                  files: files,
                ))
              }
          }
        }
      }

      var state = State1(items: [:])

      while let result = await group.nextResult() {
        switch result {
          case let .success(item):
            switch item {
              case let .file(item):
                state.items[item.bookmark.url] = State1Item(bookmark: item.bookmark.bookmark, hash: item.hash)
              case let .directory(directory):
                let item = directory.item

                state.items[item.bookmark.url] = State1Item(bookmark: item.bookmark.bookmark, hash: item.hash)

                directory.files.forEach { item in
                  state.items[item.bookmark.url] = State1Item(bookmark: item.bookmark.bookmark, hash: item.hash)
                }
            }
          case let .failure(error):
            // TODO: Elaborate.
            Logger.model.error("\(error)")
        }
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
              guard let item = state1.items[source.url] else {
                return position
              }

              let size = position.denominator.size.asInt()!
              var delta = BigFraction(BInt.ONE, BInt.TEN ** size)

              if (position + delta).simplified == 1 {
                delta = BigFraction(BInt.ONE, BInt.TEN ** (size + 1))
              }

              let position = position + delta
              let fileBookmark = try createFileBookmark(db, item: item, relative: nil)
              _ = try createItemImages(
                db,
                images: images.rowID!,
                fileBookmark: fileBookmark.rowID!,
                position: position,
              )

              return position
            case let .directory(directory):
              guard let item = state1.items[directory.item.url] else {
                return position
              }

              let fileBookmark = try createFileBookmark(db, item: item, relative: nil)

              return try directory.files.reduce(position) { position, source in
                let item = state1.items[source.url]!
                let size = position.denominator.size.asInt()!
                var delta = BigFraction(BInt.ONE, BInt.TEN ** size)

                if (position + delta).simplified == 1 {
                  delta = BigFraction(BInt.ONE, BInt.TEN ** (size + 1))
                }

                let position = position + delta
                let fileBookmark = try createFileBookmark(db, item: item, relative: fileBookmark.rowID)
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

  nonisolated static func source(url: URL, options: FileManager.DirectoryEnumerationOptions) throws -> Source<[URL]> {
    do {
      let enumerator = try url.accessingSecurityScopedResource {
        try FileManager.default.enumerate(at: url, options: options.union(.skipsPackageDescendants))
      }

      return .document(SourceDocument(source: url, items: enumerator.finderSort(by: \.pathComponents)))
    } catch let error as CocoaError where error.code == .fileReadUnknown {
      guard let error = error.underlying as? POSIXError,
            error.code == .ENOTDIR else {
        throw error
      }

      return .source(url)
    }
  }

  static func submit(
    _ dataStack: DataStackDependencyKey.DataStack,
    images: ImagesRecord,
    items: [Source<[URL]>],
    priority: Int
  ) async throws {
    let options = URL.BookmarkCreationOptions([
      .withSecurityScope,
      .securityScopeAllowOnlyReadAccess,
      .withoutImplicitSecurityScope,
    ])
    
    // FIXME: Optimize.
    //
    // Creating bookmarks is slow.
    let urbs: [Source<[URLBookmark]>] = items.compactMap { item in
      do {
        switch item {
          case .source(let url):
            let urb = try url.accessingSecurityScopedResource {
              try URLBookmark(url: url, options: options, relativeTo: nil)
            }

            return .source(urb)
          case .document(let document):
            let url = document.source

            return try url.accessingSecurityScopedResource {
              let urb = try URLBookmark(url: url, options: options, relativeTo: nil)

              return .document(SourceDocument(
                source: urb,
                items: document.items.compactMap { url in
                  do {
                    return try URLBookmark(url: url, options: [], relativeTo: urb.url)
                  } catch {
                    Logger.model.error("\(error)")

                    return nil
                  }
                }
              ))
            }
        }
      } catch {
        Logger.model.error("\(error)")

        return nil
      }
    }

    let bookmarks: [Source<[Bookmark]>] = urbs.map { urb in
      switch urb {
        case .source(let urb):
            .source(urb.bookmark)
        case .document(let document):
            .document(SourceDocument(
              source: document.source.bookmark,
              items: document.items.map(\.bookmark)
            ))
      }
    }

    let books = try await dataStack.connection.write { db in
      try bookmarks.reduce(into: [[(bookmark: BookmarkRecord, item: ImagesItemRecord?)]]()) { vals, source in
        vals.append(try DataStackDependencyKey.DataStack.submitImagesItems(
          db,
          bookmark: source,
          images: images.rowID!,
          priority: vals.last?.last?.item?.priority ?? priority
        ))
      }
    }

    for (urb, bookmarks) in zip(urbs, books) {
      for (urb, bookmark) in zip(urb.items, bookmarks) {
        let bookmark = bookmark.bookmark

        await dataStack.register(hash: bookmark.hash!, url: urb.url)
      }
    }
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

  static func resolve(responses: [LibraryModelUpdateImagesItemInfo]) -> [Data: (info: BookmarkRecord, bookmark: DataBookmark, relative: Data?)] {
    var result = [Data: (info: BookmarkRecord, bookmark: DataBookmark, relative: Data?)]()
    let responses = responses.map { $0.fileBookmark }
    let relatives = responses.compactMap { $0.relative?.relative }.uniqued(on: \.hash)
    var store = [Data: Data](minimumCapacity: relatives.count)
    let rels = relatives
      .compactMap { bookmark -> (bookmark: DataBookmark, options: URL.BookmarkCreationOptions)? in
        let options = bookmark.options!
        let hash = bookmark.hash!
        let resolved: DataBookmark

        do {
          resolved = try DataBookmark(
            data: bookmark.data!,
            options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
            hash: hash,
            relativeTo: nil,
          ) { url in
            let source = URLSource(url: url, options: options)
            let bookmark = try source.accessingSecurityScopedResource {
              try url.bookmarkData(options: options, relativeTo: nil)
            }

            return bookmark
          }
        } catch {
          Logger.model.error("Could not resolve bookmark with hash \"\(hash.hexEncodedString())\": \(error, privacy: .public)")

          return nil
        }

        store[hash] = resolved.hash
        result[resolved.hash] = (info: bookmark, bookmark: resolved, relative: nil)

        return (bookmark: resolved, options: options)
      }

    let scopes = rels.map { relative in
      let source = URLSource(url: relative.bookmark.bookmark.url, options: relative.options)

      return (source: source, scope: source.startSecurityScope())
    }

    defer {
      scopes.forEach { scope in
        let (source: source, scope: scope) = scope

        source.endSecurityScope(scope)
      }
    }

    responses.forEach { response in
      let relative: DataBookmark?

      if let rel = response.relative?.relative {
        guard let hash = store[rel.hash!],
              let rel = result[hash] else {
          return
        }

        relative = rel.bookmark
      } else {
        relative = nil
      }

      let options = response.bookmark.bookmark.options!
      let hash = response.bookmark.bookmark.hash!
      let r = relative?.bookmark.url
      let resolved: DataBookmark

      do {
        resolved = try DataBookmark(
          data: response.bookmark.bookmark.data!,
          options: URL.BookmarkResolutionOptions(options).union(.withoutMounting),
          hash: hash,
          relativeTo: r,
        ) { url in
          let source = URLSource(url: url, options: options)
          let bookmark = try source.accessingSecurityScopedResource {
            try url.bookmarkData(options: options, relativeTo: r)
          }

          return bookmark
        }
      } catch {
        Logger.model.error("Could not resolve bookmark with hash \"\(hash.hexEncodedString())\": \(error, privacy: .public)")

        return
      }

      result[resolved.hash] = (info: response.bookmark.bookmark, bookmark: resolved, relative: relative?.hash)
    }

    return result
  }

  static func update(
    _ dataStack: DataStackDependencyKey.DataStack,
    responses: some Sequence<LibraryModelTrackImagesItemsImagesItemInfo> & Sendable
  ) async throws -> [Data: URL] {
    let responses = try await dataStack.connection.read { db in
      // TODO: Don't map in reader.
      try DataStackDependencyKey.DataStack.fetch(db, items: Set(responses.map(\.item.rowID!)))
    }

    let resolved = Self.resolve(responses: responses)

    try await dataStack.connection.write { db in
      try resolved.values.forEach { entry in
        let (info: info, bookmark: bookmark, relative: relative) = entry
        let bookmark2 = BookmarkRecord(
          rowID: info.rowID,
          data: bookmark.bookmark.data,
          options: info.options,
          hash: bookmark.hash,
        )

        try bookmark2.update(db)

        var fileBookmark = FileBookmarkRecord(
          rowID: nil,
          bookmark: bookmark2.rowID,
          relative: relative.flatMap { resolved[$0]?.info.rowID },
        )

        try fileBookmark.upsert(db)
      }
    }

    // This will contain outdated keys.
    return resolved.mapValues(\.bookmark.bookmark.url)
  }

  static func update(
    _ dataStack: DataStackDependencyKey.DataStack,
    response: LibraryModelTrackImagesItemsImagesInfo,
  ) async throws -> [Data: URL] {
    var urls = await dataStack.urls
    let fetch = response.items.filter { ImagesItemModel.document(urls: urls, response: $0.fileBookmark) == nil }

    if !fetch.isEmpty {
      urls = await dataStack.register(urls: try await update(dataStack, responses: fetch))
    }

    return urls
  }

  static func resolve(
    _ dataStack: DataStackDependencyKey.DataStack,
    response: LibraryModelTrackImagesItemsImagesInfo,
  ) async throws -> [RowID: (document: URLSourceDocument?, data: ImagesItemModelProperties)] {
    let urls = try await Self.update(dataStack, response: response)
    let data = response.items.reduce(into: [RowID: (document: URLSourceDocument?, data: ImagesItemModelProperties)]()) { partialResult, response in
      guard let document = ImagesItemModel.document(urls: urls, response: response.fileBookmark) else {
        return
      }

      let url = document.source.url
      let data = document.accessingSecurityScopedResource { () -> ImagesItemModelProperties? in
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
          return nil
        }

        let options = [kCGImageSourceShouldCache: false]
        let imageIndex = CGImageSourceGetPrimaryImageIndex(imageSource)

        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(
          imageSource,
          imageIndex,
          options as CFDictionary,
        ) as? [CFString: Any] else {
          return nil
        }

        let orientation: CGImagePropertyOrientation? = if let displayOrientation = imageProperties[kCGImagePropertyOrientation] as? UInt32{
          CGImagePropertyOrientation(rawValue: displayOrientation)
        } else {
          .up
        }

        guard let orientation,
              let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? Double,
              let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? Double else {
          return nil
        }

        let aspectRatio = orientation.isReflected
        ? pixelHeight / pixelWidth
        : pixelWidth / pixelHeight

        return ImagesItemModelProperties(aspectRatio: aspectRatio)
      }

      guard let data else {
        return
      }

      partialResult[response.item.rowID!] = (document: document, data: data)
    }

    return data
  }

  @MainActor
  private func load(_ dataStack: DataStackDependencyKey.DataStack, response: LibraryModelTrackImagesItemsImagesInfo?) async throws {
    guard let response else {
      self.items = []

      return
    }

    let data = try await Self.resolve(dataStack, response: response)
    let items = response.items
    let value = items.reduce(into: (
      IdentifiedArrayOf<ImagesItemModel>(reservingCapacity: items.count),
      Set<ImagesItemModel.ID>(minimumCapacity: items.count)
    )) { partialResult, item in
      let id = item.item.rowID!

      guard let data = data[id] else {
        return
      }

      // TODO: Don't force unwrap.
      //
      // An images item may have one of several sources (currently file and data).
      let source = ImagesItemModelFileSource(document: data.document!)
      let model = self.items[id: id].map { model in
        model.source = AnyImagesItemModelSource(source: source)
        model.properties = data.data
        model.isBookmarked = item.item.isBookmarked ?? false

        return model
      } ?? ImagesItemModel(
        id: id,
        source: AnyImagesItemModelSource(source: source),
        properties: data.data,
        info: item,
        isBookmarked: item.item.isBookmarked ?? false
      )

      partialResult.0.append(model)

      if model.isBookmarked {
        partialResult.1.insert(model.id)
      }
    }

    // TODO: Verify.
    self.items = value.0
    self.bookmarkedItems = value.1
  }

  @MainActor
  private func load(response: LibraryModelTrackImagesPropertiesImagesInfo) {
    itemID = response.currentItem.item.rowID
  }

  @MainActor
  private func fetch(
    _ dataStack: DataStackDependencyKey.DataStack,
    from iterator: inout AsyncValueObservation<LibraryModelTrackImagesItemsImagesInfo?>.Iterator
  ) async throws -> Bool {
    guard let value = try await iterator.next() else {
      return false
    }

    try await load(dataStack, response: value)

    return true
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

  @MainActor
  private func performFetch(
    _ dataStack: DataStackDependencyKey.DataStack,
    from iterator: inout AsyncValueObservation<LibraryModelTrackImagesItemsImagesInfo?>.Iterator
  ) async throws -> Bool {
    defer {
      performedItemsFetch = true
    }

    return try await fetch(dataStack, from: &iterator)
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
    _ dataStack: DataStackDependencyKey.DataStack,
    from iterator: inout AsyncValueObservation<LibraryModelTrackImagesItemsImagesInfo?>.Iterator,
  ) async throws {
    while try await fetch(dataStack, from: &iterator) {}
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
    var items = source.dataStack.trackImagesItems(images: source.id.images.rowID!).makeAsyncIterator()

    guard try await performFetch(source.dataStack, from: &items) else {
      return
    }

    // TODO: Decouple properties from items.
    //
    // We currently need to process items first so the UI can be ready to receive the incoming item ID. This should be
    // split so it's sent when both data sources are ready.
    var properties = source.dataStack.trackImagesProperties(images: source.id.images.rowID!).makeAsyncIterator()

    guard try await performFetch(from: &properties) else {
      return
    }

    async let itemsTracker: () = track(source.dataStack, from: &items)
    async let propertiesTracker: () = track(from: &properties)
    _ = try await [itemsTracker, propertiesTracker]
  }

  @MainActor
  func load() async throws {
    async let runGroups: () = loadRunGroups()
    async let trackers: () = loadTrackers()
    _ = try await [runGroups, trackers]
  }

  @MainActor
  func submit(items: [Source<[URL]>]) async throws {
    let source = try await source()

    try await Self.submit(
      source.dataStack,
      images: source.id.images,
      items: items,
      priority: self.items.last?.info.item.priority ?? -1
    )
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
