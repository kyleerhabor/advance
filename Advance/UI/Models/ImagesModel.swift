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
import Foundation
import GRDB
import IdentifiedCollections
import ImageIO
import Observation
import OSLog
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

extension URL {
  static let imagesDirectory = Self.dataDirectory.appending(component: "Images", directoryHint: .isDirectory)
}

@Observable
final class ImagesItemModel {
  let id: RowID
  // A generic parameter would be nice, but heavily infects views as a consequence.
  var isBookmarked: Bool

  init(id: RowID, isBookmarked: Bool) {
    self.id = id
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

struct ImagesItemModelImageParameters {
  let width: CGFloat
}

extension ImagesItemModelImageParameters: Equatable {}

struct ImagesItemModelImageAnalysisParameters {
  let types: ImageAnalysisTypes
  let width: CGFloat
}

extension ImagesItemModelImageAnalysisParameters: Equatable {}

@Observable
@MainActor
final class ImagesItemModel2 {
  let id: RowID
  var url: URL
  var title: String
  var isBookmarked: Bool
  var edge: VerticalEdge.Set
  var sidebarAspectRatio: CGFloat
  var sidebarImage: NSImage
  var sidebarImagePhase: ImagesItemModelImagePhase
  @ObservationIgnored var sidebarImageParameters: ImagesItemModelImageParameters
  var detailAspectRatio: CGFloat
  var detailImage: NSImage
  var detailImagePhase: ImagesItemModelImagePhase
  @ObservationIgnored var detailImageParameters: ImagesItemModelImageParameters
  var imageAnalysis: ImageAnalysis?
  @ObservationIgnored var imageAnalysisParameters: ImagesItemModelImageAnalysisParameters
  var isImageAnalysisSelectableItemsHighlighted: Bool

  init(
    id: RowID,
    url: URL,
    title: String,
    isBookmarked: Bool,
    edge: VerticalEdge.Set,
    sidebarAspectRatio: CGFloat,
    sidebarImage: NSImage,
    sidebarImagePhase: ImagesItemModelImagePhase,
    sidebarImageParameters: ImagesItemModelImageParameters,
    detailAspectRatio: CGFloat,
    detailImage: NSImage,
    detailImagePhase: ImagesItemModelImagePhase,
    detailImageParameters: ImagesItemModelImageParameters,
    imageAnalysis: ImageAnalysis?,
    imageAnalysisParameters: ImagesItemModelImageAnalysisParameters,
    selectableItemsHighlighted: Bool,
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.isBookmarked = isBookmarked
    self.edge = edge
    self.sidebarAspectRatio = sidebarAspectRatio
    self.sidebarImage = sidebarImage
    self.sidebarImagePhase = sidebarImagePhase
    self.sidebarImageParameters = sidebarImageParameters
    self.detailAspectRatio = detailAspectRatio
    self.detailImage = detailImage
    self.detailImagePhase = detailImagePhase
    self.detailImageParameters = detailImageParameters
    self.imageAnalysis = imageAnalysis
    self.imageAnalysisParameters = imageAnalysisParameters
    self.isImageAnalysisSelectableItemsHighlighted = selectableItemsHighlighted
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
  let items: [RowID: ImagesModelLoadImagesImagesItemInfo]
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
  let aspectRatio: CGFloat
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

struct ImagesModelEngineURLInvalidLocationError {
  let name: String
  let query: String
}

enum ImagesModelEngineURLErrorType {
  case invalidLocation(ImagesModelEngineURLInvalidLocationError)
}

struct ImagesModelEngineURLError {
  let locale: Locale
  let type: ImagesModelEngineURLErrorType
}

extension ImagesModelEngineURLError: LocalizedError {
  var errorDescription: String? {
    switch type {
      case let .invalidLocation(error):
        String(
          localized: "Images.Item.SearchEngine.Item.URL.Error.InvalidLocation.Name.\(error.name).Query.\(error.query)",
          locale: locale,
        )
    }
  }

  var recoverySuggestion: String? {
    switch type {
      case .invalidLocation:
        String(
          localized: "Images.Item.SearchEngine.Item.URL.Error.InvalidLocation.Name.Query.RecoverySuggestion",
          locale: locale,
        )
    }
  }
}

@MainActor
struct ImagesModelResample {
  let width: CGFloat
  let items: [ImagesItemModel2]
}

extension ImagesModelResample: @MainActor Equatable {}

// TODO: Remove.
//
// We know the code path at program time, so this is pointless.
enum ImagesModelLoadImagesColumn {
  case sidebar, detail
}

@Observable
@MainActor
final class ImagesModel {
  typealias ID = UUID

  let id: ID
  var items: IdentifiedArrayOf<ImagesItemModel2>
  var sidebarItems: IdentifiedArrayOf<ImagesItemModel2>
  var bookmarkedItems: Set<ImagesItemModel2.ID>
  var restoredItem: ImagesItemModel2?
  var hasLoadedNoImages: Bool
  @ObservationIgnored let hoverChannel: AsyncChannel<Bool>
  @ObservationIgnored let sidebar: AsyncChannel<ImagesModelSidebarElement>
  @ObservationIgnored let detail: AsyncChannel<ImagesItemModel2.ID>
  @ObservationIgnored let visibleItemsChannel: AsyncChannel<[ImagesItemModel2]>
  @ObservationIgnored let detailResample: AsyncChannel<ImagesModelResample>
  @ObservationIgnored let detailImageAnalysis: AsyncChannel<ImagesModelResample>
  @ObservationIgnored let sidebarResample: AsyncChannel<ImagesModelResample>
  @ObservationIgnored private var resolvedItems: Set<ImagesItemModel2.ID>

  // MARK: - UI properties
  var isBookmarked: Bool
  var currentItem: ImagesItemModel2?
  var visibleItems: [ImagesItemModel2]
  var isHighlighted: Bool

  // MARK: - Old properties
  var items2: IdentifiedArrayOf<ImagesItemModel>
  var isReady: Bool {
    performedItemsFetch && performedPropertiesFetch
  }

  private var performedItemsFetch = false
  private var performedPropertiesFetch = false

  init(id: UUID) {
    self.id = id
    self.items = []
    self.sidebarItems = []
    self.bookmarkedItems = []
    self.hasLoadedNoImages = false
    self.hoverChannel = AsyncChannel()
    self.sidebar = AsyncChannel()
    self.detail = AsyncChannel()
    self.visibleItemsChannel = AsyncChannel()
    self.detailResample = AsyncChannel()
    self.detailImageAnalysis = AsyncChannel()
    self.sidebarResample = AsyncChannel()
    self.resolvedItems = []
    self.isBookmarked = false
    self.visibleItems = []
    self.isHighlighted = false

    self.items2 = []
  }

  func load() async {
    await _load()
  }

  func loadBookmarks() {
    self.loadBookmarkResults()
  }

  func loadImages(
    in column: ImagesModelLoadImagesColumn,
    items: [ImagesItemModel2],
    parameters: ImagesItemModelImageParameters,
  ) async {
    await self._loadImages(
      in: column,
      items: items
        .filter { item in
          switch column {
            case .sidebar:
              item.sidebarImagePhase != .success || item.sidebarImageParameters != parameters
            case .detail:
              item.detailImagePhase != .success || item.detailImageParameters != parameters
          }
        }
        .map(\.id),
      parameters: parameters,
    )

    self.items.forEach { item in
      guard !items.contains(item) else {
        return
      }

      switch column {
        case .sidebar:
          item.sidebarImage = NSImage()
          item.sidebarImagePhase = .empty
        case .detail:
          item.detailImage = NSImage()
          item.detailImagePhase = .empty
      }
    }
  }

  func loadImageAnalyses(
    for items: [ImagesItemModel2],
    parameters: ImagesItemModelImageAnalysisParameters
  ) async {
    await self.loadImageAnalyses(
      for: items
        .filter { $0.imageAnalysis == nil || $0.imageAnalysisParameters != parameters }
        .map(\.id),
      parameters: parameters,
    )

    self.items.forEach { item in
      guard !items.contains(item) else {
        return
      }

      item.imageAnalysis = nil
    }
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
    items.isNonEmptySubset(of: self.bookmarkedItems)
  }

  func bookmark(item: ImagesItemModel2, isBookmarked: Bool) async {
    item.isBookmarked = isBookmarked

    self.loadBookmarkResults()
    await self._bookmark(item: item.id, isBookmarked: isBookmarked)
  }

  func bookmark(items: Set<ImagesItemModel2.ID>, isBookmarked: Bool) async {
    items.forEach { item in
      self.items[id: item]!.isBookmarked = isBookmarked
    }

    self.loadBookmarkResults()
    await self._bookmark(items: items, isBookmarked: isBookmarked)
  }

  func setCurrentItem(item: ImagesItemModel2?) async {
    self.currentItem = item
    await _setCurrentItem(item: item?.id)
  }

  func url(
    engine: SearchSettingsEngineModel.ID,
    query: String,
    locale: Locale,
  ) async throws(ImagesModelEngineURLError) -> URL? {
    try await _url(engine: engine, query: query, locale: locale)
  }

  func highlight(items: [ImagesItemModel2], isHighlighted: Bool) {
    items.forEach(setter(on: \.isImageAnalysisSelectableItemsHighlighted, value: isHighlighted))
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

  private func loadResults() {
    hasLoadedNoImages = true
  }

  private func loadBookmarkResults() {
    let bookmarkItems = self.items.filter(\.isBookmarked)
    self.sidebarItems = self.isBookmarked ? bookmarkItems : self.items
    self.bookmarkedItems = Set(bookmarkItems.ids)
  }

  private func loadResults(
    images: ImagesModelLoadImagesInfo,
    assigned: ImagesItemAssignment,
    details: ImagesModelLoadDetailsState,
  ) {
    self.items = IdentifiedArray(
      uniqueElements: images.items
        .compactMap { imagesItem in
          let id = imagesItem.item.rowID!

          if let item = self.items[id: id] {
            item.edge = []

            guard let item2 = details.items[id] else {
              // TODO: Log.
              return item
            }

            let bookmark = assigned.bookmarks[imagesItem.fileBookmark.bookmark.bookmark.rowID!]!
            item.url = bookmark.resolved.url
            item.title = item2.title
            item.isBookmarked = item2.item.item.isBookmarked!

            return item
          }

          guard let item2 = details.items[id] else {
            // TODO: Log.
            return nil
          }

          let bookmark = assigned.bookmarks[imagesItem.fileBookmark.bookmark.bookmark.rowID!]!

          return ImagesItemModel2(
            id: id,
            url: bookmark.resolved.url,
            title: item2.title,
            isBookmarked: item2.item.item.isBookmarked!,
            edge: [],
            sidebarAspectRatio: item2.aspectRatio,
            sidebarImage: NSImage(),
            sidebarImagePhase: .empty,
            sidebarImageParameters: ImagesItemModelImageParameters(width: .nan),
            detailAspectRatio: item2.aspectRatio,
            detailImage: NSImage(),
            detailImagePhase: .empty,
            detailImageParameters: ImagesItemModelImageParameters(width: .nan),
            imageAnalysis: nil,
            imageAnalysisParameters: ImagesItemModelImageAnalysisParameters(types: [], width: .nan),
            selectableItemsHighlighted: false,
          )
        }
    )

    self.items.first?.edge.insert(.top)
    self.items.last?.edge.insert(.bottom)
    self.loadBookmarkResults()

    self.restoredItem = images.currentItem.flatMap { self.items[id: $0.item.rowID!] }
    self.hasLoadedNoImages = self.items.isEmpty
    self.resolvedItems = Set(self.items.filter { details.items[$0.id] != nil }.map(\.id))
  }

  nonisolated private func load(connection: DatabasePool, images: ImagesModelLoadImagesInfo?) async {
    guard let images else {
      await loadResults()

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
          let document: URLSourceDocument?

          do {
            document = try state1.document(fileBookmark: item.fileBookmark)
          } catch let error as ImagesItemAssignmentError {
            switch error {
              case .unresolvedRelative: break
            }

            return nil
          } catch {
            unreachable()
          }

          guard let document else {
            return nil
          }

          let item = document.accessingSecurityScopedResource { () -> ImagesModelLoadDetailsStateItem? in
            let resourceValues: URLResourceValues

            do {
              resourceValues = try document.source.url.resourceValues(
                forKeys: [.localizedNameKey, .hasHiddenExtensionKey],
              )
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

            let title = isExtensionHidden
              ? name
              : URL(filePath: name, directoryHint: .notDirectory).deletingPathExtension().lastPathComponent

            guard let imageSource = CGImageSourceCreateWithURL(document.source.url as CFURL, nil) else {
              // TODO: Log.
              return nil
            }

            let options = [kCGImageSourceShouldCache: false]

            guard let copyProperties = CGImageSourceCopyPropertiesAtIndex(
              imageSource,
              CGImageSourceGetPrimaryImageIndex(imageSource),
              options as CFDictionary,
            ) else {
              Logger.model.error(
                "Could not copy properties of image source at file URL '\(document.source.url.pathString)'",
              )

              return nil
            }

            guard let sizeOrientation = self.sizeOrientation(
                    at: document.source.url,
                    data: copyProperties as! [CFString: Any],
                  ) else {
              return nil
            }

            let size = sizeOrientation.orientedSize

            return ImagesModelLoadDetailsStateItem(item: item, title: title, aspectRatio: size.width / size.height)
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

    await loadResults(images: images, assigned: state1, details: state2)
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
      .removeDuplicates()

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection for image collection '\(self.id)': \(error)")

      return
    }

    do {
      for try await images in observation.values(in: connection, bufferingPolicy: .bufferingNewest(1)) {
        await load(connection: connection, images: images)
      }
    } catch {
      Logger.model.error("Could not observe values for image collection '\(self.id)': \(error)")

      return
    }
  }

  nonisolated private func createImageSource(at url: URL) -> CGImageSource? {
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      Logger.model.error("Could not create image source for file URL '\(url.pathString)'")

      return nil
    }

    return imageSource
  }

  nonisolated private func imageSizeOrientation(source: CGImageSource, at index: Int, url: URL) -> SizeOrientation? {
    let copyPropertiesOptions = [
      kCGImageSourceShouldCache: true,
      kCGImageSourceShouldCacheImmediately: true,
    ] as [CFString: Any]

    guard let copyProperties = CGImageSourceCopyPropertiesAtIndex(
      source,
      index,
      copyPropertiesOptions as CFDictionary,
    ) else {
      Logger.model.error("Could not copy properties of image source at file URL '\(url.pathString)'")

      return nil
    }

    let sizeOrientation = self.sizeOrientation(at: url, data: copyProperties as! [CFString: Any])

    return sizeOrientation
  }

  nonisolated private func createThumbnail(
    source: CGImageSource,
    at index: Int,
    length: CGFloat,
    size: CGSize,
    url: URL,
  ) -> NSImage? {
    let thumbnailCreationOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: length,
      kCGImageSourceCreateThumbnailWithTransform: true,
    ] as [CFString : Any]

    // This is CPU and memory-intensive, so it shouldn't be called from a task group with a variable number of child tasks.
    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
      source,
      index,
      thumbnailCreationOptions as CFDictionary,
    ) else {
      Logger.model.error("Could not create thumbnail at pixel size \(length) for image source at file URL '\(url.pathString)'")

      return nil
    }

    Logger.model.debug(
      """
      Created thumbnail at pixel size \(length) for image source at file URL '\(url.pathString)': \
      \(size.width) x \(size.height) -> \(thumbnail.width) x \(thumbnail.height)
      """
    )

    return NSImage(cgImage: thumbnail, size: .zero)
  }

  private func loadImage(
    item: ImagesItemInfo,
    column: ImagesModelLoadImagesColumn,
    parameters: ImagesItemModelImageParameters,
    image: NSImage?,
  ) {
    guard let imagesItem = self.items[id: item.item.rowID!] else {
      return
    }

    guard let image else {
      switch column {
        case .sidebar:
          imagesItem.sidebarImagePhase = .failure
        case .detail:
          imagesItem.detailImagePhase = .failure
      }

      return
    }

    switch column {
      case .sidebar:
        imagesItem.sidebarAspectRatio = image.size.width / image.size.height
        imagesItem.sidebarImage = image
        imagesItem.sidebarImagePhase = .success
        imagesItem.sidebarImageParameters = parameters
      case .detail:
        imagesItem.detailAspectRatio = image.size.width / image.size.height
        imagesItem.detailImage = image
        imagesItem.detailImagePhase = .success
        imagesItem.detailImageParameters = parameters
    }
  }

  nonisolated private func loadImage(
    state: ImagesItemAssignment,
    item: ImagesItemInfo,
    column: ImagesModelLoadImagesColumn,
    parameters: ImagesItemModelImageParameters,
  ) async {
    let document: URLSourceDocument?

    do {
      document = try state.document(fileBookmark: item.fileBookmark)
    } catch {
      switch error {
        case .unresolvedRelative: break
      }

      return
    }

    guard let document else {
      return
    }

    let image = document.accessingSecurityScopedResource { () -> NSImage? in
      guard let imageSource = self.createImageSource(at: document.source.url) else {
        return nil
      }

      let index = CGImageSourceGetPrimaryImageIndex(imageSource)

      guard let sizeOrientation = self.imageSizeOrientation(source: imageSource, at: index, url: document.source.url) else {
        return nil
      }

      let size = sizeOrientation.orientedSize
      let image = self.createThumbnail(
        source: imageSource,
        at: index,
        length: size.scale(width: parameters.width).length,
        size: size,
        url: document.source.url,
      )

      return image
    }

    await self.loadImage(item: item, column: column, parameters: parameters, image: image)
  }

  nonisolated private func _loadImages(
    in column: ImagesModelLoadImagesColumn,
    items: [RowID],
    parameters: ImagesItemModelImageParameters,
  ) async {
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
              .forKey(ImagesModelLoadImagesImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadImagesImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadImagesImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadImagesImagesItemInfo.self)
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
      await self.loadImage(state: state2, item: item, column: column, parameters: parameters)
    }
  }

  private func loadImageAnalysis(
    item: ImagesItemInfo,
    imageOrientation: ImagesModelImageOrientation,
    parameters: ImagesItemModelImageAnalysisParameters,
    url: URL,
  ) async {
    let analysis: ImageAnalysis

    do {
      analysis = try await withCheckedThrowingContinuation { continuation in
        Task {
          await analyses.send(Run(continuation: continuation) {
            let analyzer = ImageAnalyzer()
            // The analysis is performed by mediaanalysisd, so this call isn't holding up the main actor.
            let measured = try await ContinuousClock.continuous.measure {
              try await analyzer.analyze(
                imageOrientation.image,
                orientation: imageOrientation.orientation,
                configuration: ImageAnalyzer.Configuration(parameters.types.analyzerAnalysisTypes),
              )
            }

            Logger.model.debug("Took \(measured.duration) to analyze image at file URL '\(url.pathString)'")

            return measured.value
          })
        }
      }
    } catch {
      Logger.model.error("Could not analyze image at file URL '\(url.pathString)': \(error)")

      return
    }

    guard let item = self.items[id: item.item.rowID!] else {
      return
    }

    item.imageAnalysis = analysis
    item.imageAnalysisParameters = parameters
  }

  nonisolated private func loadImageAnalysis(
    state: ImagesItemAssignment,
    item: ImagesItemInfo,
    parameters: ImagesItemModelImageAnalysisParameters,
  ) async {
    let document: URLSourceDocument?

    do {
      document = try state.document(fileBookmark: item.fileBookmark)
    } catch {
      switch error {
        case .unresolvedRelative: break
      }

      return
    }

    guard let document else {
      return
    }

    let imageOrientation = document.accessingSecurityScopedResource { () -> ImagesModelImageOrientation? in
      guard let imageSource = self.createImageSource(at: document.source.url) else {
        return nil
      }

      let index = CGImageSourceGetPrimaryImageIndex(imageSource)

      guard let sizeOrientation = self.imageSizeOrientation(
        source: imageSource,
        at: index,
        url: document.source.url,
      ) else {
        return nil
      }

      let size = sizeOrientation.orientedSize
      let len = size.scale(width: parameters.width).length
      let length = min(len, ImageAnalyzer.maxLength.decremented())

      guard let image = self.createThumbnail(
              source: imageSource,
              at: index,
              length: length,
              size: size,
              url: document.source.url,
            ) else {
        return nil
      }

      let imageOrientation = ImagesModelImageOrientation(image: image, orientation: sizeOrientation.orientation)

      return imageOrientation
    }

    guard let imageOrientation else {
      return
    }

    await self.loadImageAnalysis(
      item: item,
      imageOrientation: imageOrientation,
      parameters: parameters,
      url: document.source.url,
    )
  }

  nonisolated private func loadImageAnalyses(
    for items: [RowID],
    parameters: ImagesItemModelImageAnalysisParameters,
  ) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection for image analysis: \(error)")

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
              .forKey(ImagesModelLoadImagesImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadImagesImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadImagesImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadImagesImagesItemInfo.self)
          .fetchCursor(db)

        let state = ImagesModelLoadImagesLoadState(
          items: try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) }),
        )

