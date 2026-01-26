//
//  ImagesSidebarView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/30/25.
//

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
  let isBookmarked: Bool
//  let isImageAnalysisSupplementaryInterfaceVisible: Bool

  var body: some View {
    let isInvalidSelection = self.images.isInvalidSelection(of: self.selection)

    Color.clear
      .focusedSceneValue(
        \.commandScene,
        AppModelCommandScene(
          id: .imagesSidebar(self.images.id),
          showFinder: AppModelActionCommand(isDisabled: isInvalidSelection),
          openFinder: AppModelActionCommand(isDisabled: true),
          showSidebar: AppModelActionCommand(isDisabled: self.images.currentItem == nil),
          sidebarBookmarks: AppModelToggleCommand(isDisabled: false, isOn: self.isBookmarked),
          bookmark: AppModelToggleCommand(
            isDisabled: isInvalidSelection,
            isOn: self.images.isBookmarked(items: self.selection),
          ),
//          liveTextIcon: AppModelToggleCommand(
//            isDisabled: !self.isLiveTextEnabled,
//            isOn: self.isImageAnalysisSupplementaryInterfaceVisible,
//          ),
          liveTextHighlight: AppModelToggleCommand(
            isDisabled: !self.isLiveTextEnabled || self.images.visibleItems.isEmpty,
            isOn: self.images.isHighlighted,
          ),
          resetWindowSize: AppModelActionCommand(isDisabled: false),
        ),
      )
  }
}

@MainActor
struct ImagesSidebarSelectionID {
  let images: ImagesModel
  let selection: Set<ImagesItemModel2.ID>
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
  @Binding var isBookmarked: Bool
//  @Binding var isImageAnalysisSupplementaryInterfaceVisible: Bool
  @Binding var isFileImporterPresented: Bool
  @State private var selection = Set<ImagesItemModel2.ID>()
  @State private var isShowSidebarSet = false
  @State private var currentItem: ImagesItemModel2?
  @State private var bookmarkCurrentItem: ImagesItemModel2?
  @State private var copyFolderSelection = Set<ImagesItemModel2.ID>()
  @State private var isCopyFolderFileImporterPresented = false
  @State private var copyFolderError: ImagesModelCopyFolderError?
  @State private var isCopyFolderErrorPresented = false
  @FocusState private var isFocused
  private var sceneID: AppModelCommandSceneID {
    .imagesSidebar(self.images.id)
  }

