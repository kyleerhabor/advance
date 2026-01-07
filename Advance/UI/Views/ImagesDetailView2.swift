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
import VisionKit

struct ImageDetailItemImageAnalysisView: View {
  @Environment(ImagesModel.self) private var images
  @Environment(SearchSettingsModel.self) private var search
  @Environment(\.locale) private var locale
  @Environment(\.openURL) private var openURL
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  @AppStorage(StorageKeys.isSystemSearchEnabled) private var isSystemSearchEnabled
  @Binding var searchError: ImagesModelEngineURLError?
  @Binding var isSearchErrorPresented: Bool
  let item: ImagesItemModel2
  let isSupplementaryInterfaceVisible: Bool
  private var preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes {
    var interactionTypes = ImageAnalysisOverlayView.InteractionTypes()

    if self.isLiveTextEnabled && self.item.detailImagePhase == .success {
      interactionTypes.insert(.automaticTextOnly)

      if self.isLiveTextSubjectEnabled {
        interactionTypes.insert(.automatic)
      }
    }

    return interactionTypes
  }

  var body: some View {
    @Bindable var item = self.item

    ImageAnalysisView(
      selectableItemsHighlighted: $item.isImageAnalysisSelectableItemsHighlighted,
      analysis: item.imageAnalysis,
      preferredInteractionTypes: preferredInteractionTypes,
      isSupplementaryInterfaceHidden: !self.isSupplementaryInterfaceVisible,
    ) { delegate, menu, overlayView in
      let copyImage = menu.indexOfItem(withTag: ImageAnalysisOverlayView.MenuTag.copyImage)

      if copyImage != -1 {
        menu.removeItem(at: copyImage)
      }

      let shareImage = menu.indexOfItem(withTag: ImageAnalysisOverlayView.MenuTag.shareImage)

      if shareImage != -1 {
        menu.removeItem(at: copyImage)
      }

      if !isSystemSearchEnabled {
        let index = menu.items.firstIndex { $0.identifier == NSMenuItem.search }

        if let index {
          if let engine = search.engine {
            let item = NSMenuItem()
            item.title = String(localized: "Images.Item.LiveText.Search.\(engine.name)", locale: locale)
            item.target = delegate
            item.action = #selector(delegate.action(_:))
            delegate.actions[item] = {
              Task {
                let url: URL?

                do {
                  url = try await images.url(
                    engine: engine.id,
                    query: overlayView.selectedText,
                    locale: locale,
                  )
                } catch let error as ImagesModelEngineURLError {
                  self.searchError = error
                  self.isSearchErrorPresented = true

                  return
                }

                guard let url else {
                  return
                }

                openURL(url)
              }
            }

            menu.items[index] = item
          } else {
            menu.removeItem(at: index)
          }
        }
      }

      return menu
    }
  }
}

struct ImagesDetailItemBookmarkView: View {
  @Environment(ImagesModel.self) private var images
  let item: ImagesItemModel2

  var body: some View {
    Button(
      self.item.isBookmarked ? "Images.Item.Bookmark.Remove" : "Images.Item.Bookmark.Add",
      systemImage: "bookmark"
    ) {
      Task {
        await self.images.bookmark(item: self.item, isBookmarked: !self.item.isBookmarked)
      }
    }
  }
}

struct ImagesDetailItemImageView: View {
  let item: ImagesItemModel2

  var body: some View {
    // For some reason, we need to wrap this in a VStack for animations to apply.
    VStack {
      ImagesItemImageView(
        item: self.item,
        aspectRatio: self.item.detailAspectRatio,
        image: self.item.detailImage,
        phase: self.item.detailImagePhase,
      )
    }
  }
}

@MainActor
struct ImagesDetailViewImageAnalysisID {
  let images: ImagesModel
  let types: ImageAnalysisTypes
  let pixelLength: CGFloat
}

extension ImagesDetailViewImageAnalysisID: @MainActor Equatable {}