        return state
      }
    } catch {
      Logger.model.error("Could not read from database for image analysis: \(error)")

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
      Logger.model.error("Could not write to database for image analysis: \(error)")

      return
    }

    for item in items2 {
      await self.loadImageAnalysis(state: state2, item: item, parameters: parameters)
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

  nonisolated private func store(items: [Item<URLSource>]) async {
    let state1 = await withThrowingTaskGroup(of: Item<URLBookmark>.self) { group in
      var state = ImagesModelStoreState(bookmarks: [:])

      items.forEach { item in
        group.addTask {
          switch item {
            case let .file(source):
              let bookmark = try await source.accessingSecurityScopedResource {
                try await URLBookmark(url: source.url, options: source.options, relativeTo: nil)
              }

              return .file(bookmark)
            case let .directory(directory):
              return try await directory.item.accessingSecurityScopedResource {
                let bookmark = try await URLBookmark(
                  url: directory.item.url,
                  options: directory.item.options,
                  relativeTo: nil,
                )

                let files = await withThrowingTaskGroup { group in
                  var items = [URLBookmark](reservingCapacity: directory.files.count)

                  directory.files.forEach { source in
                    group.addTask {
                      try await source.accessingSecurityScopedResource {
                        try await URLBookmark(url: source.url, options: source.options, relativeTo: bookmark.url)
                      }
                    }
                  }

                  while let result = await group.nextResult() {
                    switch result {
                      case let .success(child):
                        items.append(child)
                      case let .failure(error):
                        // TODO: Elaborate.
                        Logger.model.error("\(error)")
                    }
                  }

                  return items
                }

                return .directory(ItemDirectory(item: bookmark, files: files))
              }
          }
        }
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
      let source = URLSource(url: url, options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])

      do {
        let files = try source.accessingSecurityScopedResource {
          try FileManager.default
            .enumerate(at: source.url, options: directoryEnumerationOptions)
            .finderSort(by: \.pathComponents)
            .map { URLSource(url: $0, options: .withoutImplicitSecurityScope) }
        }

        return .directory(ItemDirectory(item: source, files: files))
      } catch {
        guard case let .iterationFailed(error) = error as? FileManagerDirectoryEnumerationError,
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
                .map { URLSource(url: $0, options: .withoutImplicitSecurityScope) }
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
    relative: BookmarkRecord?,
  ) -> URLSource? {
    guard let relative else {
      return nil
    }

    let source = URLSource(url: assigned.relative!.resolved.url, options: relative.options!)

    return source
  }

  nonisolated private func document(
    assigned: AssignedBookmarkDocument,
    bookmark: BookmarkRecord,
    relative: BookmarkRecord?,
  ) -> URLSourceDocument {
    URLSourceDocument(
      source: URLSource(url: assigned.bookmark.resolved.url, options: bookmark.options!),
      relative: self.source(assigned: assigned, relative: relative),
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

    return document(
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
      assignedFolder = try await AssignedBookmark(
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
    let document = self.document(
      assigned: assignedItem,
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.relative,
    )

    try folderSource.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
      try document.accessingSecurityScopedResource { () throws(ImagesModelCopyFolderError) in
        try copyFolder(
          item: document.source.url,
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

    let itemSource = self.document(
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
      bookmark = try await AssignedBookmark(
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
          let document: URLSourceDocument?

          do {
            document = try state2.document(fileBookmark: item.fileBookmark)
          } catch let error as ImagesItemAssignmentError {
            switch error {
              case .unresolvedRelative: break
            }

            return
          } catch {
            unreachable()
          }

          guard let document else {
            return
          }

          try document.accessingSecurityScopedResource {
            try copyFolder(
              item: document.source.url,
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
          let document: URLSourceDocument?

          do {
            document = try state2.document(fileBookmark: item.fileBookmark)
          } catch let error as ImagesItemAssignmentError {
            switch error {
              case .unresolvedRelative: break
            }

            return
          } catch {
            unreachable()
          }

          guard let document else {
            return
          }

          try document.accessingSecurityScopedResource {
            try copyFolder(
              item: document.source.url,
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

  nonisolated private func _bookmark(item: RowID, isBookmarked: Bool) async {
    let connection = try! await databaseConnection()

    do {
      try await connection.write { db in
        let item = ImagesItemRecord(rowID: item, position: nil, isBookmarked: isBookmarked, fileBookmark: nil)
        try item.update(db, columns: [ImagesItemRecord.Columns.isBookmarked])
      }
    } catch {
      Logger.model.error("Could not write to database for item bookmark: \(error)")

      return
    }
  }

  nonisolated private func _bookmark(items: Set<ImagesItemModel2.ID>, isBookmarked: Bool) async {
    let connection = try! await databaseConnection()

    do {
      try await connection.write { db in
        try items.forEach { item in
          let item = ImagesItemRecord(rowID: item, position: nil, isBookmarked: isBookmarked, fileBookmark: nil)
          try item.update(db, columns: [ImagesItemRecord.Columns.isBookmarked])
        }
      }
    } catch {
      Logger.model.error("Could not write to database for bookmarks of items: \(error)")

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

  nonisolated private func _url(
    engine: RowID,
    query: String,
    locale: Locale,
  ) async throws(ImagesModelEngineURLError) -> URL? {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection for search engine URL: \(error)")

      return nil
    }

    let searchEngine: ImagesModelEngineURLSearchEngineInfo?

    do {
      searchEngine = try await connection.read { db in
        try SearchEngineRecord
          .select(.rowID, SearchEngineRecord.Columns.name, SearchEngineRecord.Columns.location)
          .filter(key: engine)
          .asRequest(of: ImagesModelEngineURLSearchEngineInfo.self)
          .fetchOne(db)
      }
    } catch {
      Logger.model.error("Could not read database for search engine URL: \(error)")

      return nil
    }

    guard let searchEngine else {
      Logger.model.error("Could not find search engine '\(engine)'")

      return nil
    }

    let tokens = SearchSettingsItemModel
      .tokenize(searchEngine.searchEngine.location!)
      .map { token in
        switch token {
          case SearchSettingsItemModel.queryToken: query
          default: token
        }
      }

    guard let url = URL(string: SearchSettingsItemModel.detokenize(tokens)) else {
      throw ImagesModelEngineURLError(
        locale: locale,
        type: .invalidLocation(
          ImagesModelEngineURLInvalidLocationError(name: searchEngine.searchEngine.name!, query: query),
        ),
      )
    }

    return url
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
