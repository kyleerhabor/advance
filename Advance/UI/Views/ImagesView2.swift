//
//  ImagesView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/23/25.
//

import AsyncAlgorithms
import OSLog
import SwiftUI

@MainActor
struct ImagesResolvedVisibleItem {
  let item: ImagesItemModel2
  let frame: CGRect
}

@MainActor
struct ImagesVisibleItem {
  let item: ImagesItemModel2
  let anchor: Anchor<CGRect>
}

extension ImagesVisibleItem: @MainActor Equatable {}

struct ImagesVisibleItemsPreferenceKey: PreferenceKey {
  static let defaultValue = [ImagesVisibleItem]()

  static func reduce(value: inout [ImagesVisibleItem], nextValue: () -> [ImagesVisibleItem]) {
    value.append(contentsOf: nextValue())
  }
}

@MainActor
struct ImagesViewResampleID {
  let images: ImagesModel
  let pixelLength: CGFloat
}

extension ImagesViewResampleID: @MainActor Equatable {}

@MainActor
struct ImagesViewItemsID {
  let images: ImagesModel
  let items: [ImagesVisibleItem]
}

extension ImagesViewItemsID: @MainActor Equatable {}

struct ImagesBackgroundView: View {
  @Environment(ImagesModel.self) private var images
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @ImageAnalysisSupplementaryInterfaceVisibleStorage private var isImageAnalysisSupplementaryInterfaceVisible
  let isBookmarked: Bool

  var body: some View {
    Color.clear
      .focusedSceneValue(
        \.commandScene,
        AppModelCommandScene(
          id: .images(self.images.id),
          showFinder: AppModelActionCommand(isDisabled: self.images.currentItem == nil),
          openFinder: AppModelActionCommand(isDisabled: true),
          showSidebar: AppModelActionCommand(isDisabled: self.images.currentItem == nil),
          sidebarBookmarks: AppModelToggleCommand(isDisabled: false, isOn: self.isBookmarked),
          bookmark: AppModelToggleCommand(
            isDisabled: self.images.currentItem == nil,
            isOn: self.images.currentItem?.isBookmarked ?? false,
          ),
          liveTextIcon: AppModelToggleCommand(
            isDisabled: !self.isLiveTextEnabled,
            isOn: self.isImageAnalysisSupplementaryInterfaceVisible,
          ),
          liveTextHighlight: AppModelToggleCommand(
            isDisabled: !self.isLiveTextEnabled || self.images.visibleItems.isEmpty,
            isOn: self.images.isHighlighted,
          ),
          resetWindowSize: AppModelActionCommand(isDisabled: false),
        ),
      )
      .transform { content in
        if let item = self.images.currentItem {
          content
            .navigationTitle(item.title)
            .navigationDocument(item.url)
        } else {
          content
        }
      }
  }
}

@propertyWrapper
struct ImageAnalysisSupplementaryInterfaceVisibleStorage: DynamicProperty {
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextIconEnabled) private var isLiveTextIconEnabled
  @SceneStorage(StorageKeys.imageAnalysisSupplementaryInterfaceVisibility) private var visibility

  var wrappedValue: Bool {
    get {
      switch self.visibility {
        case .automatic: self.isLiveTextEnabled && self.isLiveTextIconEnabled
        case .visible: self.isLiveTextEnabled
        case .hidden: false
      }
    }
    nonmutating set {
      self.visibility = newValue ? .visible : .hidden
    }
  }

  var projectedValue: Binding<Bool> {
    Binding {
      self.wrappedValue
    } set: { newValue in
      self.wrappedValue = newValue
    }
  }
}

struct ImagesView2: View {
  @Environment(AppModel.self) private var app
  @Environment(Window.self) private var window
  @Environment(ImagesModel.self) private var images
  @Environment(\.appearsActive) private var appearsActive
  @Environment(\.isTrackingMenu) private var isTrackingMenu
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen
  @AppStorage(StorageKeys.hiddenLayout) private var hiddenLayout
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @ColumnVisibilityStorage private var columnVisibility
  @ImageAnalysisSupplementaryInterfaceVisibleStorage private var isImageAnalysisSupplementaryInterfaceVisible
  @State private var isBookmarked = false
  @State private var isActive = true
  @State private var isFileImporterPresented = false

