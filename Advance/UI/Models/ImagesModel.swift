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

  var count: Int {
    switch self {
      case .file:
        1
      case let .directory(directory):
        1 + directory.files.count
    }
  }
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

struct ImagesItemModelImageParameters {
  let width: CGFloat
}

extension ImagesItemModelImageParameters: Equatable {}

struct ImagesItemModelImageAnalysisParameters {
  let width: CGFloat
  let types: ImageAnalysisTypes
}

extension ImagesItemModelImageAnalysisParameters: Equatable {}

enum ImagesItemModelImagePhase {
  case empty, success, failure
}

@Observable
@MainActor
final class ImagesItemImageModel {
  var image: NSImage
  var phase: ImagesItemModelImagePhase
  var aspectRatio: CGFloat

  init(image: NSImage, phase: ImagesItemModelImagePhase, aspectRatio: CGFloat) {
    self.image = image
    self.phase = phase
    self.aspectRatio = aspectRatio
  }
}

@Observable
@MainActor
final class ImagesItemModel2 {
  let id: RowID
  var url: URL
  var title: String
  var isBookmarked: Bool
  var edge: VerticalEdge.Set
  let sidebarImage: ImagesItemImageModel
  @ObservationIgnored var sidebarImageParameters: ImagesItemModelImageParameters
  let detailImage: ImagesItemImageModel
  @ObservationIgnored var detailImageParameters: ImagesItemModelImageParameters
  var imageAnalysis: ImageAnalysis?
  var imageAnalysisID: UUID
  @ObservationIgnored var imageAnalysisParameters: ImagesItemModelImageAnalysisParameters
  var isImageAnalysisSelectableItemsHighlighted: Bool

  init(
    id: RowID,
    url: URL,
    title: String,
    isBookmarked: Bool,
    edge: VerticalEdge.Set,
    sidebarImage: ImagesItemImageModel,
    sidebarImageParameters: ImagesItemModelImageParameters,
    detailImage: ImagesItemImageModel,
    detailImageParameters: ImagesItemModelImageParameters,
    imageAnalysis: ImageAnalysis?,
    imageAnalysisID: UUID,
    imageAnalysisParameters: ImagesItemModelImageAnalysisParameters,
    isImageAnalysisSelectableItemsHighlighted: Bool,
  ) {
    self.id = id
    self.url = url
    self.title = title
    self.isBookmarked = isBookmarked
    self.edge = edge
    self.sidebarImage = sidebarImage
    self.sidebarImageParameters = sidebarImageParameters
    self.detailImage = detailImage
    self.detailImageParameters = detailImageParameters
    self.imageAnalysis = imageAnalysis
    self.imageAnalysisID = imageAnalysisID
    self.imageAnalysisParameters = imageAnalysisParameters
    self.isImageAnalysisSelectableItemsHighlighted = isImageAnalysisSelectableItemsHighlighted
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
  let items: [RowID: ImagesModelLoadDocumentImagesItemInfo]
}

struct ImagesModelSidebarElement {
  let item: ImagesItemModel2.ID
  let isSelected: Bool
}

struct ImagesModelEngineURLInvalidLocationError {
  let name: String
  let query: String
}

extension ImagesModelEngineURLInvalidLocationError: Equatable {}

enum ImagesModelEngineURLErrorType {
  case invalidLocation(ImagesModelEngineURLInvalidLocationError)
}

extension ImagesModelEngineURLErrorType: Equatable {}

struct ImagesModelEngineURLError {
  let locale: Locale
  let type: ImagesModelEngineURLErrorType
}

extension ImagesModelEngineURLError: Equatable {}

extension ImagesModelEngineURLError: LocalizedError {
  var errorDescription: String? {
    switch self.type {
      case let .invalidLocation(error):
        String(
          localized: "Images.Item.SearchEngine.Item.URL.Error.InvalidLocation.Name.\(error.name).Query.\(error.query)",
          locale: self.locale,
        )
    }
  }

