//
//  ImagesSidebarView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/30/25.
//

import AdvanceCore
import AsyncAlgorithms
import IdentifiedCollections
import SwiftUI
import OSLog

struct ImagesSidebarImportLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 4) {
      configuration.icon
        .font(.title)
        .imageScale(.large)
        .symbolRenderingMode(.hierarchical)

      configuration.title
        .font(.callout)
    }
    .fontWeight(.medium)
  }
}

struct ImagesSidebarBackgroundView: View {
  @Environment(ImagesModel.self) private var images
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  let selection: Set<ImagesItemModel2.ID>
  let isSupplementaryInterfaceVisible: Bool

  var body: some View {
    let isInvalidSelection = self.images.isInvalidSelection(of: self.selection)

    Color.clear
      .focusedSceneValue(\.commandScene, AppModelCommandScene(
        id: .imagesSidebar(self.images.id),
        showFinder: AppModelActionCommand(isDisabled: isInvalidSelection),
        openFinder: AppModelActionCommand(isDisabled: true),
        showSidebar: AppModelActionCommand(isDisabled: self.images.currentItem == nil),
        bookmark: AppModelToggleCommand(isDisabled: isInvalidSelection, isOn: self.images.isBookmarked(items: selection)),
        liveTextIcon: AppModelToggleCommand(isDisabled: !self.isLiveTextEnabled, isOn: self.isSupplementaryInterfaceVisible),
        liveTextHighlight: AppModelToggleCommand(
          isDisabled: !self.isLiveTextEnabled || self.images.visibleItems.isEmpty,
          isOn: self.images.isHighlighted,
        ),
        resetWindowSize: AppModelActionCommand(isDisabled: false),
      ))
  }
}

struct ImagesSidebarItemImageView: View {
  let item: ImagesItemModel2

  var body: some View {
    ImagesItemImageView(
      item: self.item,
      aspectRatio: self.item.sidebarAspectRatio,
      image: self.item.sidebarImage,
      phase: self.item.sidebarImagePhase,
    )
  }
}

struct ImagesSidebarItemView: View {
  let item: ImagesItemModel2