  var body: some View {
    let isVisible = self.isTrackingMenu
      || !self.appearsActive
      || self.columnVisibility != .detailOnly
      || self.isActive

    NavigationSplitView(columnVisibility: $columnVisibility) {
      ImagesSidebarView2(
        isBookmarked: $isBookmarked,
        isFileImporterPresented: $isFileImporterPresented,
      )
      .navigationSplitViewColumnWidth(min: 128, ideal: 128, max: 256)
    } detail: {
      ImagesDetailView2()
        .frame(minWidth: 256)
        // For some reason, applying toolbar(id:content:) to the enclosing NavigationSplitView causes the app to crash.
        // This workaround is flawed since the sidebar toggle may appear in an overflow menu instead of the sidebar.
        //
        //   NSToolbar already contains an item with the identifier com.apple.SwiftUI.navigationSplitView.toggleSidebar.
        //   Duplicate items of this type are not allowed.
        .toolbar(id: "\(Bundle.appID).Images") {
          ToolbarItem(id: "\(Bundle.appID).Images.LiveTextIcon") {
            let key: LocalizedStringKey = self.isImageAnalysisSupplementaryInterfaceVisible
              ? "Images.Toolbar.LiveTextIcon.Hide"
              : "Images.Toolbar.LiveTextIcon.Show"

            Toggle(key, systemImage: "text.viewfinder", isOn: $isImageAnalysisSupplementaryInterfaceVisible)
              .help(key)
              .disabled(!self.isLiveTextEnabled)
          }
        }
    }
    .background {
      ImagesBackgroundView(isBookmarked: self.isBookmarked)
    }
    .toolbar(self.isWindowFullScreen ? .hidden : .automatic)
    .toolbarVisible(!self.hiddenLayout.toolbar || isVisible || self.isWindowFullScreen)
    .cursorVisible(!self.hiddenLayout.cursor || isVisible)
    .scrollIndicators(!self.hiddenLayout.scroll || isVisible ? .automatic : .hidden)
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
        await images.store(
          urls: urls,
          directoryEnumerationOptions: StorageKeys.directoryEnumerationOptions(
            importHiddenFiles: self.importHiddenFiles,
            importSubdirectories: self.importSubdirectories,
          ),
        )
      }
    }
    .fileDialogCustomizationID(ImagesScene.id)
    // This is not called when a menu is open.
    .onContinuousHover { phase in
      Task {
        switch phase {
          case .active:
            await self.images.hoverChannel.send(true)
          case .ended:
            await self.images.hoverChannel.send(false)
        }
      }
    }
    .task(id: self.images) {
      await self.images.load()
    }
    .task(id: self.images) {
      var task: Task<Void, Never>?

      for await isHovering in self.images.hoverChannel {
        task?.cancel()

        self.isActive = true

        guard isHovering else {
          continue
        }

        task = Task {
          do {
            try await Task.sleep(for: .imagesHoverElapse)
          } catch is CancellationError {
            return
          } catch {
            unreachable()
          }

          self.isActive = false
        }
      }

      task?.cancel()
    }
    .onChange(of: self.isBookmarked) {
      self.images.isBookmarked = self.isBookmarked
      self.images.loadBookmarks()
    }
    .onReceive(self.app.commandsPublisher) { command in
      self.onCommand(command)
    }
  }

  func onCommand(_ command: AppModelCommand) {
    guard command.sceneID == .images(self.images.id) else {
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
        guard let item = self.images.currentItem else {
          return
        }

        Task {
          await self.images.showFinder(item: item)
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
        guard let item = self.images.currentItem else {
          return
        }

        Task {
          await self.images.bookmark(item: item, isBookmarked: !item.isBookmarked)
        }
      case .toggleLiveTextIcon:
        self.isImageAnalysisSupplementaryInterfaceVisible.toggle()
      case .toggleLiveTextHighlight:
        self.images.isHighlighted.toggle()
        self.images.highlight(items: self.images.visibleItems, isHighlighted: self.images.isHighlighted)
      case .resetWindowSize:
        self.window.window?.setContentSize(ImagesScene.defaultSize)
    }
  }
}
