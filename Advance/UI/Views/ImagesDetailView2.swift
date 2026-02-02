//
//  ImagesDetailView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/30/25.
//

import AsyncAlgorithms
import IdentifiedCollections
import OSLog
import SwiftUI
import Algorithms

@MainActor
struct ImagesDetailViewImageAnalysisID {
  let images: ImagesModel
  let types: ImageAnalysisTypes
}

extension ImagesDetailViewImageAnalysisID: @MainActor Equatable {}

@MainActor
struct ImagesDetailViewVisibleItemsID {
  let images: ImagesModel
  let restoreLastImage: Bool
  let columnVisibility: StorageColumnVisibility
}

extension ImagesDetailViewVisibleItemsID: @MainActor Equatable {}

struct ImagesDetailView2: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.pixelLength) private var pixelLength
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  @AppStorage(StorageKeys.restoreLastImage) private var restoreLastImage
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibility
  private var imageAnalysisTypes: ImageAnalysisTypes {
    var types = ImageAnalysisTypes()

    if self.isLiveTextEnabled {
      types.insert(.text)

      if self.isLiveTextSubjectEnabled {
        types.insert(.visualLookUp)
      }
    }

    return types
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(images.items) { item in
        ImagesDetailItemView(item: item)
      }
      .listStyle(.plain)
      .task(id: self.images) {
        for await item in self.images.detail {
          // TODO: Figure out how to accurately animate scrolling.
          //
          // See ImagesSidebarView2.
          //
          // For some reason, we need to wrap this in a Task to accurately scroll.
          Task {
            proxy.scrollTo(item, anchor: .top)
          }
        }
      }
      .backgroundPreferenceValue(ImagesVisibleItemsPreferenceKey.self) { value in
        GeometryReader { proxy in
          Color.clear
            .task(id: ImagesViewItemsID(images: self.images, items: value)) {
              let frame = proxy.frame(in: .local)
              let resolved = value
                .map { ImagesResolvedVisibleItem(item: $0.item, frame: proxy[$0.anchor]) }
                .filter { frame.intersects($0.frame) }

              let items = resolved.map(\.item)
              async let x: () = self.images.visibleItemsChannel.send(items)

              guard let item = resolved.first else {
                await x

                return
              }

              let resample = ImagesModelResample(width: item.frame.width, items: items)
              async let y: () = self.images.detailResample.send(resample)
              async let z: () = self.images.detailImageAnalysis.send(resample)
              await x
              await y
              await z
            }
        }
      }
      .task(id: ImagesViewResampleID(images: self.images, pixelLength: self.pixelLength)) {
        var task: Task<Void, Never>?

        for await resample in self.images.detailResample.removeDuplicates().debounce(for: .microhang) {
          task?.cancel()
          task = Task {
            await self.images.loadDetailImages(
              items: self.items(resample: resample.items),
              parameters: ImagesItemModelImageParameters(width: resample.width / self.pixelLength),
            )
          }
        }

        task?.cancel()
      }
      .task(id: ImagesDetailViewImageAnalysisID(images: self.images, types: self.imageAnalysisTypes)) {
        var task: Task<Void, Never>?

        for await resample in self.images.detailImageAnalysis.removeDuplicates().debounce(for: .microhang) {
          task?.cancel()
          task = Task {
            // This is auxiliary and expensive, so we don't want to pre-load image analysis.
            await self.images.loadImageAnalyses(
              for: resample.items,
              parameters: ImagesItemModelImageAnalysisParameters(
                width: resample.width / self.pixelLength,
                types: self.imageAnalysisTypes,
              )
            )
          }
        }

        task?.cancel()
      }
    }
    .task(
      id: ImagesDetailViewVisibleItemsID(
        images: self.images,
        restoreLastImage: self.restoreLastImage,
        columnVisibility: self.columnVisibility,
      ),
    ) {
      for await items in self.images.visibleItemsChannel.dropFirst().removeDuplicates() {
        // If we have a restore item, this initially sets the current item to the visible item that may be updated. In
        // an ideal case, we'd only use the latest value, but that'd require considering states like whether or not
        // scrolling to the restore item will send another element (i.e., whether or not we're already at the restore
        // item). At the moment, I don't want to implement it, since I'm not sure if it's a good idea.
        self.images.visibleItems = items
        self.images.isHighlighted = !items.isEmpty && items.allSatisfy(\.isImageAnalysisSelectableItemsHighlighted)
        await self.images.setCurrentItem(item: items.first)

        if self.restoreLastImage && self.images.visibleItemsNeedsScroll,
           let item = self.images.restoredItem {
          if self.columnVisibility != .detailOnly {
            await self.images.sidebar.send(ImagesModelSidebarElement(item: item.id, isSelected: false))
          }

          await self.images.detail.send(item.id)
        }

        self.images.visibleItemsNeedsScroll = false
      }
    }
  }

  private func items(resample: [ImagesItemModel2]) -> [ImagesItemModel2] {
    var items = [ImagesItemModel2](reservingCapacity: resample.count + 4)
    items.append(contentsOf: resample)

    let before1: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let before2: IdentifiedArrayOf<ImagesItemModel2>.Index?

    if let item = resample.first,
       let index = self.images.items.index(id: item.id) {
      before1 = self.images.items.subscriptIndex(before: index)
      before2 = before1.flatMap { self.images.items.subscriptIndex(before: $0) }
    } else {
      before1 = nil
      before2 = nil
    }

    let after1: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let after2: IdentifiedArrayOf<ImagesItemModel2>.Index?

    if let item = resample.last,
       let index = self.images.items.index(id: item.id) {
      after1 = self.images.items.subscriptIndex(after: index)
      after2 = after1.flatMap { self.images.items.subscriptIndex(after: $0) }
    } else {
      after1 = nil
      after2 = nil
    }

    before1.map { items.append(self.images.items[$0]) }
    after1.map { items.append(self.images.items[$0]) }
    before2.map { items.append(self.images.items[$0]) }
    after2.map { items.append(self.images.items[$0]) }

    return items
  }
}
