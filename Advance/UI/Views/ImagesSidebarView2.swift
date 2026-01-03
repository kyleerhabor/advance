//
//  ImagesSidebarView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/30/25.
//

import AdvanceCore
import SwiftUI
import OSLog

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

@MainActor
struct ImagesSidebarSelectionID {
  let images: ImagesModel
  let selection: Set<ImagesItemModel2.ID>
  let isSidebarShowSelectActive: Bool
}

extension ImagesSidebarSelectionID: @MainActor Equatable {}

struct ImagesSidebarItemView2: View {
  let item: ImagesItemModel2

  var body: some View {
    ImagesItemImageView(item: item, image: item.sidebarImage, phase: item.sidebarImagePhase)
  }
}

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
  @Binding var copyFolderSelection: Set<ImagesItemModel2.ID>
  @Binding var copyFolderError: ImagesModelCopyFolderError?
  @Binding var isCopyFolderErrorPresented: Bool
  @State private var isCopyFolderFileImporterPresented = false
  @State private var isSidebarShowSelectActive = false
  @FocusState private var isFocused
  private var sceneID: AppModelCommandSceneID {
    .imagesSidebar(self.images.id)
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(images.items, selection: $selection) { item in
        VStack {
          ImagesSidebarItemView2(item: item)
            .anchorPreference(key: ImagesItemsPreferenceKey.self, value: .bounds) { anchor in
              [ImagesItemPreferenceValue(item: item, anchor: anchor)]
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
      .backgroundPreferenceValue(ImagesItemsPreferenceKey.self) { value in
        GeometryReader { proxy in
          Color.clear
            .task(id: value) {
              let frame = proxy.frame(in: .local)
              let items = value
                .map { ImagesItemModelResample(item: $0.item, frame: proxy[$0.anchor]) }
                .filter { frame.intersects($0.frame) }

              guard let item = items.first else {
                return
              }

              let width = item.frame.width

              guard width != 0 else {
                return
              }

              await self.images.sidebarResample.send(ImagesModelResample(width: width, items: items.map(\.item)))
            }
        }
      }
      .task(id: self.images) {
        for await resample in self.images.sidebarResample.removeDuplicates() {
          var items = [ImagesItemModel2](reservingCapacity: resample.items.count + 8)

          // TODO: Reimplement to prioritize images.
          //
          // In general:
          //
          //   [A, B, C, D, E, F, G]
          //
          // Could be processed as:
          //
          //   [D, C, E, B, F, A, G]
          //
          // To see if the user finds it more responsive.

          if let index = self.images.items.index(id: resample.items.first!.id) {
            let item1 = self.images.items.before(index: index)
            let item2 = item1.flatMap { self.images.items.before(index: $0.index) }
            let item3 = item2.flatMap { self.images.items.before(index: $0.index) }
            let item4 = item3.flatMap { self.images.items.before(index: $0.index) }

            item4.map { items.append($0.element) }
            item3.map { items.append($0.element) }
            item2.map { items.append($0.element) }
            item1.map { items.append($0.element) }
          }

          items.append(contentsOf: resample.items)

          if let index = self.images.items.index(id: resample.items.last!.id) {
            let item1 = self.images.items.after(index: index)
            let item2 = item1.flatMap { self.images.items.after(index: $0.index) }
            let item3 = item2.flatMap { self.images.items.after(index: $0.index) }
            let item4 = item3.flatMap { self.images.items.after(index: $0.index) }

            item1.map { items.append($0.element) }
            item2.map { items.append($0.element) }
            item3.map { items.append($0.element) }
            item4.map { items.append($0.element) }
          }

          await self.images.loadImages(in: .sidebar, items: items, width: resample.width, pixelLength: pixelLength)
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
}
