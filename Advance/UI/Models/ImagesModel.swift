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

    return CGImageSourceCreateThumbnailAtIndex(imageSource, iimage, options as CFDictionary)
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
  let id: UUID
  // A generic parameter would be nice, but heavily infects views as a consequence.
  var source: AnyImagesItemModelSource
  var properties: ImagesItemModelProperties
  @ObservationIgnored var info: ImagesItemInfo
  var isBookmarked: Bool

  init(
    id: UUID,
    source: AnyImagesItemModelSource,
    properties: ImagesItemModelProperties,
    info: ImagesItemInfo,
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

  static func document(urls: [Data: URL], response: BookmarkTrackerResponse) -> URLSourceDocument? {
    let bookmark = response.bookmark

    guard let source = Self.source(urls: urls, hash: bookmark.hash!, options: bookmark.options!) else {
      return nil
    }

    let relative: URLSource?

    if let rel = response.relative {
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
  let id: ImagesIDResponse
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

@Observable
final class ImagesModel {
  typealias ID = UUID
  typealias Resampler = AsyncStream<Runner<CGImage?, Never>>
  typealias Analyzer = AsyncStream<Runner<ImageAnalysis, any Error>>

  let id: UUID

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
    self.bookmarkedItems = []
    self.source = Once {
      @Dependency(\.dataStack) var dataStack

      let ds = try await dataStack()
      let id = try await ds.connection.write { db in
        try DataStackDependencyKey.DataStack.id(db, images: id)
      }

      return ImagesModelSource(dataStack: ds, id: id)
    }
    // Should we set an explicit buffering policy?
    self.resampler = AsyncStream.makeStream()
    self.analyzer = AsyncStream.makeStream()
  }

  static func source(
    url: URL,
    options: FileManager.DirectoryEnumerationOptions
  ) throws -> Source<[URL]> {
    let enumerator: FileManager.DirectoryEnumerationIterator

    do {
      enumerator = try url.accessingSecurityScopedResource {
        try FileManager.default.enumerate(at: url, options: options.union(.skipsPackageDescendants))
      }
    } catch let error as CocoaError where error.code == .fileReadUnknown {
      guard let error = error.underlying as? POSIXError,
            error.code == .ENOTDIR else {
        throw error
      }

      return .source(url)
    }

    return .document(SourceDocument(source: url, items: enumerator.finderSort(by: \.pathComponents)))
  }

  static func submit(
    _ dataStack: DataStackDependencyKey.DataStack,
    info: ImagesInfo,
    items: [Source<[URL]>],
    priority: Int
  ) async throws {
    let options: URL.BookmarkCreationOptions = [.withReadOnlySecurityScope, .withoutImplicitSecurityScope]
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
      try bookmarks.reduce(into: [[(bookmark: BookmarkInfo, item: ImagesItemInfo?)]]()) { vals, source in
        vals.append(try DataStackDependencyKey.DataStack.submit(
          db,
          bookmark: source,
          images: info,
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

  static func submit(
    _ dataStack: DataStackDependencyKey.DataStack,
    images: ImagesInfo,
    item: ImagesItemInfo?
  ) async throws {
    try await dataStack.connection.write { db in
      try DataStackDependencyKey.DataStack.submit(db, images: images, item: item)
    }
  }

  static func submitItemBookmark(
    _ dataStack: DataStackDependencyKey.DataStack,
    item: ImagesItemInfo,
    isBookmarked: Bool
  ) async throws {
    try await dataStack.connection.write { db in
      try DataStackDependencyKey.DataStack.saveImagesItem(db, item: item, isBookmarked: isBookmarked)
    }
  }

  static func resolve(responses: [ImagesItemFetchResponse]) -> [Data: (info: BookmarkInfo, bookmark: DataBookmark, relative: Data?)] {
    Dictionary(grouping: responses) { $0.item.type! }
      .reduce(into: [Data: (info: BookmarkInfo, bookmark: DataBookmark, relative: Data?)]()) { partialResult, entry in
        let (key: type, value: responses) = entry

        switch type {
          case .image: break
          case .bookmark:
            let responses = responses.map { $0.bookmark!.bookmark2 }
            let relatives = responses.compactMap(\.relative).uniqued(on: \.hash)
            var store = [Data: Data](minimumCapacity: relatives.count)
            let rels = relatives
              .compactMap { bookmark -> (bookmark: DataBookmark, options: URL.BookmarkCreationOptions)? in
                let options = bookmark.options!
                let hash = bookmark.hash!
                let resolved: DataBookmark

                do {
                  resolved = try DataBookmark(data: bookmark.data!, options: options, hash: hash, relativeTo: nil)
                } catch {
                  Logger.model.error("Could not resolve bookmark with hash \"\(hash.hexEncodedString())\": \(error, privacy: .public)")

                  return nil
                }

                store[hash] = resolved.hash
                partialResult[resolved.hash] = (info: bookmark, bookmark: resolved, relative: nil)

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

              if let rel = response.relative {
                guard let hash = store[rel.hash!],
                      let rel = partialResult[hash] else {
                  return
                }

                relative = rel.bookmark
              } else {
                relative = nil
              }

              let bookmark = response.bookmark
              let hash = bookmark.hash!
              let resolved: DataBookmark

              do {
                resolved = try DataBookmark(
                  data: bookmark.data!,
                  options: bookmark.options!,
                  hash: hash,
                  relativeTo: relative?.bookmark.url
                )
              } catch {
                Logger.model.error("Could not resolve bookmark with hash \"\(hash.hexEncodedString())\": \(error, privacy: .public)")

                return
              }

              partialResult[resolved.hash] = (info: bookmark, bookmark: resolved, relative: relative?.hash)
            }
        }
      }
  }

  static func update(
    _ dataStack: DataStackDependencyKey.DataStack,
    responses: some Sequence<ImagesItemTrackerResponse> & Sendable
  ) async throws -> [Data: URL] {
    let responses = try await dataStack.connection.read { db in
      try DataStackDependencyKey.DataStack.fetch(db, items: Set(responses.map(\.item)))
    }

    let resolved = Self.resolve(responses: responses)

    try await dataStack.connection.write { db in
      try resolved.values.forEach { entry in
        let (info: info, bookmark: bookmark, relative: relative) = entry
        let book = BookmarkInfo(info, data: bookmark.bookmark.data, options: info.options, hash: bookmark.hash)
        let rel = relative.flatMap { resolved[$0]?.info }

        try DataStackDependencyKey.DataStack.submit(db, bookmark: book, relative: rel)
      }
    }

    // This will contain outdated keys.
    return resolved.mapValues(\.bookmark.bookmark.url)
  }

  static func update(
    _ dataStack: DataStackDependencyKey.DataStack,
    response: ImagesItemsTrackerResponse
  ) async throws -> [Data: URL] {
    var urls = await dataStack.urls
    let fetch = response.items.filter { response in
      switch response.item.type! {
        case .image:
          // The image data must always exist.
          return false
        case .bookmark:
          let response = response.bookmark!.bookmark2

          return ImagesItemModel.document(urls: urls, response: response) == nil
      }
    }

    if !fetch.isEmpty {
      urls = await dataStack.register(urls: try await update(dataStack, responses: fetch))
    }

    return urls
  }

  static func resolve(
    _ dataStack: DataStackDependencyKey.DataStack,
    response: ImagesItemsTrackerResponse
  ) async throws -> [UUID: (document: URLSourceDocument?, data: ImagesItemModelProperties)] {
    let urls = try await Self.update(dataStack, response: response)
    let data = response.items.reduce(into: [UUID: (document: URLSourceDocument?, data: ImagesItemModelProperties)]()) { partialResult, resp in
      let item = resp.item

      switch item.type! {
          // TODO: Implement.
        case .image: break
        case .bookmark:
          let response = resp.bookmark!.bookmark2

          guard let document = ImagesItemModel.document(urls: urls, response: response) else {
            return
          }

          let url = document.source.url
          let data = document.accessingSecurityScopedResource { () -> ImagesItemModelProperties? in
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
              return nil
            }

            let options = [kCGImageSourceShouldCache: false]
            let imageIndex = CGImageSourceGetPrimaryImageIndex(imageSource)

            guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, imageIndex, options as CFDictionary) as? [CFString: Any] else {
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

          partialResult[item.id!] = (document: document, data: data)
      }
    }

    return data
  }

  @MainActor
  private func load(_ dataStack: DataStackDependencyKey.DataStack, response: ImagesItemsTrackerResponse?) async throws {
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
      let id = item.item.id!

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
        info: item.item,
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
  private func load(response: ImagesPropertiesTrackerResponse) {
    itemID = response.item.id
  }

  @MainActor
  private func fetch(
    _ dataStack: DataStackDependencyKey.DataStack,
    from iterator: inout AsyncValueObservation<ImagesItemsTrackerResponse?>.Iterator
  ) async throws -> Bool {
    guard let value = try await iterator.next() else {
      return false
    }

    try await load(dataStack, response: value)

    return true
  }

  @MainActor
  private func fetch(
    from iterator: inout AsyncValueObservation<ImagesPropertiesTrackerResponse?>.Iterator
  ) async throws -> ImagesModelFetchPhase<ImagesPropertiesTrackerResponse> {
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
    from iterator: inout AsyncValueObservation<ImagesItemsTrackerResponse?>.Iterator
  ) async throws -> Bool {
    defer {
      performedItemsFetch = true
    }

    return try await fetch(dataStack, from: &iterator)
  }

  @MainActor
  private func performFetch(
    from iterator: inout AsyncValueObservation<ImagesPropertiesTrackerResponse?>.Iterator
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
        response.item.id.map(incomingItemID.send(_:))

        return true
    }
  }

  @MainActor
  private func track(
    _ dataStack: DataStackDependencyKey.DataStack,
    from iterator: inout AsyncValueObservation<ImagesItemsTrackerResponse?>.Iterator
  ) async throws {
    while try await fetch(dataStack, from: &iterator) {}
  }

  @MainActor
  private func track(
    from iterator: inout AsyncValueObservation<ImagesPropertiesTrackerResponse?>.Iterator
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
    var items = source.dataStack.track(itemsForImages: source.id.images).makeAsyncIterator()

    guard try await performFetch(source.dataStack, from: &items) else {
      return
    }

    // TODO: Decouple properties from items.
    //
    // We currently need to process items first so the UI can be ready to receive the incoming item ID. This should be
    // split so it's sent when both data sources are ready.
    var properties = source.dataStack.track(propertiesForImages: source.id.images).makeAsyncIterator()

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
      info: source.id.images,
      items: items,
      priority: self.items.last?.info.priority ?? -1
    )
  }

  @MainActor
  func submit(currentItem item: ImagesItemModel?) async throws {
    let source = try await source()

    guard let item = item?.info else {
      return
    }

    try await Self.submit(source.dataStack, images: source.id.images, item: item)
  }

  @MainActor
  func submitItemBookmark(item: ImagesItemModel, isBookmarked: Bool) async throws {
    let source = try await source()

    try await Self.submitItemBookmark(source.dataStack, item: item.info, isBookmarked: isBookmarked)
  }
}

extension ImagesModel: Equatable {
  static func ==(lhs: ImagesModel, rhs: ImagesModel) -> Bool {
    lhs.id == rhs.id
  }
}

extension ImagesModel: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension ImagesModel: Codable {
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