  private var directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions {
    StorageKeys.directoryEnumerationOptions(
      importHiddenFiles: self.importHiddenFiles,
      importSubdirectories: self.importSubdirectories,
    )
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(selection: $selection) {
        ForEach(self.images.sidebarItems) { item in
          ImagesSidebarItemView(item: item)
        }
        // I think the following before methods are wrong because offset being equal to the end index doesn't mean that
        // it's the case for self.items.
        .dropDestination(for: URL.self) { items, offset in
          Task {
            await self.images.store(
              items: items,
              before: offset == self.images.sidebarItems.endIndex ? nil : self.images.sidebarItems[offset],
              directoryEnumerationOptions: self.directoryEnumerationOptions,
            )
          }
        }
        .onMove { items, offset in
          Task {
            await self.images.store(
              items: items.map { self.images.sidebarItems[$0] },
              before: offset == self.images.sidebarItems.endIndex ? nil : self.images.sidebarItems[offset],
            )
          }
        }
        .onDelete { items in
          Task {
            await self.images.remove(items: items.map { self.images.sidebarItems[$0] })
          }
        }
      }
      .contextMenu { ids in
        Group {
          var items: [ImagesItemModel2] {
            self.images.items.filter(in: ids, by: \.id)
          }

          Section {
            Button("Finder.Item.Show", systemImage: "finder") {
              Task {
                await self.images.showFinder(items: items)
              }
            }
          }

          Section {
            Button("Images.Item.Copy", systemImage: "document.on.document") {
              Task {
                await self.images.copy(items: items)
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
            let isBookmarked = self.images.isBookmarked(items: ids)

            Button(
              isBookmarked ? "Images.Item.Bookmark.Remove" : "Images.Item.Bookmark.Add",
              systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
            ) {
              Task {
                await self.images.bookmark(items: ids, isBookmarked: !self.images.isBookmarked(items: ids))
              }
            }
          }
        }
        .disabled(self.images.isInvalidSelection(of: ids))
      }
      .focused($isFocused)
      .overlay {
        ContentUnavailableView {
          Button {
            self.isFileImporterPresented = true
          } label: {
            Label("Images.Sidebar.Import", systemImage: "square.and.arrow.down")
              .labelStyle(ImagesSidebarImportLabelStyle())
          }
          .buttonStyle(.plain)
          .disabled(!self.images.hasLoadedNoImages)
          .visible(self.images.hasLoadedNoImages)
          .animation(.default, value: self.images.hasLoadedNoImages)
          .transaction(
            value: self.images.hasLoadedNoImages,
            setter(on: \.disablesAnimations, value: !self.images.hasLoadedNoImages),
          )
        }
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        VStack(spacing: 0) {
          Divider()

          HStack {
            Spacer()

            @Bindable var images = self.images
            let key: LocalizedStringKey = self.isBookmarked
              ? "Images.Sidebar.Bookmark.Hide"
              : "Images.Sidebar.Bookmark.Show"

            Toggle(key, systemImage: self.isBookmarked ? "bookmark.fill" : "bookmark", isOn: $isBookmarked)
              .toggleStyle(.button)
              .buttonStyle(.plain)
              .labelStyle(.iconOnly)
              .help(key)
              .font(.system(size: 13))
              .foregroundStyle(Color(self.isBookmarked ? .controlAccentColor : .secondaryLabelColor))
              .onChange(of: self.isBookmarked) {
                guard let currentItem = self.isBookmarked ? self.bookmarkCurrentItem : self.currentItem else {
                  return
                }

                Task {
                  await images.sidebar.send(ImagesModelSidebarElement(item: currentItem.id, isSelected: false))
                }
              }
          }
          .padding(10)
        }
      }
      .overlay {
        if images.hasLoadedNoImages {
          Color.clear
            .dropDestination(for: ImagesItemTransfer.self) { items, _ in
              Task {
                await self.images.store(items: items, directoryEnumerationOptions: self.directoryEnumerationOptions)
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

              let currentItem = items.middleItem

              if self.isBookmarked {
                self.bookmarkCurrentItem = currentItem?.item
              } else {
                self.currentItem = currentItem?.item
              }

              guard let item = items.first else {
                return
              }

              // According to AsyncChannel/send(_:),
              //
              //   If the task is cancelled, this function will resume without sending the element.
              //
              // I've found that it can still send the element when the task is canceled. While we could check for
              // cancellation, it's unnecessary since the debouncer will act first.
              await images.sidebarResample.send(
                ImagesModelResample(width: item.frame.width, items: items.map(\.item)),
              )
            }
        }
      }
      .task(id: ImagesViewResampleID(images: self.images, pixelLength: self.pixelLength)) {
        var task: Task<Void, Never>?

        for await resample in self.images.sidebarResample.removeDuplicates().debounce(for: .microhang) {
          task?.cancel()
          task = Task {
            await self.images.loadSidebarImages(
              items: await self.resample(resample),
              parameters: ImagesItemModelImageParameters(width: resample.width / self.pixelLength),
            )
          }
        }

        task?.cancel()
      }
      .copyable(self.images.urls(ofItems: self.selection))
      .onChange(of: ImagesSidebarSelectionID(images: self.images, selection: self.selection)) { prior, id in
        guard !self.isShowSidebarSet else {
          self.isShowSidebarSet = false

          return
        }

        // TODO: Document.
        let difference = id.selection.subtracting(prior.selection)
        let item = id.images.sidebarItems.last { difference.contains($0.id) }

        guard let item else {
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
            self.isShowSidebarSet = true
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
      ImagesSidebarBackgroundView(
        selection: self.selection,
        isBookmarked: self.isBookmarked,
//        isImageAnalysisSupplementaryInterfaceVisible: self.isImageAnalysisSupplementaryInterfaceVisible,
      )
    }
    .alert(isPresented: $isCopyFolderErrorPresented, error: self.copyFolderError) {}
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
          try await self.images.copyFolder(
            items: self.images.items.filter(in: self.copyFolderSelection, by: \.id),
            to: url,
            locale: self.locale,
            resolveConflicts: self.resolveConflicts,
            pathDirection: self.foldersPathDirection,
            pathSeparator: self.foldersPathSeparator,
          )
        } catch let error as ImagesModelCopyFolderError {
          self.copyFolderError = error
          self.isCopyFolderErrorPresented = true
        }
      }
    }
    .fileDialogCustomizationID(FoldersSettingsScene.id)
    .onDeleteCommand {
      Task {
        await self.images.remove(items: self.images.items.filter(in: self.selection, by: \.id))
      }
    }
    .onReceive(self.app.commandsPublisher) { command in
      self.onCommand(command)
    }
  }

  func onCommand(_ command: AppModelCommand) {
    guard command.sceneID == sceneID else {
      return
    }

    switch command.action {
      case .open:
        guard self.images.hasLoadedNoImages else {
          self.app.isImagesFileImporterPresented = true

          return
        }

        self.isFileImporterPresented = true
      case .showFinder:
        Task {
          await self.images.showFinder(items: self.images.items.filter(in: self.selection, by: \.id))
        }
      case .openFinder:
        unreachable()
      case .showSidebar:
        guard let item = self.images.currentItem else {
          return
        }

        Task {
          await self.images.sidebar.send(ImagesModelSidebarElement(item: item.id, isSelected: true))
        }
      case .toggleSidebarBookmarks:
        self.isBookmarked.toggle()
      case .bookmark:
        Task {
          await self.images.bookmark(
            items: self.selection,
            isBookmarked: !self.images.isBookmarked(items: self.selection),
          )
        }
//      case .toggleLiveTextIcon:
//        self.isImageAnalysisSupplementaryInterfaceVisible.toggle()
      case .toggleLiveTextHighlight:
        self.images.isHighlighted.toggle()
        self.images.highlight(items: self.images.visibleItems, isHighlighted: self.images.isHighlighted)
      case .resetWindowSize:
        self.window.window?.setContentSize(ImagesScene.defaultSize)
    }
  }

  func resample(_ resample: ImagesModelResample) async -> [ImagesItemModel2] {
    var items = [ImagesItemModel2](reservingCapacity: resample.items.count + 8)
    items.append(contentsOf: resample.items)

    let before1: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let before2: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let before3: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let before4: IdentifiedArrayOf<ImagesItemModel2>.Index?

    if let index = self.images.sidebarItems.index(id: resample.items.first!.id) {
      before1 = self.images.sidebarItems.subscriptIndex(before: index)
      before2 = before1.flatMap { self.images.sidebarItems.subscriptIndex(before: $0) }
      before3 = before2.flatMap { self.images.sidebarItems.subscriptIndex(before: $0) }
      before4 = before3.flatMap { self.images.sidebarItems.subscriptIndex(before: $0) }
    } else {
      before1 = nil
      before2 = nil
      before3 = nil
      before4 = nil
    }

    let after1: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let after2: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let after3: IdentifiedArrayOf<ImagesItemModel2>.Index?
    let after4: IdentifiedArrayOf<ImagesItemModel2>.Index?

    if let index = self.images.sidebarItems.index(id: resample.items.last!.id) {
      after1 = self.images.sidebarItems.subscriptIndex(after: index)
      after2 = after1.flatMap { self.images.sidebarItems.subscriptIndex(after: $0) }
      after3 = after2.flatMap { self.images.sidebarItems.subscriptIndex(after: $0) }
      after4 = after3.flatMap { self.images.sidebarItems.subscriptIndex(after: $0) }
    } else {
      after1 = nil
      after2 = nil
      after3 = nil
      after4 = nil
    }

    before1.map { items.append(self.images.sidebarItems[$0]) }
    after1.map { items.append(self.images.sidebarItems[$0]) }
    before2.map { items.append(self.images.sidebarItems[$0]) }
    after2.map { items.append(self.images.sidebarItems[$0]) }
    before3.map { items.append(self.images.sidebarItems[$0]) }
    after3.map { items.append(self.images.sidebarItems[$0]) }
    before4.map { items.append(self.images.sidebarItems[$0]) }
    after4.map { items.append(self.images.sidebarItems[$0]) }

    return items
  }
}