  var recoverySuggestion: String? {
    switch self.type {
      case .invalidLocation:
        String(
          localized: "Images.Item.SearchEngine.Item.URL.Error.InvalidLocation.Name.Query.RecoverySuggestion",
          locale: self.locale,
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

struct ImagesModelLoadImageAnalysis {
  let image: ImageOrientation
  let url: URL
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
  @ObservationIgnored var visibleItemsNeedsScroll: Bool
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
    self.visibleItemsNeedsScroll = true
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

  func loadSidebarImages(items: [ImagesItemModel2], parameters: ImagesItemModelImageParameters) async {
    do {
      try await self.loadSidebarImages(
        items: items
          .filter { $0.sidebarImage.phase != .success || $0.sidebarImageParameters != parameters }
          .map(\.id),
        parameters: parameters,
      )
    } catch is CancellationError {
      // Fallthrough
    } catch {
      unreachable()
    }

    self.items.forEach { item in
      guard !items.contains(item) else {
        return
      }

      item.sidebarImage.image = NSImage()
      item.sidebarImage.phase = .empty
      item.detailImageParameters = ImagesItemModelImageParameters(width: .nan)
    }
  }

  func loadDetailImages(items: [ImagesItemModel2], parameters: ImagesItemModelImageParameters) async {
    do {
      try await self.loadDetailImages(
        items: items
          .filter { $0.detailImage.phase != .success || $0.detailImageParameters != parameters }
          .map(\.id),
        parameters: parameters,
      )
    } catch is CancellationError {
      // Fallthrough
    } catch {
      unreachable()
    }

    self.items.forEach { item in
      guard !items.contains(item) else {
        return
      }

      item.detailImage.image = NSImage()
      item.detailImage.phase = .empty
      item.detailImageParameters = ImagesItemModelImageParameters(width: .nan)
    }
  }

  func loadImageAnalyses(
    for items: [ImagesItemModel2],
    parameters: ImagesItemModelImageAnalysisParameters
  ) async {
    do {
      try await self.loadImageAnalyses(
        for: items
          .filter { $0.imageAnalysis == nil || $0.imageAnalysisParameters != parameters }
          .map(\.id),
        parameters: parameters,
      )
    } catch is CancellationError {
      // Fallthrough
    } catch {
      unreachable()
    }

    self.items.forEach { item in
      guard !items.contains(item) else {
        return
      }

      if item.imageAnalysis != nil {
        item.imageAnalysis = nil
        item.imageAnalysisID = UUID()
      }

      item.imageAnalysisParameters = ImagesItemModelImageAnalysisParameters(width: .nan, types: [])
      item.isImageAnalysisSelectableItemsHighlighted = false
    }
  }

  func store(urls: [URL], directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions) async {
    await _store(urls: urls, directoryEnumerationOptions: directoryEnumerationOptions)
  }

  func store(items: [ImagesItemTransfer], directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions) async {
    await _store(items: items, directoryEnumerationOptions: directoryEnumerationOptions)
  }

  // FIXME: Storing an item may result in double entries where the difference is whether or not the resource requires a security scope.
  //
  // The only solution I can think of is comparing the URL, but we'd need to resolve them, somehow (whether via URL/init(resolvingBookmarkData:options:relativeTo:bookmarkDataIsStale:),
  // URL/resourceValues(forKeys:fromBookmarkData:), storing the path in the database, etc.).
  func store(
    items: [URL],
    before: ImagesItemModel2?,
    directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions,
  ) async {
    await self.store(items: items, before: before?.id, directoryEnumerationOptions: directoryEnumerationOptions)
  }

  func store(items: [ImagesItemModel2], before: ImagesItemModel2?) async {
    await self.store(items: items.map(\.id), before: before?.id)
  }

  func remove(items: [ImagesItemModel2]) async {
    // If we wanted to make this instant in the UI, we'd need to update a number of dependent variables, and I can't be
    // asked to do that manually. Maybe there's a system to do this for us (besides method calls, of course).
    await self.remove(items: items.map(\.id))
  }

  func isInvalidSelection(of items: Set<ImagesItemModel2.ID>) -> Bool {
    items.isEmpty
  }

  func showFinder(item: ImagesItemModel2) async {
    await self.showFinder(item: item.id)
  }

  func showFinder(items: [ImagesItemModel2]) async {
    await self.showFinder(items: items.map(\.id))
  }

  // This should be async, but is a consequence of View.copyable(_:) only accepting a synchronous closure.
  func urls(ofItems items: Set<ImagesItemModel2.ID>) -> [URL] {
    // We don't want partial results.
    guard items.isNonEmptySubset(of: resolvedItems) else {
      return []
    }

    return items.map { self.items[id: $0]!.url }
  }

  func copy(item: ImagesItemModel2) async {
    await self.copy(item: item.id)
  }

  func copy(items: [ImagesItemModel2]) async {
    await self.copy(items: items.map(\.id))
  }

  func copyFolder(
    item: ImagesItemModel2,
    to folder: FoldersSettingsItemModel,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
  ) async throws(ImagesModelCopyFolderError) {
    try await self.copyFolder(
      item: item.id,
      to: folder.id,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathDirection: pathDirection,
      pathSeparator: pathSeparator,
    )
  }

  func copyFolder(
    item: ImagesItemModel2,
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
  ) async throws(ImagesModelCopyFolderError) {
    try await self.copyFolder(
      item: item.id,
      to: folder,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathDirection: pathDirection,
      pathSeparator: pathSeparator,
    )
  }

  func copyFolder(
    items: [ImagesItemModel2],
    to folder: FoldersSettingsItemModel,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
  ) async throws(ImagesModelCopyFolderError) {
    try await self.copyFolder(
      items: items.map(\.id),
      to: folder.id,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathDirection: pathDirection,
      pathSeparator: pathSeparator,
    )
  }

  func copyFolder(
    items: [ImagesItemModel2],
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
  ) async throws(ImagesModelCopyFolderError) {
    try await self.copyFolder(
      items: items.map(\.id),
      to: folder,
      locale: locale,
      resolveConflicts: resolveConflicts,
      pathDirection: pathDirection,
      pathSeparator: pathSeparator,
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

  nonisolated private func orientationImageProperty(data: [CFString: Any]) -> CGImagePropertyOrientation? {
    guard let value = data[kCGImagePropertyOrientation] as? UInt32 else {
      return .identity
    }

    guard let orientation = CGImagePropertyOrientation(rawValue: value) else {
      return nil
    }

    return orientation
  }

  nonisolated private func sizeOrientation(at url: URL, data: [CFString: Any]) -> SizeOrientation? {
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
            sidebarImage: ImagesItemImageModel(image: NSImage(), phase: .empty, aspectRatio: item2.aspectRatio),
            sidebarImageParameters: ImagesItemModelImageParameters(width: .nan),
            detailImage: ImagesItemImageModel(image: NSImage(), phase: .empty, aspectRatio: item2.aspectRatio),
            detailImageParameters: ImagesItemModelImageParameters(width: .nan),
            imageAnalysis: nil,
            imageAnalysisID: UUID(),
            imageAnalysisParameters: ImagesItemModelImageAnalysisParameters(width: .nan, types: []),
            isImageAnalysisSelectableItemsHighlighted: false,
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

            guard let imageSource = self.createImageSource(at: document.source.url) else {
              return nil
            }

            let options = [kCGImageSourceShouldCache: false]

            guard let copyProperties = CGImageSourceCopyPropertiesAtIndex(
                    imageSource,
                    // For some file formats (e.g., GIF), this reads the whole file, airing out the disk.
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

  nonisolated private func loadImage(
    parameters: ImagesItemModelImageParameters,
    document: URLSourceDocument,
  ) async throws -> ImageOrientation? {
    try Task.checkCancellation()

    // I've noticed that some memory is retained when closing windows. The Allocations instrument points at this
    // function, but weak/unowned self doesn't eliminate, e.g., CGImageSourceCreateThumbnailAtIndex(_:_:_:), from the
    // call tree, which confuses me.
    let image = await run(on: resamples) {
      document.accessingSecurityScopedResource {
        guard let imageSource = self.createImageSource(at: document.source.url) else {
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
        let length = size.scale(width: parameters.width).length
        let createThumbnailOptions = [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: length,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as [CFString: Any]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                imageSource,
                index,
                createThumbnailOptions as CFDictionary,
              ) else {
          Logger.model.error(
            """
            Could not create thumbnail at pixel size \(length) for image source at file URL \
            '\(document.source.url.pathString)'
            """,
          )

          return nil
        }

        Logger.model.debug(
          """
          Created thumbnail at pixel size \(length) for image source at file URL '\(document.source.url.pathString)': \
          \(size.width) x \(size.height) -> \(thumbnail.width) x \(thumbnail.height)
          """
        )

        let image = ImageOrientation(image: thumbnail, orientation: sizeOrientation.orientation)

        return image
      }
    }

    return image
  }

  nonisolated private func loadImage(
    item: RowID,
    parameters: ImagesItemModelImageParameters,
    documents: [RowID: URLSourceDocument],
  ) async throws -> NSImage? {
    guard let document = documents[item],
          let image = try await self.loadImage(parameters: parameters, document: document) else {
      return nil
    }

    return NSImage(cgImage: image.image, size: .zero)
  }

  private func loadSidebarImage(item: ImagesItemModel2.ID, parameters: ImagesItemModelImageParameters, image: NSImage?) {
    guard let item = self.items[id: item] else {
      return
    }

    guard let image else {
      item.sidebarImage.phase = .failure

      return
    }

    item.sidebarImage.image = image
    item.sidebarImage.phase = .success
    item.sidebarImage.aspectRatio = image.size.width / image.size.height
    item.sidebarImageParameters = parameters
  }

  private func loadDetailImage(item: ImagesItemModel2.ID, parameters: ImagesItemModelImageParameters, image: NSImage?) {
    guard let item = self.items[id: item] else {
      return
    }

    guard let image else {
      item.detailImage.phase = .failure

      return
    }

    let aspectRatio = image.size.width / image.size.height
    item.detailImage.image = image
    item.detailImage.phase = .success
    item.detailImage.aspectRatio = aspectRatio
    item.detailImageParameters = parameters
  }

  nonisolated private func loadSidebarImages(items: [RowID], parameters: ImagesItemModelImageParameters) async throws {
    guard let documents = await self.loadDocuments(for: items) else {
      return
    }

    for item in items {
      await self.loadSidebarImage(
        item: item,
        parameters: parameters,
        image: try await self.loadImage(item: item, parameters: parameters, documents: documents),
      )
    }
  }

  nonisolated private func loadDetailImages(items: [RowID], parameters: ImagesItemModelImageParameters) async throws {
    try Task.checkCancellation()

    guard let documents = await self.loadDocuments(for: items) else {
      return
    }

    for item in items {
      await self.loadDetailImage(
        item: item,
        parameters: parameters,
        image: try await self.loadImage(item: item, parameters: parameters, documents: documents),
      )
    }
  }

  // TODO: De-duplicate.
  nonisolated private func loadImageAnalysis(
    parameters: ImagesItemModelImageAnalysisParameters,
    document: URLSourceDocument,
  ) async throws -> ImagesModelLoadImageAnalysis? {
    try Task.checkCancellation()

    let image = await run(on: resamples) {
      document.accessingSecurityScopedResource {
        guard let imageSource = self.createImageSource(at: document.source.url) else {
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
        let length = min(size.scale(width: parameters.width).length, ImageAnalyzer.maxLength.decremented())
        let createThumbnailOptions = [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceThumbnailMaxPixelSize: length,
          kCGImageSourceCreateThumbnailWithTransform: true,
        ] as [CFString: Any]

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(
          imageSource,
          index,
          createThumbnailOptions as CFDictionary,
        ) else {
          Logger.model.error(
            """
            Could not create thumbnail at pixel size \(length) for image source at file URL \
            '\(document.source.url.pathString)'
            """,
          )

          return nil
        }

        Logger.model.debug(
          """
          Created thumbnail at pixel size \(length) for image source at file URL '\(document.source.url.pathString)': \
          \(size.width) x \(size.height) -> \(thumbnail.width) x \(thumbnail.height)
          """
        )

        let image = ImageOrientation(image: thumbnail, orientation: sizeOrientation.orientation)

        return image
      }
    }

    guard let image else {
      return nil
    }

    let result = ImagesModelLoadImageAnalysis(image: image, url: document.source.url)

    return result
  }

  private func loadImageAnalysis(
    parameters: ImagesItemModelImageAnalysisParameters,
    analysis: ImagesModelLoadImageAnalysis,
  ) async throws -> ImageAnalysis? {
    try Task.checkCancellation()

    do {
      return try await run(on: analyses) {
        // The analysis is performed by mediaanalysisd, so this call isn't holding up the main actor.
        let measured = try await ContinuousClock.continuous.measure {
          // For some reason, VisionKit seems to retain image memory until the app is inactive for a short period of
          // time (e.g., 10 seconds). I tried using analyze(imageAt:orientation:configuration:), but that just pushed
          // the memory to mediaanalysisd. Maybe we can try using CVPixelBuffer since it's the native format.
          try await ImageAnalyzer.default.analyze(
            analysis.image.image,
            orientation: analysis.image.orientation,
            configuration: ImageAnalyzer.Configuration(parameters.types.analyzerAnalysisTypes),
          )
        }

        Logger.model.debug("Took \(measured.duration) to analyze image at file URL '\(analysis.url.pathString)'")

        return measured.value
      }
    } catch {
      Logger.model.error("Could not analyze image at file URL '\(analysis.url.pathString)': \(error)")

      return nil
    }
  }

  private func loadImageAnalysis(
    item: ImagesItemModel2.ID,
    parameters: ImagesItemModelImageAnalysisParameters,
    analysis: ImageAnalysis?,
  ) {
    guard let item = self.items[id: item] else {
      return
    }

    item.imageAnalysis = analysis
    item.imageAnalysisID = UUID()
    item.imageAnalysisParameters = parameters
  }

  private func loadImageAnalysis(
    item: ImagesItemModel2.ID,
    parameters: ImagesItemModelImageAnalysisParameters,
    analysis: ImagesModelLoadImageAnalysis?
  ) async throws {
    let result: ImageAnalysis?

    if let analysis {
      result = try await self.loadImageAnalysis(parameters: parameters, analysis: analysis)
    } else {
      result = nil
    }

    self.loadImageAnalysis(
      item: item,
      parameters: parameters,
      analysis: result,
    )
  }

  nonisolated private func loadImageAnalyses(
    for items: [RowID],
    parameters: ImagesItemModelImageAnalysisParameters,
  ) async throws {
    guard let documents = await self.loadDocuments(for: items) else {
      return
    }

    for item in items {
      let analysis: ImagesModelLoadImageAnalysis?

      if let document = documents[item],
         let img = try await self.loadImageAnalysis(parameters: parameters, document: document) {
        analysis = img
      } else {
        analysis = nil
      }

      try await self.loadImageAnalysis(item: item, parameters: parameters, analysis: analysis)
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
    var imagesItem = ImagesItemRecord(
      fileBookmark: fileBookmark,
      position: position.asDecimalString(precision: position.denominator.digitCount(base: .TEN).decremented()),
      isBookmarked: false,
    )

    try imagesItem.insert(db)

    var itemImages = ItemImagesRecord(images: images, item: imagesItem.rowID)
    try itemImages.insert(db)

    return itemImages
  }

  nonisolated private func store(items: [Item<URLSource>]) async {
    let state1 = await self.urbs(items: items)
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

        _ = try items.reduce(images2.items.first?.item.position.flatMap(BigFraction.init(_:)) ?? BigFraction.zero) { position, item in
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
    let items = await self.items(urls, directoryEnumerationOptions: directoryEnumerationOptions)
    await store(items: urls.compactMap { items[$0] })
  }

  nonisolated private func _store(
    items: [ImagesItemTransfer],
    directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions,
  ) async {
    await store(items: self.items(items, directoryEnumerationOptions: directoryEnumerationOptions))
  }

  // TODO: Rename.
  nonisolated private func items(
    in directory: URLSource,
    directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions,
  ) async -> ItemDirectory<URLSource>? {
    // TODO: Rename and extract.
    struct X {
      let item: URL
      let pathComponents: [String]
    }

    let files = await directory.accessingSecurityScopedResource { () -> [X]? in
      guard let enumerator = FileManager.default.enumerate(
              at: directory.url,
              includingPropertiesForKeys: [.contentTypeKey],
              options: directoryEnumerationOptions,
            ) else {
        // TODO: Log.
        return nil
      }

      let items = await withTaskGroup(of: X?.self) { group in
        enumerator.forEach { item in
          group.addTask {
            let path = item.pathString
            let resourceValues: URLResourceValues

            do {
              resourceValues = try item.resourceValues(forKeys: [.contentTypeKey])
            } catch {
              Logger.model.error("Could not determine resource values for resource at file URL '\(path)'")

              return nil
            }

            guard let contentType = resourceValues.contentType else {
              Logger.model.error("Could not determine content type of resource at file URL '\(path)'")

              return nil
            }

            guard contentType.conforms(to: .image) else {
              Logger.model.debug(
                """
                Skipping resource at file URL '\(path)' because its content type '\(contentType)' doesn't refer to an \
                image
                """,
              )

              return nil
            }

            guard let components = FileManager.default.componentsToDisplay(forPath: path) else {
              Logger.model.error("Could not determine path components for resource at file URL '\(path)'")

              return nil
            }

            return X(item: item, pathComponents: components)
          }
        }

        let items = await group.reduce(into: [X]()) { partialResult, item in
          guard let item else {
            return
          }

          partialResult.append(item)
        }

        return items
      }

      return items
    }

    guard let files else {
      return nil
    }

    let directory = ItemDirectory(
      item: directory,
      files: files
        .finderSort(by: \.pathComponents)
        .map { URLSource(url: $0.item, options: [.withoutImplicitSecurityScope]) },
    )

    return directory
  }

  // TODO: Rename.
  nonisolated private func items(
    _ items: [URL],
    directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions,
  ) async -> [URL: Item<URLSource>] {
    await withTaskGroup(of: Item<URLSource>?.self) { group in
      items.forEach { item in
        group.addTask {
          let resourceValues: URLResourceValues

          do {
            resourceValues = try item.resourceValues(forKeys: [.contentTypeKey])
          } catch {
            Logger.model.error("Could not determine resource values for resource at file URL '\(item.pathString)'")

            return nil
          }

          guard let contentType = resourceValues.contentType else {
            Logger.model.error("Could not determine content type of resource at file URL '\(item.pathString)'")

            return nil
          }

          let source = URLSource(url: item, options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])

          if contentType.conforms(to: .image) {
            return .file(source)
          }

          if contentType.conforms(to: .folder) {
            guard let directory = await self.items(in: source, directoryEnumerationOptions: directoryEnumerationOptions) else {
              return nil
            }

            return .directory(directory)
          }

          Logger.model.debug(
            """
            Skipping resource at file URL '\(item.pathString)' because its content type '\(contentType)' neither refers
            to an image nor folder
            """,
          )

          return nil
        }
      }

      let results = await group.reduce(into: [URL: Item<URLSource>]()) { partialResult, item in
        guard let item else {
          return
        }

        switch item {
          case let .file(file): partialResult[file.url] = item
          case let .directory(directory): partialResult[directory.item.url] = item
        }
      }

      return results
    }
  }

  nonisolated private func items(
    _ items: [ImagesItemTransfer],
    directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions,
  ) async -> [Item<URLSource>] {
    var results = [Item<URLSource>](reservingCapacity: items.count)

    for item in items {
      switch item.contentType {
        case .image:
          results.append(.file(item.source))
        case .folder:
          guard let directory = await self.items(
            in: item.source,
            directoryEnumerationOptions: directoryEnumerationOptions,
          ) else {
            // TODO: Elaborate.
            continue
          }

          results.append(.directory(directory))
        default:
          unreachable()
      }
    }

    return results
  }

  nonisolated private func urbs(items: [Item<URLSource>]) async -> ImagesModelStoreState {
    await withThrowingTaskGroup(of: Item<URLBookmark>.self) { group in
      var state = ImagesModelStoreState(bookmarks: Dictionary(minimumCapacity: items.map(\.count).sum()))

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
  }

  nonisolated private func store(
    items: [URL],
    before: RowID?,
    directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions,
  ) async {
    // Interestingly, the items have no security scope, but we still need to create bookmarks with them so they don't
    // later become unavailable.
    let items2 = await self.items(items, directoryEnumerationOptions: directoryEnumerationOptions)
    let items3 = items.compactMap { items2[$0] }
    let state = await self.urbs(items: items3)
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection: \(error)")

      return
    }

    do {
      try await connection.write { db in
        let images = try ImagesRecord
          .select(.rowID)
          .filter(key: [ImagesRecord.Columns.id.name: self.id])
          .including(
            all: ImagesRecord.items
              .forKey(ImagesModelStoreBeforeImagesInfo.CodingKeys.items)
              .select(.rowID, ImagesItemRecord.Columns.position)
              .including(
                required: ImagesItemRecord.fileBookmark
                  .forKey(ImagesModelStoreBeforeImagesItemInfo.CodingKeys.fileBookmark)
                  .select(.rowID),
              ),
          )
          .asRequest(of: ImagesModelStoreBeforeImagesInfo.self)
          .fetchOne(db)

        let lowerBound: BigFraction
        let upperBound: BigFraction
        let record: ImagesRecord
        let index: [RowID: RowID]

        if let images {
          let upper = images.items.firstIndex { $0.item.rowID == before }
          let lower = upper.flatMap { images.items.subscriptIndex(before: $0) }

          lowerBound = lower.flatMap { BigFraction(images.items[$0].item.position!) } ?? .zero
          upperBound = upper.flatMap { BigFraction(images.items[$0].item.position!) } ?? .one
          record = images.images
          index = Dictionary(
            uniqueKeysWithValues: images.items.map { ($0.fileBookmark.fileBookmark.rowID!, $0.item.rowID!) },
          )
        } else {
          lowerBound = .zero
          upperBound = .one
          var images = ImagesRecord(id: self.id, currentItem: nil)
          try images.insert(db)

          record = images
          index = [:]
        }

        _ = try items3.reduce(lowerBound...upperBound) { partialResult, item in
          // TODO: Extract.
          switch item {
            case let .file(source):
              guard let bookmark = state.bookmarks[source.url] else {
                return partialResult
              }

              var bookmarkRecord = BookmarkRecord(data: bookmark.data, options: bookmark.options)
              try bookmarkRecord.upsert(db)

              var fileBookmark = FileBookmarkRecord(bookmark: bookmarkRecord.rowID, relative: nil)
              try fileBookmark.upsert(db)

              let fileBookmarkID = fileBookmark.rowID!
              let position = partialResult.lowerBound
                + delta(lowerBound: partialResult.lowerBound, upperBound: partialResult.upperBound, base: .TEN)

              let positionString = position.asDecimalString(
                precision: position.denominator.digitCount(base: .TEN).decremented(),
              )

              let item: ImagesItemRecord

              if let id = index[fileBookmarkID] {
                let record = ImagesItemRecord(rowID: id, fileBookmark: nil, position: positionString, isBookmarked: nil)
                try record.update(db, columns: [ImagesItemRecord.Columns.position])

                item = record
              } else {
                var record = ImagesItemRecord(
                  fileBookmark: fileBookmarkID,
                  position: positionString,
                  isBookmarked: false,
                )

                try record.insert(db)

                item = record
              }

              var itemImages = ItemImagesRecord(images: record.rowID, item: item.rowID)
              try itemImages.upsert(db)

              return position...upperBound
            case let .directory(directory):
              guard let bookmark = state.bookmarks[directory.item.url] else {
                return partialResult
              }

              var bookmarkRecord = BookmarkRecord(data: bookmark.data, options: bookmark.options)
              try bookmarkRecord.upsert(db)

              var fileBookmark = FileBookmarkRecord(bookmark: bookmarkRecord.rowID, relative: nil)
              try fileBookmark.upsert(db)

              let fileBookmarkID = fileBookmark.rowID!
              let range = try directory.files.reduce(partialResult) { partialResult, file in
                guard let bookmark = state.bookmarks[file.url] else {
                  return partialResult
                }

                var bookmarkRecord = BookmarkRecord(data: bookmark.data, options: bookmark.options)
                try bookmarkRecord.upsert(db)

                var fileBookmark = FileBookmarkRecord(bookmark: bookmarkRecord.rowID, relative: fileBookmarkID)
                try fileBookmark.upsert(db)

                let fileBookmarkID = fileBookmark.rowID!
                let position = partialResult.lowerBound
                  + delta(lowerBound: partialResult.lowerBound, upperBound: partialResult.upperBound, base: .TEN)

                let positionString = position.asDecimalString(
                  precision: position.denominator.digitCount(base: .TEN).decremented(),
                )

                let item: ImagesItemRecord

                if let id = index[fileBookmarkID] {
                  let record = ImagesItemRecord(
                    rowID: id,
                    fileBookmark: nil,
                    position: positionString,
                    isBookmarked: nil,
                  )

                  try record.update(db, columns: [ImagesItemRecord.Columns.position])

                  item = record
                } else {
                  var record = ImagesItemRecord(
                    fileBookmark: fileBookmarkID,
                    position: positionString,
                    isBookmarked: false,
                  )

                  try record.insert(db)

                  item = record
                }

                var itemImages = ItemImagesRecord(images: record.rowID, item: item.rowID)
                try itemImages.upsert(db)

                return position...upperBound
              }

              return range
          }
        }
      }
    } catch {
      Logger.model.error("Could not write to database: \(error)")
    }
  }

  nonisolated private func store(items: [RowID], before: RowID?) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection: \(error)")

      return
    }

    do {
      try await connection.write { db in
        let upper = try ImagesItemRecord
          .select(.rowID, ImagesItemRecord.Columns.position)
          .filter(key: before)
          .asRequest(of: ImagesModelStoreMoveBeforeImagesItemInfo.self)
          .fetchOne(db)

        let lower = try ImagesItemRecord
          .select(.rowID, ImagesItemRecord.Columns.position)
          .filter(ImagesItemRecord.Columns.position < upper?.item.position)
          .order(ImagesItemRecord.Columns.position.desc)
          .asRequest(of: ImagesModelStoreMoveBeforeImagesItemInfo.self)
          .fetchOne(db)

        let lowerBound = lower.flatMap { BigFraction($0.item.position!) } ?? .zero
        let upperBound = upper.flatMap { BigFraction($0.item.position!) } ?? .one
        _ = try items.reduce(lowerBound...upperBound) { partialResult, item in
          let position = partialResult.lowerBound
            + delta(lowerBound: partialResult.lowerBound, upperBound: partialResult.upperBound, base: .TEN)

          let item = ImagesItemRecord(
            rowID: item,
            fileBookmark: nil,
            position: position.asDecimalString(precision: position.denominator.digitCount(base: .TEN).decremented()),
            isBookmarked: nil,
          )

          try item.update(db, columns: [ImagesItemRecord.Columns.position])

          return position...upperBound
        }
      }
    } catch {
      Logger.model.error("Could not write to database: \(error)")
    }
  }

  nonisolated private func remove(items: [RowID]) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection: \(error)")

      return
    }

    do {
      try await connection.write { db in
        _ = try ImagesItemRecord.deleteAll(db, keys: items)
      }
    } catch {
      Logger.model.error("Could not write to database: \(error)")

      return
    }
  }

  nonisolated private func assign(bookmark: BookmarkRecord, relative: BookmarkRecord?) async -> AssignedBookmarkDocument? {
    // If relative is resolved while bookmark isn't, this will send notifications for both. This isn't the best design,
    // but it's not the worst, either, since we'll be notified of the region changing, rather than of the individual
    // bookmarks. As a result, returning nil instead of, say, nil for the property, has no visible effect on the
    // application, which is flexible.

    let assignedRelative: AssignedBookmark?
    let relativeSource: URLSource?

    if let r = relative {
      let relative: AssignedBookmark

      do {
        relative = try await AssignedBookmark(data: r.data!, options: r.options!, relativeTo: nil)
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return nil
      }

      assignedRelative = relative
      relativeSource = URLSource(url: relative.resolved.url, options: r.options!)
    } else {
      assignedRelative = nil
      relativeSource = nil
    }

    let assignedBookmark: AssignedBookmark

    do {
      assignedBookmark = try await relativeSource.accessingSecurityScopedResource {
        try await AssignedBookmark(data: bookmark.data!, options: bookmark.options!, relativeTo: relativeSource?.url)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    return AssignedBookmarkDocument(bookmark: assignedBookmark, relative: assignedRelative)
  }

  nonisolated private func document(
    assigned: AssignedBookmarkDocument,
    bookmark: BookmarkRecord,
    relative: BookmarkRecord?,
  ) -> URLSourceDocument {
    let rel: URLSource?

    if let r = relative {
      rel = URLSource(url: assigned.relative!.resolved.url, options: r.options!)
    } else {
      rel = nil
    }

    let document = URLSourceDocument(
      source: URLSource(url: assigned.bookmark.resolved.url, options: bookmark.options!),
      relative: rel,
    )

    return document
  }

  nonisolated private func loadDocument(for item: ImagesItemModel2.ID) async -> URLSourceDocument? {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection: \(error)")

      return nil
    }

    let item2: ImagesModelLoadDocumentImagesItemInfo?

    do {
      item2 = try await connection.read { db in
        try ImagesItemRecord
          .select(.rowID)
          .filter(key: item)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelLoadDocumentImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadDocumentImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadDocumentImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadDocumentImagesItemInfo.self)
          .fetchOne(db)
      }
    } catch {
      Logger.model.error("Could not read from database: \(error)")

      return nil
    }

    guard let item = item2 else {
      Logger.model.error("Could not find image collection item '\(item)'")

      return nil
    }

    let assigned = await assign(
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.bookmark,
    )

    do {
      try await connection.write { db in
        if let relative = item.fileBookmark.relative {
          try write(db, bookmark: relative.bookmark, assigned: assigned?.relative)
        }

        try write(db, bookmark: item.fileBookmark.bookmark.bookmark, assigned: assigned?.bookmark)
      }
    } catch {
      Logger.model.error("Could not write to database: \(error)")

      return nil
    }

    guard let assigned else {
      return nil
    }

    let document = self.document(
      assigned: assigned,
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.bookmark,
    )

    return document
  }

  nonisolated private func loadDocuments(for items: some Collection<RowID> & Sendable) async -> [RowID: URLSourceDocument]? {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection: \(error)")

      return nil
    }

    let imagesItems: [RowID: ImagesModelLoadDocumentImagesItemInfo]

    do {
      imagesItems = try await connection.read { db in
        let items = try ImagesItemRecord
          .select(.rowID)
          .filter(keys: items)
          .including(
            required: ImagesItemRecord.fileBookmark
              .forKey(ImagesModelLoadDocumentImagesItemInfo.CodingKeys.fileBookmark)
              .select(.rowID)
              .including(
                required: FileBookmarkRecord.bookmark
                  .forKey(ImagesModelLoadDocumentImagesItemFileBookmarkInfo.CodingKeys.bookmark)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              )
              .including(
                optional: FileBookmarkRecord.relative
                  .forKey(ImagesModelLoadDocumentImagesItemFileBookmarkInfo.CodingKeys.relative)
                  .select(.rowID, BookmarkRecord.Columns.data, BookmarkRecord.Columns.options),
              ),
          )
          .asRequest(of: ImagesModelLoadDocumentImagesItemInfo.self)
          .fetchCursor(db)

        let state = try Dictionary(uniqueKeysWithValues: items.map { ($0.item.rowID!, $0) })

        return state
      }
    } catch is CancellationError {
      return nil
    } catch {
      Logger.model.error("Could not read from database: \(error)")

      return nil
    }

    let fileBookmarks = items.compactMap { item -> BookmarkAssignmentFileBookmark? in
      guard let item = imagesItems[item] else {
        Logger.model.error("Could not find image collection item '\(item)'")

        return nil
      }

      let fileBookmark = BookmarkAssignmentFileBookmark(
        fileBookmark: item.fileBookmark.fileBookmark,
        bookmark: BookmarkAssignmentFileBookmarkBookmark(bookmark: item.fileBookmark.bookmark.bookmark),
        relative: item.fileBookmark.relative.map { relative in
          BookmarkAssignmentFileBookmarkRelative(bookmark: relative.bookmark)
        },
      )

      return fileBookmark
    }

    var assigner = BookmarkAssignment()
    await assigner.assign(fileBookmarks: fileBookmarks)

    do {
      // If the calling task is canceled, we still want the results written to the database.
      try await Task { [assigner] in
        try await connection.write { db in
          try assigner.write(db, fileBookmarks: fileBookmarks)
        }
      }.value
      // TODO: Figure out how to ignore task cancellation.
      //
      // We could create a Task and await its value property.
    } catch {
      Logger.model.error("Could not write to database: \(error)")

      return nil
    }

    let documents = items.reduce(into: Dictionary(minimumCapacity: items.count)) { partialResult, item in
      guard let item = imagesItems[item] else {
        return
      }

      partialResult[item.item.rowID!] = assigner.document(
        fileBookmark: BookmarkAssignmentFileBookmark(
          fileBookmark: item.fileBookmark.fileBookmark,
          bookmark: BookmarkAssignmentFileBookmarkBookmark(bookmark: item.fileBookmark.bookmark.bookmark),
          relative: item.fileBookmark.relative.map { relative in
            BookmarkAssignmentFileBookmarkRelative(bookmark: relative.bookmark)
          },
        ),
      )
    }

    return documents
  }

  nonisolated private func showFinder(item: RowID) async {
    guard let document = await self.loadDocument(for: item) else {
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting([document.source.url])
  }

  nonisolated private func showFinder(items: [RowID]) async {
    guard let documents = await self.loadDocuments(for: items) else {
      return
    }

    NSWorkspace.shared.activateFileViewerSelecting(items.compactMap { documents[$0]?.source.url })
  }

  nonisolated private func copy(url: URL) {
    // FIXME: This does not work:
    //
    //   NSPasteboard.general.writeObjects([document.source.url as NSURL])
    //
    // writeObjects(_:) is necessary to support features like "Paste Item" in Finder (Finder > Edit > Paste Item).
    // Because URL bookmarks no longer carry an implicit security scope, other processes can't read the image. The issue,
    // here, is that removing the implicit security scope is necessary to process all bookmarks without exhausting the
    // sandbox.
    //
    // I tried using NSFilePromiseProvider, but the delegate methods were never called.
    //
    // I tried creating sources with security scopes even when their relative has one, but that had no effect. This has
    // me thinking that implicit security scopes are necessary. If we were to support this, we'd need to restructure
    // bookmark resolution to be done in chunks. However, even with this, we couldn't support View.copyable(_:). Because
    // of this, I think partial support is better at this point in time.
    guard NSPasteboard.general.setString(url.absoluteString, forType: .URL) else {
      Logger.model.error("Could not write URL '\(url.debugString)' to general pasteboard")

      return
    }
  }

  nonisolated private func copy(item: RowID) async {
    guard let document = await self.loadDocument(for: item) else {
      return
    }

    NSPasteboard.general.prepareForNewContents()
    self.copy(url: document.source.url)
  }

  nonisolated private func copy(items: [RowID]) async {
    guard let documents = await self.loadDocuments(for: items) else {
      return
    }

    NSPasteboard.general.prepareForNewContents()
    // This should store all items in the pasteboard, even if the last one is what appears in the user's clipboard,
    // which should be useful for applications that allow you to inspect the pasteboard over time.
    items
      .compactMap { documents[$0] }
      .forEach { self.copy(url: $0.source.url) }
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

  nonisolated private func copyFolder(
    item: RowID,
    to folder: RowID,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
  ) async throws(ImagesModelCopyFolderError) {
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

    let assignedItem = await assign(
      bookmark: item.fileBookmark.bookmark.bookmark,
      relative: item.fileBookmark.relative?.relative,
    )

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

  nonisolated private func copyFolder(
    item: RowID,
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
  ) async throws(ImagesModelCopyFolderError) {
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

    let assigned = await assign(bookmark: item.fileBookmark.bookmark.bookmark, relative: item.fileBookmark.relative?.relative)

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

  nonisolated private func copyFolder(
    items: [RowID],
    to folder: RowID,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
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

  nonisolated private func copyFolder(
    items: [RowID],
    to folder: URL,
    locale: Locale,
    resolveConflicts: Bool,
    pathDirection: StorageFoldersPathDirection,
    pathSeparator: StorageFoldersPathSeparator,
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
        let item = ImagesItemRecord(rowID: item, fileBookmark: nil, position: nil, isBookmarked: isBookmarked)
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
          let item = ImagesItemRecord(rowID: item, fileBookmark: nil, position: nil, isBookmarked: isBookmarked)
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
