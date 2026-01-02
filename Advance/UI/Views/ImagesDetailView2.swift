//
//  ImagesDetailView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/30/25.
//

import AdvanceCore
import AsyncAlgorithms
import OSLog
import SwiftUI
import VisionKit

struct ImagesDetailItemImageView2: View {
  @State private var hasElapsed = false
  let item: ImagesItemModel2

  var body: some View {
    let isSuccess = item.detailImagePhase == .success

    Image(nsImage: item.detailImage)
      .resizable()
      .background(.fill.quaternary.visible(!isSuccess), in: .rect)
      .animation(.default, value: isSuccess)
      .overlay {
        let isVisible = item.detailImagePhase == .empty && hasElapsed

        ProgressView()
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .overlay {
        let isVisible = item.detailImagePhase == .failure

        Image(systemName: "exclamationmark.triangle.fill")
          .symbolRenderingMode(.multicolor)
          .imageScale(.large)
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .aspectRatio(item.aspectRatio, contentMode: .fit)
      .task {
        do {
          try await Task.sleep(for: .imagesElapse)
        } catch is CancellationError {
          return
        } catch {
          unreachable()
        }

        hasElapsed = true
      }
  }
}

@MainActor
struct ImagesDetailItem {
  let item: ImagesItemModel2
  let anchor: Anchor<CGRect>
}

extension ImagesDetailItem: @MainActor Equatable {}

struct ImagesDetailItemsPreferenceKey: PreferenceKey {
  static let defaultValue = [ImagesDetailItem]()

  static func reduce(value: inout [ImagesDetailItem], nextValue: () -> [ImagesDetailItem]) {
    value.append(contentsOf: nextValue())
  }
}

struct ImagesDetailResample {
  let width: Double
  let items: [ImagesItemModel2]
}

extension ImagesDetailResample: Equatable {}

struct ImagesDetailViewLiveTextID {
  let id: UUID
  let phase: ImagesItemModelImagePhase
}

extension ImagesDetailViewLiveTextID: Equatable {}

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

    guard self.isLiveTextEnabled else {
      return interactionTypes
    }

    interactionTypes.insert(.automaticTextOnly)

    if self.isLiveTextSubjectEnabled {
      interactionTypes.insert(.automatic)
    }

    return interactionTypes
  }

  var body: some View {
    @Bindable var item = self.item

    ImageAnalysisView2(
      selectableItemsHighlighted: $item.isHighlighted,
      analysis: item.imageAnalysis,
      preferredInteractionTypes: preferredInteractionTypes,
      isSupplementaryInterfaceHidden: !isSupplementaryInterfaceVisible,
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
        let index = menu.items.firstIndex { $0.action == NSMenuItem.searchAction }

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
      item.isBookmarked ? "Images.Item.Bookmark.Remove" : "Images.Item.Bookmark.Add",
      systemImage: "bookmark"
    ) {
      Task {
        await images.bookmark(item: item, isBookmarked: !item.isBookmarked)
      }
    }
  }
}

struct ImagesDetailItemBackgroundView: View {
  @Environment(ImagesModel.self) private var images
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  let item: ImagesItemModel2

