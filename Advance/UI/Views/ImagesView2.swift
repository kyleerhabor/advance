//
//  ImagesView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/23/25.
//

import AdvanceCore
import AsyncAlgorithms
import OSLog
import SwiftUI
import VisionKit

enum ImagesItemLoadImagePhase {
  case empty, success, failure
}

struct ImagesItemView2: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.pixelLength) private var pixelLength
  @State private var image = NSImage()
  @State private var phase = ImagesItemLoadImagePhase.empty
  @State private var hasElapsed = false
  @State private var channel = AsyncChannel<Double>()
  let item: ImagesItemModel2

  var body: some View {
    Image(nsImage: image)
      .resizable()
      .background(.fill.quaternary.visible(phase != .success), in: .rect)
      .animation(.default, value: phase == .success)
      .overlay {
        let isVisible = phase == .empty && hasElapsed

        ProgressView()
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .overlay {
        let isVisible = phase == .failure

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
      .task {
        let lengths = chain(
          channel.prefix(1),
          channel.dropFirst().debounce(for: .microhang),
        )

        for await length in lengths {
          let image = await images.loadImage(item: item.id, length: length / pixelLength)

          guard !Task.isCancelled else {
            return
          }

          self.image = image ?? NSImage()
          self.phase = image == nil ? .failure : .success
        }
      }
      .onGeometryChange(for: Double.self) { geometry in
        geometry.size.length
      } action: { length in
        Task {
          await channel.send(length)
        }
      }
  }
}

struct ImagesDetailItemView2: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.pixelLength) private var pixelLength
  @State private var hasElapsed = false
  @State private var channel = AsyncChannel<Double>()
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
struct ImagesSidebarSelectionID {
  let images: ImagesModel
  let selection: Set<ImagesItemModel2.ID>
  let isSidebarShowSelectActive: Bool
}

extension ImagesSidebarSelectionID: @MainActor Equatable {}