struct ImagesDetailView2: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.locale) private var locale
  @Environment(\.pixelLength) private var pixelLength
  @AppStorage(StorageKeys.collapseMargins) private var collapseMargins
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  @AppStorage(StorageKeys.margins) private var margins
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.restoreLastImage) private var restoreLastImage
  @Binding var copyFolderError: ImagesModelCopyFolderError?
  @Binding var isCopyFolderErrorPresented: Bool
  @State private var copyFolderSelection: ImagesItemModel2.ID?
  @State private var isCopyFolderFileImporterPresented = false
  @State private var searchError: ImagesModelEngineURLError?
  @State private var isSearchErrorPresented = false
  let columnVisibility: NavigationSplitViewVisibility
  let isImageAnalysisSupplementaryInterfaceVisible: Bool
  private var half: CGFloat { self.margins * 3 }
  private var full: CGFloat { self.half * 2 }
  private var all: EdgeInsets { EdgeInsets(self.full) }
  private var top: EdgeInsets { EdgeInsets(horizontal: self.full, top: self.full, bottom: self.half) }
  private var between: EdgeInsets { EdgeInsets(horizontal: self.full, top: self.half, bottom: self.half) }
  private var bottom: EdgeInsets { EdgeInsets(horizontal: self.full, top: self.half, bottom: self.full) }
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
        let insets = switch item.edge {
          case .all:
            self.all
          case .top:
            self.collapseMargins ? self.top : self.all
          case .bottom:
            self.collapseMargins ? self.bottom : self.all
          default:
            self.collapseMargins ? self.between : self.all
        }

        // TODO: Figure out how to remove the border when the context menu is open.
        //
        // For some reason, we need to extract accesses to item's properties into dedicated views to prevent slow view
        // updates when switching windows.
        ImagesDetailItemImageView(item: item)
          .anchorPreference(key: ImagesVisibleItemsPreferenceKey.self, value: .bounds) { anchor in
            [ImagesVisibleItem(item: item, anchor: anchor)]
          }
          .overlay {
            ImageDetailItemImageAnalysisView(
              searchError: $searchError,
              isSearchErrorPresented: $isSearchErrorPresented,
              item: item,
              isSupplementaryInterfaceVisible: self.isImageAnalysisSupplementaryInterfaceVisible,
            )
          }
          .contextMenu {
            Section {
              Button("Finder.Item.Show", systemImage: "finder") {
                Task {
                  await images.showFinder(item: item.id)
                }
              }

              Button("Sidebar.Item.Show", systemImage: "sidebar.squares.leading") {
                Task {
                  await images.sidebar.send(ImagesModelSidebarElement(item: item.id, isSelected: true))
                }
              }
            }

            Section {
              Button("Images.Item.Copy", systemImage: "document.on.document") {
                Task {
                  await images.copy(item: item.id)
                }
              }

              ImagesDetailItemCopyFolderView(
                selection: $copyFolderSelection,
                isFileImporterPresented: $isCopyFolderFileImporterPresented,
                error: $copyFolderError,
                isErrorPresented: $isCopyFolderErrorPresented,
                item: item.id,
              )
            }

            Section {
              ImagesDetailItemBookmarkView(item: item)
            }
          }
          .shadow(radius: self.margins / 2)
          .listRowInsets(.listRow + insets)
          .listRowSeparator(.hidden)
      }
      .listStyle(.plain)
      .alert(isPresented: $isSearchErrorPresented, error: searchError) { error in
        // Empty
      } message: { error in
        Text(error.recoverySuggestion ?? "")
      }
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

              async let y: () = self.images.detailResample.send(ImagesModelResample(width: item.frame.width, items: items))
              async let z: () = self.images.detailImageAnalysis.send(ImagesModelResample(width: item.frame.width, items: items))
              await x
              await y
              await z
            }
        }
      }
      .task(id: self.images) {
        guard !Task.isCancelled else {
          return
        }

        // For some reason, scrolling via the sidebar may cause this to output an empty array, immediately followed by
        // the proper items. Debouncing defends against this, but is not a sound solution, since our problem is state.
        var iterator = self.images.visibleItemsChannel
          // Drop the items before items has loaded (that is, an empty array).
          .dropFirst()
          // Remove duplicate arrays.
          .removeDuplicates()
          .makeAsyncIterator()

        if self.restoreLastImage,
           let items = await iterator.next() {
          // If we have a restore item, this initially sets the current item to the visible item that may be updated. In
          // an ideal case, we'd only use the latest value, but that'd require considering states like whether or not
          // scrolling to the restore item will send another element (i.e., whether or not we're already at the restore
          // item). At the moment, I don't want to implement it, since I'm not sure if it's a good idea.
          self.images.visibleItems = items
          self.images.isHighlighted = !items.isEmpty && items.allSatisfy(\.isImageAnalysisSelectableItemsHighlighted)
          await self.images.setCurrentItem(item: items.first)

          if let item = self.images.restoredItem {
            if self.columnVisibility != .detailOnly {
              await self.images.sidebar.send(ImagesModelSidebarElement(item: item.id, isSelected: false))
            }

            await self.images.detail.send(item.id)
          }
        }

        while let items = await iterator.next() {
          self.images.visibleItems = items
          self.images.isHighlighted = !items.isEmpty && items.allSatisfy(\.isImageAnalysisSelectableItemsHighlighted)
          await self.images.setCurrentItem(item: items.first)
        }
      }
      .task(id: ImagesViewResampleID(images: self.images, pixelLength: self.pixelLength)) {
        for await resample in self.images.detailResample.removeDuplicates().debounce(for: .microhang) {
          await self.images.loadImages(
            in: .detail,
            items: self.items(resample: resample),
            parameters: ImagesItemModelImageParameters(width: resample.width / self.pixelLength),
          )
        }
      }
      .task(
        id: ImagesDetailViewImageAnalysisID(
          images: self.images,
          types: self.imageAnalysisTypes,
          pixelLength: self.pixelLength,
        ),
      ) {
        for await resample in self.images.detailImageAnalysis.removeDuplicates().debounce(for: .microhang) {
          await self.images.loadImageAnalyses(
            for: self.items(resample: resample),
            parameters: ImagesItemModelImageAnalysisParameters(
              types: self.imageAnalysisTypes,
              width: resample.width / self.pixelLength,
            )
          )
        }
      }
    }
    .fileImporter(isPresented: $isCopyFolderFileImporterPresented, allowedContentTypes: foldersContentTypes) { result in
      let url: URL

      switch result {
        case let .success(x):
          url = x
        case let .failure(error):
          // TODO: Elaborate.
          Logger.ui.error("\(error)")

          return
      }

      Task {
        do {
          try await images.copyFolder(
            item: copyFolderSelection,
            to: url,
            locale: locale,
            resolveConflicts: resolveConflicts,
            pathSeparator: foldersPathSeparator,
            pathDirection: foldersPathDirection,
          )
        } catch let error as ImagesModelCopyFolderError {
          self.copyFolderError = error
          self.isCopyFolderErrorPresented = true
        }
      }
    }
    .fileDialogCustomizationID(FoldersSettingsScene.id)
  }

  private func items(resample: ImagesModelResample) -> [ImagesItemModel2] {
    var items = [ImagesItemModel2](reservingCapacity: resample.items.count + 4)
    items.append(contentsOf: resample.items)

    let before1: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let before2: IdentifiedArrayOf<ImagesItemModel2>.Index?

    if let item = resample.items.first,
       let index = self.images.items.index(id: item.id) {
      before1 = self.images.items.subscriptIndex(before: index)
      before2 = before1.flatMap { self.images.items.subscriptIndex(before: $0) }
    } else {
      before1 = nil
      before2 = nil
    }

    let after1: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let after2: IdentifiedArrayOf<ImagesItemModel2>.Index?

    if let item = resample.items.last,
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