  var body: some View {
    Color.clear
      .task(id: ImagesDetailViewLiveTextID(id: item.detailImageID, phase: item.detailImagePhase)) {
        var types = ImageAnalysisTypes()

        if isLiveTextEnabled {
          types.insert(.text)

          if isLiveTextSubjectEnabled {
            types.insert(.visualLookUp)
          }
        }

        await images.loadImageAnalysis(item: item, types: types)
      }
  }
}

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
  @State private var itemsChannel = AsyncChannel<[ImagesItemModel2]>()
  @State private var resamples = AsyncChannel<ImagesDetailResample>()
  @State private var copyFolderSelection: ImagesItemModel2.ID?
  @State private var isCopyFolderFileImporterPresented = false
  @State private var searchError: ImagesModelEngineURLError?
  @State private var isSearchErrorPresented = false
  let columnVisibility: NavigationSplitViewVisibility
  let isSupplementaryInterfaceVisible: Bool
  private var half: CGFloat { self.margins * 3 }
  private var full: CGFloat { self.half * 2 }
  private var all: EdgeInsets { EdgeInsets(full) }
  private var top: EdgeInsets { EdgeInsets(horizontal: full, top: full, bottom: half) }
  private var between: EdgeInsets { EdgeInsets(horizontal: full, top: half, bottom: half) }
  private var bottom: EdgeInsets { EdgeInsets(horizontal: full, top: half, bottom: full) }

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
        ImagesDetailItemImageView2(item: item)
          .overlay {
            ImageDetailItemImageAnalysisView(
              searchError: $searchError,
              isSearchErrorPresented: $isSearchErrorPresented,
              item: item,
              isSupplementaryInterfaceVisible: isSupplementaryInterfaceVisible,
            )
          }
          .background {
            ImagesDetailItemBackgroundView(item: item)
          }
          .anchorPreference(key: ImagesDetailItemsPreferenceKey.self, value: .bounds) { anchor in
            [ImagesDetailItem(item: item, anchor: anchor)]
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
      .task(id: images) {
        for await item in images.detail {
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
      .backgroundPreferenceValue(ImagesDetailItemsPreferenceKey.self) { value in
        GeometryReader { proxy in
          Color.clear
            .task(id: value) {
              let frame = proxy.frame(in: .local)
              let items = value
                .filter { frame.intersects(proxy[$0.anchor]) }
                .map(\.item)

              await self.resamples.send(ImagesDetailResample(width: frame.width, items: items))
              await self.itemsChannel.send(items)
            }
        }
      }
      .task(id: images) {
        guard !Task.isCancelled else {
          return
        }

        for await resample in resamples.removeDuplicates() {
          var items = [ImagesItemModel2](reservingCapacity: resample.items.count + 4)

          if let item = resample.items.first,
             let index = images.items.index(id: item.id) {
            let item1 = images.items.before(index: index)
            let item2 = item1.flatMap { images.items.before(index: $0.index) }
            
            item2.map { items.append($0.element) }
            item1.map { items.append($0.element) }
          }

          items.append(contentsOf: resample.items)

          if let item = resample.items.last,
             let index = images.items.index(id: item.id) {
            let item1 = images.items.after(index: index)
            let item2 = item1.flatMap { images.items.after(index: $0.index) }

            item2.map { items.append($0.element) }
            item1.map { items.append($0.element) }
          }

          await images.loadImages(
            items: items.filter { $0.detailImagePhase != .success },
            width: resample.width,
            pixelLength: pixelLength,
          )

          self.images.items.forEach { item in
            // On average, average contains 6 elements, so I think this should be faster than using a set (but someone
            // could test it).
            guard !items.contains(item) else {
              return
            }

            item.detailImage = NSImage()
            item.detailImageID = UUID()
            item.detailImagePhase = .empty
          }
        }
      }
      .task(id: self.images) {
        guard !Task.isCancelled else {
          return
        }

        // For some reason, scrolling via the sidebar may cause this to output nil, immediately followed by a proper
        // item. Debouncing defends against this, but is not a sound solution, since it's based on time, rather than
        // state.
        var iterator = self.itemsChannel
          // Drop the current item before items have been loaded (that is, nil).
          .dropFirst()
          // Remove duplicate current items.
          .removeDuplicates()
          .makeAsyncIterator()

        // At this point, items have been loaded and we need to account for whether or not we have a current item. If we
        // have one, we'll scroll to it and ignore the following element that is a result of this.
        if restoreLastImage,
           let items = await iterator.next() {
          if let item = images.currentItem {
            if columnVisibility != .detailOnly {
              await images.sidebar.send(ImagesModelSidebarElement(item: item.id, isSelected: false))
            }

            await images.detail.send(item.id)

            _ = await iterator.next()
          } else {
            self.images.visibleItems = items
            self.images.isHighlighted = !self.images.visibleItems.isEmpty && self.images.visibleItems.allSatisfy(\.isHighlighted)
            await images.setCurrentItem(item: items.first)
          }
        }

        while let items = await iterator.next() {
          self.images.visibleItems = items
          self.images.isHighlighted = !self.images.visibleItems.isEmpty && self.images.visibleItems.allSatisfy(\.isHighlighted)
          await images.setCurrentItem(item: items.first)
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
}
