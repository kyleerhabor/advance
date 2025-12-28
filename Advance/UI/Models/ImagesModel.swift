//
//  ImagesModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/12/24.
//

import AdvanceCore
import Algorithms
import AppKit
import AsyncAlgorithms
import BigInt
import Combine
import CoreGraphics
import CryptoKit
import Foundation
import GRDB
import IdentifiedCollections
import ImageIO
import Observation
import OSLog
import SwiftUI
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
  var isBookmarked: Bool

  init(
    id: RowID,
    source: AnyImagesItemModelSource,
    properties: ImagesItemModelProperties,
    isBookmarked: Bool
  ) {
    self.id = id
    self.source = source
    self.properties = properties
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

struct ImagesModelLoadImagesCurrentItemInfo {
  let item: ImagesItemRecord
}

extension ImagesModelLoadImagesCurrentItemInfo: Sendable, Equatable, Decodable, FetchableRecord {}

struct ImagesModelLoadImagesInfo {
  let images: ImagesRecord
  let currentItem: ImagesModelLoadImagesCurrentItemInfo?
  let items: [ImagesModelLoadImagesItemInfo]
}

extension ImagesModelLoadImagesInfo: Decodable {
  enum CodingKeys: CodingKey {
    case images, currentItem, items
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

enum ImagesItemModelImagePhase {
  case empty, success, failure
}

@Observable
@MainActor
final class ImagesItemModel2 {
  let id: RowID
  var url: URL
  var title: String
  var aspectRatio: Double
  var isBookmarked: Bool
  var sidebarImage: NSImage
  var sidebarImagePhase: ImagesItemModelImagePhase
  var detailImage: NSImage
  var detailImageOrientation: CGImagePropertyOrientation
  var detailImageHash: Data
  var detailImagePhase: ImagesItemModelImagePhase
  var imageAnalysis: ImageAnalysis?

  init(
    id: RowID,
    url: URL,
    title: String,
    aspectRatio: Double,
    isBookmarked: Bool,
    sidebarImage: NSImage,
    sidebarImagePhase: ImagesItemModelImagePhase,
    detailImage: NSImage,
    detailImageOrientation: CGImagePropertyOrientation,
    detailImageHash: Data,
    detailImagePhase: ImagesItemModelImagePhase,
    imageAnalysis: ImageAnalysis?,
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.aspectRatio = aspectRatio
    self.isBookmarked = isBookmarked
    self.sidebarImage = sidebarImage
    self.sidebarImagePhase = sidebarImagePhase
    self.detailImage = detailImage
    self.detailImageOrientation = detailImageOrientation
    self.detailImageHash = detailImageHash
    self.detailImagePhase = detailImagePhase
    self.imageAnalysis = imageAnalysis
  }
}

extension ImagesItemModel2: @MainActor Equatable {
  static func ==(lhs: ImagesItemModel2, rhs: ImagesItemModel2) -> Bool {
    lhs.id == rhs.id
  }
}

extension ImagesItemModel2: @MainActor Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

extension ImagesItemModel2: Identifiable {}

struct ImagesModelCopyFolderFileExistsError {
  let source: String
  let destination: String
}

extension ImagesModelCopyFolderFileExistsError: Equatable, Error {}

enum ImagesModelCopyFolderErrorType {
  case fileExists(ImagesModelCopyFolderFileExistsError)
}

extension ImagesModelCopyFolderErrorType: Equatable, Error {}

struct ImagesModelCopyFolderError {
  let locale: Locale
  let type: ImagesModelCopyFolderErrorType
}

extension ImagesModelCopyFolderError: Equatable, Error {}

extension ImagesModelCopyFolderError: LocalizedError {
  var errorDescription: String? {
    switch type {
      case let .fileExists(error):
        String(
          localized: "Images.Item.Folder.Item.Copy.Error.FileExists.Source.\(error.source).Destination.\(error.destination)",
          locale: locale,
        )
    }
  }
}

struct ImagesModelLoadImagesLoadState {
  let items: [RowID: ImagesModelLoadImageImagesItemInfo]
}

struct ImagesModelLoadImagesResampleState {
  var images: [RowID: NSImage]
}

struct ImagesModelLoadImagesResampleChild {
  let bookmark: RowID
  let image: NSImage
}

struct ImagesModelStoreState {
  var bookmarks: [URL: Bookmark]
}

struct ImagesModelCopyFolderLoadItemState {
  let folder: ImagesModelCopyFolderFolderInfo?
  let item: ImagesModelCopyFolderImagesItemInfo?
}

struct ImagesModelCopyFolderLoadState {
  let folder: ImagesModelCopyFolderFolderInfo?
  let items: [RowID: ImagesModelCopyFolderImagesItemInfo]
}

struct ImagesModelLoadDetailsStateItem {
  let item: ImagesItemInfo
  let title: String
  let aspectRatio: Double
}

struct ImagesModelLoadDetailsState {
  var items: [RowID: ImagesModelLoadDetailsStateItem]
}

struct ImagesModelLoadURLState {
  let items: [RowID: ImagesModelLoadURLImagesItemInfo]
}

struct ImagesModelSidebarElement {
  let item: ImagesItemModel2.ID
  let isSelected: Bool
}

struct ImagesModelImageOrientation {
  let image: NSImage
  let orientation: CGImagePropertyOrientation
}

struct ImagesModelLoadImage {
  let hash: Data
  let imageOrientation: ImagesModelImageOrientation
}

@Observable
@MainActor
final class ImagesModel {
  typealias ID = UUID
  typealias Resampler = AsyncStream<Runner<CGImage?, Never>>
  typealias Analyzer = AsyncStream<Runner<ImageAnalysis, any Error>>

  let id: ID
  @ObservationIgnored private var hasLoaded: Bool
  var items: IdentifiedArrayOf<ImagesItemModel2>
  var hasLoadedNoImages: Bool
  var currentItem: ImagesItemModel2?
  var bookmarkedItems: Set<ImagesItemModel2.ID>
  let sidebar: AsyncChannel<ImagesModelSidebarElement>
  let detail: AsyncChannel<ImagesItemModel2.ID>
  @ObservationIgnored private var resolvedItems: Set<ImagesItemModel2.ID>

  var items2: IdentifiedArrayOf<ImagesItemModel>
  var isReady: Bool {
    performedItemsFetch && performedPropertiesFetch
  }
  @ObservationIgnored var resampler: (stream: Resampler, continuation: Resampler.Continuation)
  @ObservationIgnored var analyzer: (stream: Analyzer, continuation: Analyzer.Continuation)
  private var performedItemsFetch = false
  private var performedPropertiesFetch = false

  init(id: UUID) {
    self.id = id
    self.hasLoaded = false
    self.items = []
    self.hasLoadedNoImages = false
    self.bookmarkedItems = []
    self.sidebar = AsyncChannel()
    self.detail = AsyncChannel()
    self.resolvedItems = []

    self.items2 = []
    // Should we set an explicit buffering policy?
    self.resampler = AsyncStream.makeStream()
    self.analyzer = AsyncStream.makeStream()
  }

  func load2() async {
    await _load()
  }

  func loadImage(item: ImagesItemModel2.ID, length: Double) async -> NSImage? {
    await _loadImage(item: item, length: length)
  }

  func loadImages(items: [ImagesItemModel2.ID], width: Double, pixelLength: Double) async {
    await _loadImages(items: items, width: width, pixelLength: pixelLength)
  }

  func loadImageAnalysis(for item: ImagesItemModel2, types: ImageAnalysisTypes) async {
    guard item.detailImagePhase == .success else {
      return
    }

    let analyzer = ImageAnalyzer()
    let analysis: ImageAnalysis?

    do {
      analysis = try await withCheckedThrowingContinuation { continuation in
        Task {
          await analyses.send(Run(continuation: continuation) {
            let configuration = ImageAnalyzer.Configuration(types.analyzerAnalysisTypes)
            // The analysis is performed by mediaanalysisd, so it's not like this is all that expensive.
            let analysis = try await analyzer.analyze(
              item.detailImage,
              orientation: item.detailImageOrientation,
              configuration: configuration,
            )

            return analysis
          })
        }
      }
    } catch {
      // This kind of sucks since the URL may be outdated.
      Logger.model.error("Could not analyze image at file URL '\(item.url.pathString)': \(error)")

      return
    }

    item.imageAnalysis = analysis
  }

  func store(urls: [URL], directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions) async {
    await _store(urls: urls, directoryEnumerationOptions: directoryEnumerationOptions)
  }

  func store(items: [ImagesItemTransfer], enumerationOptions: FileManager.DirectoryEnumerationOptions) async {
    await _store(items: items, enumerationOptions: enumerationOptions)
  }

  func isInvalidSelection(of items: Set<ImagesItemModel2.ID>) -> Bool {
    items.isEmpty
  }

  func showFinder(item: ImagesItemModel2.ID) async {
    await _showFinder(item: item)
  }

  func showFinder(items: Set<ImagesItemModel2.ID>) async {
    await _showFinder(items: items)
  }

  // This should be async, but is a consequence of View.copyable(_:) only accepting a synchronous closure.
  func urls(ofItems items: Set<ImagesItemModel2.ID>) -> [URL] {
    // We don't want partial results.
    guard items.isNonEmptySubset(of: resolvedItems) else {
      return []
    }

    return items.map { self.items[id: $0]!.url }
  }

  func copy(item: ImagesItemModel2.ID) async {
    await _copy(item: item)
  }

  func copy(items: Set<ImagesItemModel2.ID>) async {
    await _copy(items: items)
  }

  func copyFolder(
    item: ImagesItemModel2.ID?,
    to folder: FoldersSettingsItemModel,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    try await _copyFolder(
      item: item,
      to: folder.id,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
  }

  func copyFolder(
    item: ImagesItemModel2.ID?,
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    try await _copyFolder(
      item: item,
      to: folder,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
  }

  func copyFolder(
    items: [ImagesItemModel2.ID],
    to folder: FoldersSettingsItemModel,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    try await _copyFolder(
      items: items,
      to: folder.id,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
  }

  func copyFolder(
    items: [ImagesItemModel2.ID],
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    try await _copyFolder(
      items: items,
      to: folder,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathSeparator: pathSeparator,
      pathDirection: pathDirection,
    )
  }

  func isBookmarked(items: Set<ImagesItemModel2.ID>) -> Bool {
    items.isNonEmptySubset(of: bookmarkedItems)
  }

  func bookmark(item: ImagesItemModel2.ID, isBookmarked: Bool) async {
    if isBookmarked {
      bookmarkedItems.insert(item)
    } else {
      bookmarkedItems.remove(item)
    }

    self.items[id: item]!.isBookmarked = isBookmarked

    await _bookmark(item: item, isBookmarked: isBookmarked)
  }

  func bookmark(items: Set<ImagesItemModel2.ID>, isBookmarked: Bool) async {
    if isBookmarked {
      bookmarkedItems.formUnion(items)
    } else {
      bookmarkedItems.subtract(items)
    }

    items.forEach { item in
      self.items[id: item]!.isBookmarked = isBookmarked
    }

    await _bookmark(items: items, isBookmarked: isBookmarked)
  }

  func setCurrentItem(item: ImagesItemModel2?) async {
    self.currentItem = item

    await _setCurrentItem(item: item?.id)
  }

  nonisolated private func orientationImageProperty(data: [CFString : Any]) -> CGImagePropertyOrientation? {
    guard let value = data[kCGImagePropertyOrientation] as? UInt32 else {
      return .identity
    }

    guard let orientation = CGImagePropertyOrientation(rawValue: value) else {
      return nil
    }

    return orientation
  }

  nonisolated private func sizeOrientation(at url: URL, data: [CFString : Any]) -> SizeOrientation? {
    guard let pixelWidth = data[kCGImagePropertyPixelWidth] as? Double else {
      Logger.model.fault("Properties of image source at file URL '\(url.pathString)' has no pixel width")

      return nil
    }

    guard let pixelHeight = data[kCGImagePropertyPixelHeight] as? Double else {
      Logger.model.fault("Properties of image source at file URL '\(url.pathString)' has no pixel height")

      return nil
    }

    guard let orientation = orientationImageProperty(data: data) else {
      Logger.model.fault("Properties of image source at file URL '\(url.pathString)' has invalid orientation")

      return nil
    }

    return SizeOrientation(
      size: CGSize(width: pixelWidth, height: pixelHeight),
      orientation: orientation,
    )
  }

  nonisolated private func load(connection: DatabasePool, images: ImagesModelLoadImagesInfo?) async {
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

    let state2 = await withTaskGroup(of: ImagesModelLoadDetailsStateItem?.self) { group in
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
          let item = relative.accessingSecurityScopedResource { () -> ImagesModelLoadDetailsStateItem? in
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

              guard let copyProperties = CGImageSourceCopyPropertiesAtIndex(
                      imageSource,
                      CGImageSourceGetPrimaryImageIndex(imageSource),
                      options as CFDictionary,
                    ) else {
                Logger.model.error("Could not copy properties of image source at file URL '\(source.url.pathString)'")

                return nil
              }

              guard let sizeOrientation = self.sizeOrientation(at: source.url, data: copyProperties as! [CFString: Any]) else {
                return nil
              }

              let size = sizeOrientation.orientedSize

              return ImagesModelLoadDetailsStateItem(item: item, title: title, aspectRatio: size.width / size.height)
            }
          }

          return item
        }
      }

      return await group.reduce(
        into: ImagesModelLoadDetailsState(items: Dictionary(minimumCapacity: images.items.count)),
      ) { partialResult, child in
        guard let child else {
          return
        }

        partialResult.items[child.item.item.rowID!] = child
      }
    }

    Task { @MainActor in
      self.items = IdentifiedArray(
        uniqueElements: images.items
          .compactMap { imagesItem in
            let id = imagesItem.item.rowID!

            if let item = self.items[id: id] {
              guard let item2 = state2.items[id] else {
                // TODO: Log.
                return item
              }

              let bookmark = state1.bookmarks[imagesItem.fileBookmark.bookmark.bookmark.rowID!]!
              item.url = bookmark.resolved.url
              item.title = item2.title
              item.aspectRatio = item2.aspectRatio
              item.isBookmarked = item2.item.item.isBookmarked!

              return item
            }

            guard let item2 = state2.items[id] else {
              // TODO: Log.
              return nil
            }

            let bookmark = state1.bookmarks[imagesItem.fileBookmark.bookmark.bookmark.rowID!]!

            return ImagesItemModel2(
              id: id,
              url: bookmark.resolved.url,
              title: item2.title,
              aspectRatio: item2.aspectRatio,
              isBookmarked: item2.item.item.isBookmarked!,
              sidebarImage: NSImage(),
              sidebarImagePhase: .empty,
              detailImage: NSImage(),
              detailImageOrientation: .identity,
              detailImageHash: Data(),
              detailImagePhase: .empty,
              imageAnalysis: nil,
            )
          }
      )

      if !self.hasLoaded {
        self.currentItem = images.currentItem.flatMap { self.items[id: $0.item.rowID!] }
      }

      self.hasLoaded = true
      self.hasLoadedNoImages = self.items.isEmpty
      self.bookmarkedItems = Set(self.items.filter(\.isBookmarked).map(\.id))
      self.resolvedItems = Set(self.items.filter { state2.items[$0.id] != nil }.map(\.id))
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
          .including(
            optional: ImagesRecord.currentItem
              .forKey(ImagesModelLoadImagesInfo.CodingKeys.currentItem)
              .select(.rowID),
          )
          .asRequest(of: ImagesModelLoadImagesInfo.self)
          .fetchOne(db)
      }
      .removeDuplicates { a, b in
        switch (a, b) {
          case (nil, nil):
            true
          case (nil, .some):
            false
          case (.some, nil):
            false
          case (.some(let a), .some(let b)):
            // currentItem is loaded once and set by setCurrentItem(item:), so we don't need to load images again if it
            // changes. If we wanted to get rid of removeDuplicates(by:), we could cache items so bookmarks and images
            // aren't re-computed. I'd prefer that be the implementation, but diagnosing the performance in this async
            // code is not easy.
            a.images == b.images && a.items == b.items && a.currentItem != b.currentItem
        }
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
      for try await images in observation.values(in: connection, bufferingPolicy: .bufferingNewest(1)) {
        await load(connection: connection, images: images)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func loadImage(url: URL, length: Double) -> NSImage? {
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      // TODO: Log.
      return nil
    }

    let index = CGImageSourceGetPrimaryImageIndex(imageSource)
    let options = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: length,
      // TODO: Document.
      kCGImageSourceCreateThumbnailWithTransform: true,
    ] as [CFString : Any]

    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, index, options as CFDictionary) else {
      // TODO: Log.
      return nil
    }

    return NSImage(cgImage: thumbnail, size: .zero)
  }

  nonisolated private func loadImage(at url: URL, width: Double, pixelLength: Double) -> ImagesModelImageOrientation? {
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      Logger.model.error("Could not create image source for file URL '\(url.pathString)'")

      return nil
    }

    let index = CGImageSourceGetPrimaryImageIndex(imageSource)
    let copyPropertiesOptions = [
      kCGImageSourceShouldCache: true,
      kCGImageSourceShouldCacheImmediately: true,
    ] as [CFString: Any]

    guard let copyProperties = CGImageSourceCopyPropertiesAtIndex(
            imageSource,
            index,
            copyPropertiesOptions as CFDictionary,
          ) else {
      Logger.model.error("Could not copy properties of image source at file URL '\(url.pathString)'")

      return nil
    }

    guard let sizeOrientation = sizeOrientation(at: url, data: copyProperties as! [CFString: Any]) else {
      return nil
    }

    let sized = sizeOrientation.orientedSize
    let height = width * (sized.height / sized.width)
    let length = max(width, height) / pixelLength
    let thumbnailCreationOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: length,
      kCGImageSourceCreateThumbnailWithTransform: true,
    ] as [CFString : Any]

    // This is memory-intensive, so it shouldn't be called from a task group with a variable number of child tasks.
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
            imageSource,
            index,
            thumbnailCreationOptions as CFDictionary,
          ) else {
      Logger.model.error("Could not create thumbnail at pixel size '\(length)' for image source at file URL '\(url.pathString)'")

      return nil
    }

    return ImagesModelImageOrientation(
      image: NSImage(cgImage: thumbnail, size: .zero),
      orientation: sizeOrientation.orientation,
    )
  }

  nonisolated private func _loadImage(item: ImagesItemModel2.ID, length: Double) async -> NSImage? {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    let imagesItem: ImagesModelLoadImageImagesItemInfo?

    do {
      imagesItem = try await connection.read { db in
        try ImagesItemRecord
          .select(.rowID)
          .filter(key: item)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelLoadImageImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadImageImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadImageImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadImageImagesItemInfo.self)
          .fetchOne(db)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    guard let item = imagesItem else {
      return nil
    }

    let assigned = assign(bookmark: item.fileBookmark.bookmark.bookmark, relative: item.fileBookmark.relative?.relative)

    do {
      try await connection.write { db in
        if let rel = item.fileBookmark.relative {
          try write(db, bookmark: rel.relative, assigned: assigned?.relative)
        }

        try write(db, bookmark: item.fileBookmark.bookmark.bookmark, assigned: assigned?.bookmark)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    guard let assigned else {
      return nil
    }

    let source = source(
      assigned: assigned,
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.relative,
    )

    let image = source.accessingSecurityScopedResource {
      loadImage(url: source.source.url, length: length)
    }

    return image
  }

  nonisolated private func loadImage(
    state: ImagesItemAssignment,
    item: ImagesItemInfo,
    width: Double,
    pixelLength: Double,
  ) -> ImagesModelLoadImage? {
    let relative: URLSource?

    do {
      relative = try state.relative(item.fileBookmark.relative)
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    let id = item.fileBookmark.bookmark.bookmark.rowID!

    guard let bookmark = state.bookmarks[id] else {
      return nil
    }

    let document = URLSourceDocument(
      source: URLSource(url: bookmark.resolved.url, options: item.fileBookmark.bookmark.bookmark.options!),
      relative: relative,
    )

    return document.accessingSecurityScopedResource {
      guard let stream = InputStream(url: document.source.url) else {
        Logger.model.error("Could not create input stream at file URL '\(document.source.url.pathString)'")

        return nil
      }

      stream.open()

      defer {
        stream.close()
      }

      let capacity = 65536 // 2^16
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)

      defer {
        buffer.deallocate()
      }

      var hasher = SHA256()

      while stream.hasBytesAvailable {
        let result = stream.read(buffer, maxLength: capacity)

        guard result != -1 else {
          Logger.model.error("Could not read input stream at file URL '\(document.source.url.pathString)': \(stream.streamError)")

          return nil
        }

        hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: result))
      }

      let hash = Data(hasher.finalize())

      guard let imageOrientation = self.loadImage(at: document.source.url, width: width, pixelLength: pixelLength) else {
        return nil
      }

      return ImagesModelLoadImage(hash: hash, imageOrientation: imageOrientation)
    }
  }

  nonisolated private func _loadImages(items: [ImagesItemModel2.ID], width: Double, pixelLength: Double) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state1: ImagesModelLoadImagesLoadState

    do {
      state1 = try await connection.read { db in
        let items = try ImagesItemRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelLoadImageImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadImageImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadImageImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadImageImagesItemInfo.self)
          .fetchCursor(db)

        let state = ImagesModelLoadImagesLoadState(
          items: try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) }),
        )

        return state
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let items2 = items.map { item in
      let item = state1.items[item]!

      return ImagesItemInfo(
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

    var state2 = ImagesItemAssignment()
    await state2.assign(items: items2)

    do {
      try await connection.write { [state2] db in
        try state2.write(db, items: items2)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    for item in items2 {
      let result = loadImage(state: state2, item: item, width: width, pixelLength: pixelLength)

      await MainActor.run {
        let imagesItem = self.items[id: item.item.rowID!]!

        guard let result else {
          imagesItem.detailImage = imagesItem.detailImage
          imagesItem.detailImageHash = imagesItem.detailImageHash
          imagesItem.detailImagePhase = .failure

          return
        }

        imagesItem.detailImage = result.imageOrientation.image
        imagesItem.detailImageHash = result.hash
        imagesItem.detailImagePhase = .success
      }
    }

    let items = Set(items)

    Task { @MainActor in
      self.items.forEach { item in
        guard !items.contains(item.id) else {
          return
        }

        item.detailImage = NSImage()
        item.detailImageHash = Data()
        item.detailImagePhase = .empty
      }
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
        // FIXME: Don't reset currentItem.
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

              let position = position + delta(lowerBound: position, upperBound: .one, base: .TEN)
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

                let position = position + delta(lowerBound: position, upperBound: .one, base: .TEN)
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

  nonisolated private func assign(bookmark: BookmarkRecord, relative: BookmarkRecord?) -> AssignedBookmarkDocument? {
    // If relative is resolved while bookmark isn't, this will send notifications for both. This isn't the best design,
    // but it's not the worst, either, since we'll be notified of the region changing, rather than of the individual
    // bookmarks. As a result, returning nil instead of, say, nil for the property, has no visible effect on the
    // application, which is flexible.

    if let r = relative {
      let relative: AssignedBookmark

      do {
        relative = try AssignedBookmark(data: r.data!, options: r.options!, relativeTo: nil)
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return nil
      }

      let source = URLSource(url: relative.resolved.url, options: [])
      let assigned: AssignedBookmark

      do {
        assigned = try source.accessingSecurityScopedResource {
          try AssignedBookmark(data: bookmark.data!, options: bookmark.options!, relativeTo: relative.resolved.url)
        }
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return nil
      }

      return AssignedBookmarkDocument(bookmark: assigned, relative: relative)
    }

    let assigned: AssignedBookmark

    do {
      assigned = try AssignedBookmark(data: bookmark.data!, options: bookmark.options!, relativeTo: nil)
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    return AssignedBookmarkDocument(bookmark: assigned, relative: nil)
  }

  nonisolated private func source(
    assigned: AssignedBookmarkDocument,
    bookmark: BookmarkRecord,
    relative: BookmarkRecord?,
  ) -> URLSourceDocument {
    let rel: URLSource?

    if let relative {
      // If relative is non-nil, assigned.relative should be non-nil, too, because assign(bookmark:relative:) returns
      // nil for cases where resolving relative fails.
      rel = URLSource(url: assigned.relative!.resolved.url, options: relative.options!)
    } else {
      rel = nil
    }

    return URLSourceDocument(
      source: URLSource(url: assigned.bookmark.resolved.url, options: bookmark.options!),
      relative: rel,
    )
  }

  nonisolated private func loadURL(forItem item: ImagesItemModel2.ID) async -> URLSourceDocument? {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    let imagesItem: ImagesModelLoadURLImagesItemInfo?

    do {
      imagesItem = try await connection.read { db in
        try ImagesItemRecord
          .select(.rowID)
          .filter(key: item)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelLoadURLImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadURLImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadURLImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadURLImagesItemInfo.self)
          .fetchOne(db)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    guard let item = imagesItem else {
      return nil
    }

    let assigned = assign(bookmark: item.fileBookmark.bookmark.bookmark, relative: item.fileBookmark.relative?.relative)

    do {
      try await connection.write { db in
        if let rel = item.fileBookmark.relative {
          try write(db, bookmark: rel.relative, assigned: assigned?.relative)
        }

        try write(db, bookmark: item.fileBookmark.bookmark.bookmark, assigned: assigned?.bookmark)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    guard let assigned else {
      return nil
    }

    return source(
      assigned: assigned,
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.relative,
    )
  }

  nonisolated private func loadURLs(forItems items: Set<ImagesItemModel2.ID>) async -> [URL]? {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    let state1: ImagesModelLoadURLState

    do {
      state1 = try await connection.read { db in
        let items = try ImagesItemRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelLoadURLImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadURLImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadURLImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadURLImagesItemInfo.self)
          .fetchCursor(db)

        let state = ImagesModelLoadURLState(
          items: try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) }),
        )

        return state
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    let items2 = items.map { item in
      let item = state1.items[item]!

      return ImagesItemInfo(
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

    var state2 = ImagesItemAssignment()
    await state2.assign(items: items2)

    do {
      try await connection.write { [state2] db in
        try state2.write(db, items: items2)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    return items
      .compactMap { state1.items[$0] }
      .compactMap { state2.bookmarks[$0.fileBookmark.bookmark.bookmark.rowID!]?.resolved.url }
  }

  nonisolated private func _showFinder(items: Set<ImagesItemModel2.ID>) async {
    guard let urls = await loadURLs(forItems: items) else {
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }

  nonisolated private func _showFinder(item: ImagesItemModel2.ID) async {
    guard let document = await loadURL(forItem: item) else {
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting([document.source.url])
  }

  nonisolated private func _copy(item: ImagesItemModel2.ID) async {
    guard let item = await loadURL(forItem: item) else {
      return
    }

    NSPasteboard.general.prepareForNewContents()
    NSPasteboard.general.writeObjects([item.source.url as NSURL])
  }

  nonisolated private func _copy(items: Set<ImagesItemModel2.ID>) async {
    guard let urls = await loadURLs(forItems: items) else {
      return
    }

    NSPasteboard.general.prepareForNewContents()
    NSPasteboard.general.writeObjects(urls as [NSURL])
  }

  nonisolated private func copyFolder(
    item: URL,
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) throws(ImagesModelCopyFolderError) {
    // I've no idea whether or not this contains characters that are invalid for file paths.
    guard let components = FileManager.default.componentsToDisplay(
      forPath: item.deletingLastPathComponent().pathString,
    ) else {
      // TODO: Log.
      return
    }

    let lastPathComponent = item.lastPathComponent

    do {
      // TODO: Don't use lastPathComponent.
      do {
        try FileManager.default.copyItem(
          at: item,
          to: folder.appending(component: lastPathComponent, directoryHint: .notDirectory),
        )
      } catch let error as CocoaError where error.code == .fileWriteFileExists {
        guard resolveConflicts else {
          throw error
        }

        // TODO: Interpolate separator
        //
        // Given that localization supports this, I think it should be safe to assume that a collection of
        // path components can be strung together by a common separator (in English, a space) embedding the
        // true separator (say, an inequality sign).
        let separator = switch (pathSeparator, pathDirection) {
          case (.inequalitySign, .leading):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.InequalitySign.LeftToLeft",
              locale: locale,
            )
          case (.inequalitySign, .trailing):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.InequalitySign.RightToLeft",
              locale: locale,
            )
          case (.singlePointingAngleQuotationMark, .leading):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.SinglePointingAngleQuotationMark.LeftToRight",
              locale: locale,
            )
          case (.singlePointingAngleQuotationMark, .trailing):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.SinglePointingAngleQuotationMark.RightToLeft",
              locale: locale,
            )
          case (.blackPointingTriangle, .leading):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.BlackPointingTriangle.LeftToRight",
              locale: locale,
            )
          case (.blackPointingTriangle, .trailing):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.BlackPointingTriangle.RightToLeft",
              locale: locale,
            )
          case (.blackPointingSmallTriangle, .leading):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.BlackPointingSmallTriangle.LeftToRight",
              locale: locale,
            )
          case (.blackPointingSmallTriangle, .trailing):
            String(
              localized: "Images.Item.Folder.Item.Copy.Path.Separator.BlackPointingSmallTriangle.RightToLeft",
              locale: locale,
            )
        }

        let pathComponents = components
          .reversed()
          .reductions(into: []) { $0.append($1) }
          .dropFirst() // The initial reduction (an empty array)

        for pathComponents in pathComponents {
          let path = pathComponents.joined(separator: separator)
          let component = String(
            localized: "Images.Item.Folder.Item.Copy.Name.\(item.deletingPathExtension().lastPathComponent).Path.\(path)",
            locale: locale,
          )

          do {
            try FileManager.default.copyItem(
              at: item,
              to: folder
                .appending(component: component, directoryHint: .notDirectory)
                .appendingPathExtension(item.pathExtension),
            )
          } catch let error as CocoaError where error.code == .fileWriteFileExists {
            continue
          } catch {
            // TODO: Elaborate.
            Logger.model.error("\(error)")

            return
          }

          return
        }

        throw error
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }
    } catch {
      throw ImagesModelCopyFolderError(
        locale: locale,
        type: .fileExists(ImagesModelCopyFolderFileExistsError(
          source: lastPathComponent,
          destination: folder.lastPathComponent,
        )),
      )
    }
  }

  nonisolated private func _copyFolder(
    item: ImagesItemModel2.ID?,
    to folder: FoldersSettingsItemModel.ID,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    guard let item else {
      return
    }

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state: ImagesModelCopyFolderLoadItemState

    do {
      state = try await connection.read { db in
        let folder = try FolderRecord
          .select(.rowID)
          .filter(key: folder)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(ImagesModelCopyFolderFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelCopyFolderFolderFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelCopyFolderFolderInfo.self)
          .fetchOne(db)

        let item = try ImagesItemRecord
          .select(.rowID)
          .filter(key: item)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelCopyFolderImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelCopyFolderImagesItemInfo.self)
          .fetchOne(db)

        return ImagesModelCopyFolderLoadItemState(folder: folder, item: item)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let folder = state.folder,
          let item = state.item else {
      // TODO: Log.
      return
    }

    let options = folder.fileBookmark.bookmark.bookmark.options!
    let assignedFolder: AssignedBookmark?

    do {
      assignedFolder = try AssignedBookmark(
        data: folder.fileBookmark.bookmark.bookmark.data!,
        options: options,
        relativeTo: nil,
      )
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      assignedFolder = nil
    }

    let assignedItem = assign(bookmark: item.fileBookmark.bookmark.bookmark, relative: item.fileBookmark.relative?.relative)

    do {
      try await connection.write { db in
        try write(db, bookmark: folder.fileBookmark.bookmark.bookmark, assigned: assignedFolder)

        if let rel = item.fileBookmark.relative {
          try write(db, bookmark: rel.relative, assigned: assignedItem?.relative)
        }

        try write(db, bookmark: item.fileBookmark.bookmark.bookmark, assigned: assignedItem?.bookmark)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let assignedFolder,
          let assignedItem else {
      return
    }

    let folderSource = URLSource(url: assignedFolder.resolved.url, options: options)
    let itemSource = self.source(
      assigned: assignedItem,
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.relative,
    )

    try folderSource.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
      try itemSource.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
        try copyFolder(
          item: itemSource.source.url,
          to: folderSource.url,
          locale: locale,
          resolveConflicts: resolveConflicts,
          pathSeparator: pathSeparator,
          pathDirection: pathDirection,
        )
      }
    }
  }

  nonisolated private func _copyFolder(
    item: ImagesItemModel2.ID?,
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    guard let item else {
      return
    }

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let imagesItem: ImagesModelCopyFolderImagesItemInfo?

    do {
      imagesItem = try await connection.read { db in
        try ImagesItemRecord
          .select(.rowID)
          .filter(key: item)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelCopyFolderImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelCopyFolderImagesItemInfo.self)
          .fetchOne(db)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let item = imagesItem else {
      // TODO: Log.
      return
    }

    let assigned = assign(bookmark: item.fileBookmark.bookmark.bookmark, relative: item.fileBookmark.relative?.relative)

    do {
      try await connection.write { db in
        if let rel = item.fileBookmark.relative {
          try write(db, bookmark: rel.relative, assigned: assigned?.relative)
        }

        try write(db, bookmark: item.fileBookmark.bookmark.bookmark, assigned: assigned?.bookmark)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let assigned else {
      return
    }

    let itemSource = self.source(
      assigned: assigned,
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.relative,
    )

    try folder.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
      try itemSource.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
        try copyFolder(
          item: itemSource.source.url,
          to: folder,
          locale: locale,
          resolveConflicts: resolveConflicts,
          pathSeparator: pathSeparator,
          pathDirection: pathDirection,
        )
      }
    }
  }

  nonisolated private func _copyFolder(
    items: [ImagesItemModel2.ID],
    to folder: FoldersSettingsItemModel.ID,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let state1: ImagesModelCopyFolderLoadState

    do {
      state1 = try await connection.read { db in
        let folder = try FolderRecord
          .select(.rowID)
          .filter(key: folder)
          .including(
            required: FolderRecord.fileBookmark
              .forKey(ImagesModelCopyFolderFolderInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelCopyFolderFolderFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelCopyFolderFolderInfo.self)
          .fetchOne(db)

        let items = try ImagesItemRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelCopyFolderImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelCopyFolderImagesItemInfo.self)
          .fetchCursor(db)

        return ImagesModelCopyFolderLoadState(
          folder: folder,
          items: try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) }),
        )
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let folder = state1.folder else {
      // TODO: Log.
      return
    }

    let options = folder.fileBookmark.bookmark.bookmark.options!
    let bookmark: AssignedBookmark?

    do {
      bookmark = try AssignedBookmark(
        data: folder.fileBookmark.bookmark.bookmark.data!,
        options: options,
        relativeTo: nil,
      )
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      bookmark = nil
    }

    let items = items.map { item in
      let item = state1.items[item]!

      return ImagesItemInfo(
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

    var state2 = ImagesItemAssignment()
    await state2.assign(items: items)

    do {
      try await connection.write { [state2] db in
        try write(db, bookmark: folder.fileBookmark.bookmark.bookmark, assigned: bookmark)
        try state2.write(db, items: items)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    guard let bookmark else {
      return
    }

    let source = URLSource(url: bookmark.resolved.url, options: options)
    try source.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
      do {
        try items.forEach { item in
          let relative: URLSource?

          do {
            relative = try state2.relative(item.fileBookmark.relative)
          } catch {
            // TODO: Elaborate.
            Logger.model.error("\(error)")

            return
          }

          guard let bookmark = state2.bookmarks[item.fileBookmark.bookmark.bookmark.rowID!] else {
            return
          }

          let itemSource = URLSourceDocument(
            source: URLSource(url: bookmark.resolved.url, options: item.fileBookmark.bookmark.bookmark.options!),
            relative: relative,
          )

          try itemSource.accessingSecurityScopedResource {
            try copyFolder(
              item: itemSource.source.url,
              to: source.url,
              locale: locale,
              resolveConflicts: resolveConflicts,
              pathSeparator: pathSeparator,
              pathDirection: pathDirection,
            )
          }
        }
      } catch {
        throw error as! ImagesModelCopyFolderError
      }
    }
  }

  nonisolated private func _copyFolder(
    items: [ImagesItemModel2.ID],
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathSeparator: StorageFoldersPathSeparator,
    pathDirection: StorageFoldersPathDirection,
  ) async throws(ImagesModelCopyFolderError) {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    // TODO: De-duplicate.
    let items2: [RowID: ImagesModelCopyFolderImagesItemInfo]

    do {
      items2 = try await connection.read { db in
        let items = try ImagesItemRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelCopyFolderImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelCopyFolderImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelCopyFolderImagesItemInfo.self)
          .fetchCursor(db)

        return try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) })
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let items3 = items.map { item in
      let item = items2[item]!

      return ImagesItemInfo(
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

    var state2 = ImagesItemAssignment()
    await state2.assign(items: items3)

    do {
      try await connection.write { [state2] db in
        try state2.write(db, items: items3)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    try folder.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
      do {
        try items3.forEach { item in
          let relative: URLSource?

          do {
            relative = try state2.relative(item.fileBookmark.relative)
          } catch {
            // TODO: Elaborate.
            Logger.model.error("\(error)")

            return
          }

          guard let bookmark = state2.bookmarks[item.fileBookmark.bookmark.bookmark.rowID!] else {
            return
          }

          let itemSource = URLSourceDocument(
            source: URLSource(url: bookmark.resolved.url, options: item.fileBookmark.bookmark.bookmark.options!),
            relative: relative,
          )

          try itemSource.accessingSecurityScopedResource {
            try copyFolder(
              item: itemSource.source.url,
              to: folder,
              locale: locale,
              resolveConflicts: resolveConflicts,
              pathSeparator: pathSeparator,
              pathDirection: pathDirection,
            )
          }
        }
      } catch {
        throw error as! ImagesModelCopyFolderError
      }
    }
  }

  nonisolated private func _bookmark(item: ImagesItemModel2.ID, isBookmarked: Bool) async {
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
        let item = ImagesItemRecord(rowID: item, position: nil, isBookmarked: isBookmarked, fileBookmark: nil)
        try item.update(db, columns: [ImagesItemRecord.Columns.isBookmarked])
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func _bookmark(items: Set<ImagesItemModel2.ID>, isBookmarked: Bool) async {
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
        try items.forEach { item in
          let item = ImagesItemRecord(rowID: item, position: nil, isBookmarked: isBookmarked, fileBookmark: nil)
          try item.update(db, columns: [ImagesItemRecord.Columns.isBookmarked])
        }
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func _setCurrentItem(item: ImagesItemModel2.ID?) async {
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
        let rowID = try ImagesRecord
          .filter(key: [ImagesRecord.Columns.id.name: id])
          .selectPrimaryKey(as: RowID.self)
          .fetchOne(db)

        guard let rowID else {
          var images = ImagesRecord(id: id, currentItem: item)
          try images.insert(db)

          return
        }

        let images = ImagesRecord(rowID: rowID, id: nil, currentItem: item)
        try images.update(db, columns: [ImagesRecord.Columns.currentItem])
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  // MARK: - Old

  private func loadRunGroups() async throws {
    var resampler = resampler.stream.makeAsyncIterator()
    var analyzer = analyzer.stream.makeAsyncIterator()

    async let resamplerRunGroup: () = run(limit: 8, iterator: &resampler)
    async let analyzerRunGroup: () = run(limit: 10, iterator: &analyzer)
    _ = try await [resamplerRunGroup, analyzerRunGroup]
  }

  @MainActor
  func load() async throws {
    try await loadRunGroups()
  }
}

extension ImagesModel: @MainActor Equatable {
  static func ==(lhs: ImagesModel, rhs: ImagesModel) -> Bool {
    lhs.id == rhs.id
  }
}

extension ImagesModel: @MainActor Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
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
    try container.encode(self.id)
  }
}