struct ImagesSidebarView2: View {
  @Environment(\.locale) private var locale
  @Environment(ImagesModel.self) private var images
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @Binding var columnVisibility: NavigationSplitViewVisibility
  @Binding var selection: Set<ImagesItemModel2.ID>
  @Binding var isFileImporterPresented: Bool
  @Binding var copyFolderSelection: Set<ImagesItemModel2.ID>
  @Binding var copyFolderError: ImagesModelCopyFolderError?
  @Binding var isCopyFolderErrorPresented: Bool
  @FocusState private var isFocused
  @State private var isCopyFolderFileImporterPresented = false
  @State private var isSidebarShowSelectActive = false
  private var directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions {
    StorageKeys.directoryEnumerationOptions(
      importHiddenFiles: importHiddenFiles,
      importSubdirectories: importSubdirectories,
    )
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(images.items, selection: $selection) { item in
        VStack {
          ImagesItemView2(item: item)
            .overlay(alignment: .topTrailing) {
              // TODO: Figure out how to draw a white outline.
              //
              // I don't know how to do the above, so I'm using opacity to create depth as a fallback.
              Image(systemName: "bookmark.fill")
                .font(.title)
                .imageScale(.small)
                .symbolRenderingMode(.multicolor)
                .opacity(0.85)
                .shadow(radius: 0.5)
                .padding(4)
                .visible(item.isBookmarked)
            }

          Text(item.title)
            .font(.subheadline)
            .padding(EdgeInsets(vertical: 4, horizontal: 8))
            .background(.fill.tertiary, in: .rect(cornerRadius: 4))
            .help(item.title)
        }
      }
      .focused($isFocused)
      .contextMenu { ids in
        Group {
          Section {
            Button("Finder.Item.Show", systemImage: "finder") {
              Task {
                await images.showFinder(items: ids)
              }
            }
          }

          Section {
            Button("Images.Item.Copy", systemImage: "document.on.document") {
              Task {
                await images.copy(items: ids)
              }
            }

            ImagesSidebarItemCopyFolderView(
              selection: $copyFolderSelection,
              isFileImporterPresented: $isCopyFolderFileImporterPresented,
              error: $copyFolderError,
              isErrorPresented: $isCopyFolderErrorPresented,
              items: ids,
            )
          }

          Section {
            let isBookmarked = images.isBookmarked(items: ids)

            Button(
              isBookmarked ? "Images.Item.Bookmark.Remove" : "Images.Item.Bookmark.Add",
              systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
            ) {
              Task {
                await images.bookmark(items: ids, isBookmarked: !images.isBookmarked(items: ids))
              }
            }
          }
        }
        .disabled(images.isInvalidSelection(of: ids))
      }
      .copyable(images.urls(ofItems: selection))
      .overlay {
        ContentUnavailableView {
          Button {
            isFileImporterPresented = true
          } label: {
            Label("Images.Sidebar.Import", systemImage: "square.and.arrow.down")
              .labelStyle(ImagesSidebarImportLabelStyle())
          }
          .buttonStyle(.plain)
          .disabled(!images.hasLoadedNoImages)
          .visible(images.hasLoadedNoImages)
        }
      }
      .onChange(
        of: ImagesSidebarSelectionID(
          images: images,
          selection: selection,
          isSidebarShowSelectActive: isSidebarShowSelectActive,
        ),
      ) { prior, id in
        guard id.images == prior.images else {
          return
        }

        guard !id.isSidebarShowSelectActive else {
          isSidebarShowSelectActive = false

          return
        }

        guard !prior.isSidebarShowSelectActive else {
          return
        }

        // TODO: Document.
        let difference = id.selection.subtracting(prior.selection)

        guard let item = images.items.last(where: { difference.contains($0.id) }) else {
          return
        }

        Task {
          await images.detail.send(item.id)
        }
      }
      .task(id: images) {
        for await element in images.sidebar {
          if element.isSelected {
            isSidebarShowSelectActive = true
            selection = [element.item]
          }

          // TODO: Figure out how to finish scrolling off-screen before showing columns.
          //
          // For some reason, animating scrollTo(_:anchor:) causes it to scroll in the 'viewport,' rather than the whole
          // list.
          withAnimation {
            // The difference between all and automatic is that automatic always performs its animation, whereas all
            // will perform it if the sidebar is not visible. That is, if the sidebar is visible, all won't delay the
            // user.
            columnVisibility = .all
          } completion: {
            isFocused = true

            proxy.scrollTo(element.item, anchor: .center)
          }
        }
      }
      .dropDestination(for: ImagesItemTransfer.self) { items, _ in
        Task {
          await images.store(items: items, enumerationOptions: directoryEnumerationOptions)
        }

        return true
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
            items: images.items.ids.filter(in: copyFolderSelection),
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
  let hash: Data
  let phase: ImagesItemModelImagePhase
}

extension ImagesDetailViewLiveTextID: Equatable {}

struct ImagesDetailView2: View {
  @Environment(ImagesModel.self) private var images
  @Environment(SearchSettingsModel.self) private var search
  @Environment(\.locale) private var locale
  @Environment(\.pixelLength) private var pixelLength
  @Environment(\.openURL) private var openURL
  @AppStorage(StorageKeys.isSystemSearchEnabled) private var isSystemSearchEnabled
  @AppStorage(StorageKeys.restoreLastImage) private var restoreLastImage
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @Binding var copyFolderError: ImagesModelCopyFolderError?
  @Binding var isCopyFolderErrorPresented: Bool
  @State private var copyFolderSelection: ImagesItemModel2.ID?
  @State private var isCopyFolderFileImporterPresented = false
  @State private var currentItems = AsyncChannel<ImagesItemModel2?>()
  @State private var resamples = AsyncChannel<ImagesDetailResample>()
  @State private var searchError: SearchSettingsModelEngineURLError?
  @State private var isSearchErrorPresented = false
  private var preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes {
    var interactionTypes = ImageAnalysisOverlayView.InteractionTypes()

    if isLiveTextEnabled {
      interactionTypes.insert(.automaticTextOnly)
    }

    if isLiveTextSubjectEnabled {
      interactionTypes.insert([.imageSubject, .visualLookUp])
    }

    return interactionTypes
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(images.items) { item in
        // TODO: Figure out how to remove the border when the context menu is open.
//        ImagesItemView2(item: item)
        ImagesDetailItemView2(item: item)
          .overlay {
            ImageAnalysisView2(
              analysis: item.imageAnalysis,
              preferredInteractionTypes: preferredInteractionTypes,
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
                let action = Selector(("_searchWithGoogleFromMenu:"))
                let index = menu.items.firstIndex { $0.action == action }

                if let index {
                  menu.removeItem(at: index)

                  if let engine = search.engine {
                    let item = NSMenuItem()
                    item.title = String(localized: "Images.Item.LiveText.Search.\(engine.name)", locale: locale)
                    item.target = delegate
                    item.action = #selector(delegate.action(_:))
                    delegate.actions[item] = {
                      Task {
                        let url: URL?

                        do {
                          url = try await search.url(
                            of: engine.id,
                            query: overlayView.selectedText,
                            locale: locale,
                          )
                        } catch let error as SearchSettingsModelEngineURLError {
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

                    menu.insertItem(item, at: index)
                  }
                }
              }

              return menu
            }
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
              Button(
                item.isBookmarked ? "Images.Item.Bookmark.Remove" : "Images.Item.Bookmark.Add",
                systemImage: item.isBookmarked ? "bookmark.fill" : "bookmark"
              ) {
                Task {
                  await images.bookmark(item: item.id, isBookmarked: !item.isBookmarked)
                }
              }
            }
          }
          .listRowInsets(.listRow)
          .listRowSeparator(.hidden)
          .task(id: ImagesDetailViewLiveTextID(hash: item.detailImageHash, phase: item.detailImagePhase)) {
            var types = ImageAnalysisTypes()

            if isLiveTextEnabled {
              types.insert(.text)
            }

            if isLiveTextSubjectEnabled {
              types.insert(.visualLookUp)
            }

            await images.loadImageAnalysis(for: item, types: types)
          }
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

              await resamples.send(ImagesDetailResample(width: frame.width, items: items))
              await currentItems.send(items.first)
            }
        }
      }
      .task(id: images) {
        guard !Task.isCancelled else {
          return
        }

        for await resample in resamples.removeDuplicates() {
          var items = [ImagesItemModel2.ID](reservingCapacity: resample.items.count + 4)

          if let item = resample.items.first,
             let index = images.items.index(id: item.id) {
            let item1 = images.items.before(index: index)
            let item2 = item1.flatMap { images.items.before(index: $0.index) }
//            let item3 = item2.flatMap { images.items.before(index: $0.index) }
//
//            item3.map { items.append($0.element.id) }
            item2.map { items.append($0.element.id) }
            item1.map { items.append($0.element.id) }
          }

          items.append(contentsOf: resample.items.map(\.id))

          if let item = resample.items.last,
             let index = images.items.index(id: item.id) {
            let item1 = images.items.after(index: index)
            let item2 = item1.flatMap { images.items.after(index: $0.index) }
//            let item3 = item2.flatMap { images.items.after(index: $0.index) }
//
//            item3.map { items.append($0.element.id) }
            item2.map { items.append($0.element.id) }
            item1.map { items.append($0.element.id) }
          }

          await images.loadImages(items: items, width: resample.width, pixelLength: pixelLength)
        }
      }
      .task(id: images) {
        guard !Task.isCancelled else {
          return
        }

        // For some reason, scrolling via the sidebar may cause this to output nil, immediately followed by a proper
        // item. Debouncing defends against this, but is not a sound solution, since it's based on time, rather than
        // state.
        var iterator = currentItems
          // Drop the current item before items have been loaded (that is, nil).
          .dropFirst()
          // Remove duplicate current items.
          .removeDuplicates()
          .makeAsyncIterator()

        // At this point, items have been loaded and we need to account for whether or not we have a current item. If we
        // have one, we'll scroll to it and ignore the following element that is a result of this.
        if restoreLastImage,
           let item = await iterator.next() {
          if let item = images.currentItem {
            await images.sidebar.send(ImagesModelSidebarElement(item: item.id, isSelected: false))
            await images.detail.send(item.id)

            _ = await iterator.next()
          } else {
            await images.setCurrentItem(item: item)
          }
        }

        while let item = await iterator.next() {
          await images.setCurrentItem(item: item)
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

struct ImagesBackgroundView: View {
  @Environment(ImagesModel.self) private var images
  let selection: Set<ImagesItemModel2.ID>

  var body: some View {
    let isInvalidSelection = images.isInvalidSelection(of: selection)

    Color.clear
      .focusedSceneValue(\.commandScene, AppModelCommandScene(
        id: .images(images.id),
        disablesShowFinder: isInvalidSelection,
        // If there are many items, supporting this would be a disaster.
        disablesOpenFinder: true,
        disablesShowSidebar: images.currentItem == nil,
        disablesBookmark: isInvalidSelection,
        disablesResetWindowSize: false,
      ))
      .transform { content in
        if let item = images.currentItem {
          content
            .navigationTitle(item.title)
            .navigationDocument(item.url)
        } else {
          content
        }
      }
  }
}

struct ImagesView2: View {
  @Environment(AppModel.self) private var app
  @Environment(Window.self) private var windowed
  @Environment(ImagesModel.self) private var images
  @Environment(FoldersSettingsModel.self) private var folders
  @Environment(\.appearsActive) private var appearsActive
  @Environment(\.locale) private var locale
  @Environment(\.isTrackingMenu) private var isTrackingMenu
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @AppStorage(StorageKeys.hiddenLayout) private var hiddenLayout
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibilityStorage
  @State private var columnVisibility = StorageKeys.columnVisibility.defaultValue.columnVisibility
  @State private var selection = Set<ImagesItemModel2.ID>()
  @State private var isFileImporterPresented = false
  @State private var copyFolderSelection = Set<ImagesItemModel2.ID>()
  @State private var copyFolderError: ImagesModelCopyFolderError?
  @State private var isCopyFolderErrorPresented = false
  private var directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions {
    StorageKeys.directoryEnumerationOptions(
      importHiddenFiles: importHiddenFiles,
      importSubdirectories: importSubdirectories,
    )
  }

  private var sceneID: AppModelCommandSceneID {
    .images(images.id)
  }

  var body: some View {
    // For some reason, we're unable to accurately implement this for windows restored into full-screen mode. While
    // columnVisibility is set to its default value (automatic), setting it to its scene value causes the sidebar to
    // appear, which is unexpected. We can't move the backing SceneStorage to the database since it's too slow, so we're
    // stuck with this until we reimplement hiding on scroll.
    let isVisible = !hiddenLayout.scroll || isTrackingMenu || !appearsActive || !isWindowFullScreen || columnVisibility != .detailOnly

    NavigationSplitView(columnVisibility: $columnVisibility) {
      ImagesSidebarView2(
        columnVisibility: $columnVisibility,
        selection: $selection,
        isFileImporterPresented: $isFileImporterPresented,
        copyFolderSelection: $copyFolderSelection,
        copyFolderError: $copyFolderError,
        isCopyFolderErrorPresented: $isCopyFolderErrorPresented,
      )
      .navigationSplitViewColumnWidth(min: 128, max: 256)
    } detail: {
      ImagesDetailView2(copyFolderError: $copyFolderError, isCopyFolderErrorPresented: $isCopyFolderErrorPresented)
    }
    .toolbar(isWindowFullScreen ? .hidden : .automatic)
    .cursorVisible(isVisible)
    .scrollIndicators(isVisible ? .automatic : .hidden)
    .background {
      ImagesBackgroundView(selection: selection)
    }
    .alert(isPresented: $isCopyFolderErrorPresented, error: copyFolderError) {}
    .fileImporter(
      isPresented: $isFileImporterPresented,
      allowedContentTypes: imagesContentTypes,
      allowsMultipleSelection: true,
    ) { result in
      let urls: [URL]

      switch result {
        case let .success(x):
          urls = x
        case let .failure(error):
          // TODO: Elaborate.
          Logger.ui.error("\(error)")

          return
      }

      Task {
        await images.store(urls: urls, directoryEnumerationOptions: directoryEnumerationOptions)
      }
    }
    .fileDialogCustomizationID(ImagesScene.id)
    .task(id: images) {
      guard !Task.isCancelled else {
        return
      }

      await images.load2()
    }
    .onReceive(app.commandsPublisher) { command in
      onCommand(command)
    }
    .onChange(of: columnVisibility) {
      columnVisibilityStorage = StorageColumnVisibility(columnVisibility)
    }
  }

  func onCommand(_ command: AppModelCommand) {
    guard command.sceneID == sceneID else {
      return
    }

    switch command.action {
      case .open:
        guard images.hasLoadedNoImages else {
          app.isImagesFileImporterPresented = true

          return
        }

        isFileImporterPresented = true
      case .showFinder:
        Task {
          await images.showFinder(items: selection)
        }
      case .openFinder:
        unreachable()
      case .showSidebar:
        guard let item = images.currentItem else {
          return
        }

        Task {
          await images.sidebar.send(ImagesModelSidebarElement(item: item.id, isSelected: true))
        }
      case .bookmark:
        Task {
          await images.bookmark(items: selection, isBookmarked: !images.isBookmarked(items: selection))
        }
      case .resetWindowSize:
        windowed.window?.setContentSize(ImagesScene.defaultSize)
    }
  }
}