  var body: some View {
    VStack {
      ImagesSidebarItemImageView(item: item)
        .anchorPreference(key: ImagesVisibleItemsPreferenceKey.self, value: .bounds) { anchor in
          [ImagesVisibleItem(item: item, anchor: anchor)]
        }
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
}

@MainActor
struct ImagesSidebarSelectionID {
  let images: ImagesModel
  let selection: Set<ImagesItemModel2.ID>
//  let isSidebarShowSelectActive: Bool
}

extension ImagesSidebarSelectionID: @MainActor Equatable {}

struct ImagesSidebarView2: View {
  @Environment(AppModel.self) private var app
  @Environment(Window.self) private var window
  @Environment(ImagesModel.self) private var images
  @Environment(\.locale) private var locale
  @Environment(\.pixelLength) private var pixelLength
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @Binding var columnVisibility: NavigationSplitViewVisibility
  @Binding var isSupplementaryInterfaceVisible: Bool
  @Binding var selection: Set<ImagesItemModel2.ID>
  @Binding var isFileImporterPresented: Bool
  @Binding var copyFolderError: ImagesModelCopyFolderError?
  @Binding var isCopyFolderErrorPresented: Bool
  @State private var isSelectionSet = false
  @State private var copyFolderSelection = Set<ImagesItemModel2.ID>()
  @State private var isCopyFolderFileImporterPresented = false
  @FocusState private var isFocused
  private var sceneID: AppModelCommandSceneID {
    .imagesSidebar(self.images.id)
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(images.items, selection: $selection) { item in
        ImagesSidebarItemView(item: item)
      }
      .focused($isFocused)
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
//      .overlay(alignment: .bottom) {
//        VStack(spacing: 0) {
//          Divider()
//
//          HStack {
//            Spacer()
//
//            Toggle("Bookmark", systemImage: "bookmark.fill", isOn: .constant(true))
//              .toggleStyle(.button)
//              .buttonStyle(.plain)
//              .labelStyle(.iconOnly)
//              .foregroundStyle(Color(.controlAccentColor))
//              .controlSize(.large)
//          }
//          .padding(10)
//        }
//      }
      .overlay {
        if images.hasLoadedNoImages {
          Color.clear
            .dropDestination(for: ImagesItemTransfer.self) { items, _ in
              Task {
                await images.store(
                  items: items,
                  enumerationOptions: StorageKeys.directoryEnumerationOptions(
                    importHiddenFiles: self.importHiddenFiles,
                    importSubdirectories: self.importSubdirectories,
                  ),
                )
              }

              return true
            }
        }
      }
      .backgroundPreferenceValue(ImagesVisibleItemsPreferenceKey.self) { value in
        GeometryReader { proxy in
          Color.clear
            .task(id: ImagesViewItemsID(images: self.images, items: value)) {
              let frame = proxy.frame(in: .local)
              let items = value
                .map { ImagesResolvedVisibleItem(item: $0.item, frame: proxy[$0.anchor]) }
                .filter { frame.intersects($0.frame) }

              guard let item = items.first else {
                return
              }

              // According to AsyncChannel/send(_:),
              //
              //   If the task is cancelled, this function will resume without sending the element.
              //
              // I've found that it can still send the element when the task is canceled. While we could check for
              // cancellation, it's unnecessary since the debouncer will act first.
              await self.images.sidebarResample.send(
                ImagesModelResample(width: item.frame.width, items: items.map(\.item)),
              )
            }
        }
      }
      .task(id: ImagesViewResampleID(images: self.images, pixelLength: self.pixelLength)) {
        for await resample in self.images.sidebarResample.removeDuplicates().debounce(for: .microhang) {
          await self.resample(resample)
        }
      }
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
      .onChange(of: ImagesSidebarSelectionID(images: self.images, selection: self.selection)) { prior, id in
        guard id.images == prior.images else {
          return
        }

        guard !self.isSelectionSet else {
          self.isSelectionSet = false

          return
        }

        // TODO: Document.
        let difference = id.selection.subtracting(prior.selection)

        guard let item = id.images.items.last(where: { difference.contains($0.id) }) else {
          return
        }

        Task {
          await id.images.detail.send(item.id)
        }
      }
      .task(id: self.images) {
        for await element in self.images.sidebar {
          if element.isSelected {
            self.selection = [element.item]
            self.isSelectionSet = true
          }

          // TODO: Figure out how to finish scrolling off-screen before showing columns.
          //
          // For some reason, animating scrollTo(_:anchor:) causes it to scroll in the 'viewport,' rather than the whole
          // list.
          withAnimation {
            // The difference between all and automatic is that automatic always performs its animation, whereas all
            // will perform it if the sidebar is not visible. That is, if the sidebar is visible, all won't delay the
            // user.
            self.columnVisibility = .all
          } completion: {
            self.isFocused = true
            proxy.scrollTo(element.item, anchor: .center)
          }
        }
      }
    }
    .background {
      ImagesSidebarBackgroundView(selection: selection, isSupplementaryInterfaceVisible: isSupplementaryInterfaceVisible)
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
    .onReceive(app.commandsPublisher) { command in
      onCommand(command)
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
      case .toggleLiveTextIcon:
        self.isSupplementaryInterfaceVisible.toggle()
      case .toggleLiveTextHighlight:
        self.images.isHighlighted.toggle()
        self.images.highlight(items: self.images.visibleItems, isHighlighted: self.images.isHighlighted)
      case .resetWindowSize:
        self.window.window?.setContentSize(ImagesScene.defaultSize)
    }
  }

  func resample(_ resample: ImagesModelResample) async {
    var items = [ImagesItemModel2](reservingCapacity: resample.items.count + 8)
    items.append(contentsOf: resample.items)

    let before1: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?
    let before2: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?
    let before3: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?
    let before4: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?

    if let index = self.images.items.index(id: resample.items.first!.id) {
      before1 = self.images.items.before(index: index)
      before2 = before1.flatMap { self.images.items.before(index: $0.index) }
      before3 = before2.flatMap { self.images.items.before(index: $0.index) }
      before4 = before3.flatMap { self.images.items.before(index: $0.index) }
    } else {
      before1 = nil
      before2 = nil
      before3 = nil
      before4 = nil
    }

    let after1: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?
    let after2: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?
    let after3: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?
    let after4: BidirectionalCollectionItem<IdentifiedArrayOf<ImagesItemModel2>>?

    if let index = self.images.items.index(id: resample.items.last!.id) {
      after1 = self.images.items.after(index: index)
      after2 = after1.flatMap { self.images.items.after(index: $0.index) }
      after3 = after2.flatMap { self.images.items.after(index: $0.index) }
      after4 = after3.flatMap { self.images.items.after(index: $0.index) }
    } else {
      after1 = nil
      after2 = nil
      after3 = nil
      after4 = nil
    }

    before1.map { items.append($0.element) }
    after1.map { items.append($0.element) }
    before2.map { items.append($0.element) }
    after2.map { items.append($0.element) }
    before3.map { items.append($0.element) }
    after3.map { items.append($0.element) }
    before4.map { items.append($0.element) }
    after4.map { items.append($0.element) }

    await self.images.loadImages(
      in: .sidebar,
      items: items,
      parameters: ImagesItemModelImageParameters(width: resample.width, pixelLength: self.pixelLength),
    )
  }
}
