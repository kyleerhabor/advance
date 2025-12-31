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

struct ImagesBackgroundView: View {
  @Environment(ImagesModel.self) private var images
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  let isSupplementaryInterfaceVisible: Bool

  var body: some View {
    Color.clear
      .focusedSceneValue(\.commandScene, AppModelCommandScene(
        id: .images(self.images.id),
        isShowFinderDisabled: self.images.currentItem == nil,
        isOpenFinderDisabled: true,
        isShowSidebarDisabled: self.images.currentItem == nil,
        bookmark: AppModelToggleCommand(
          isDisabled: self.images.currentItem == nil,
          isOn: self.images.currentItem?.isBookmarked ?? false,
        ),
        liveTextIcon: AppModelToggleCommand(isDisabled: !self.isLiveTextEnabled, isOn: self.isSupplementaryInterfaceVisible),
        liveTextHighlight: AppModelToggleCommand(
          isDisabled: !self.isLiveTextEnabled || self.images.visibleItems.isEmpty,
          isOn: self.images.isHighlighted,
        ),
        isResetWindowSizeDisabled: false,
      ))
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

@MainActor
struct ImagesViewLiveTextID {
  let images: ImagesModel
  let isLiveTextEnabled: Bool
  let isLiveTextIconEnabled: Bool
}

extension ImagesViewLiveTextID: @MainActor Equatable {}

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
  @AppStorage(StorageKeys.isLiveTextIconEnabled) private var isLiveTextIconEnabled
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibilityStorage
  @SceneStorage(StorageKeys.liveTextSupplementaryInterfaceVisibility)
  private var liveTextSupplementaryInterfaceVisibility

  @State private var columnVisibility = NavigationSplitViewVisibility.automatic
  @State private var isColumnVisibilitySet = false
  @State private var isSupplementaryInterfaceVisible = false
  @State private var isSupplementaryInterfaceVisibleSet = false
  @State private var selection = Set<ImagesItemModel2.ID>()
  @State private var isFileImporterPresented = false
  @State private var copyFolderSelection = Set<ImagesItemModel2.ID>()
  @State private var copyFolderError: ImagesModelCopyFolderError?
  @State private var isCopyFolderErrorPresented = false
  private var directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions {
    StorageKeys.directoryEnumerationOptions(
      importHiddenFiles: self.importHiddenFiles,
      importSubdirectories: self.importSubdirectories,
    )
  }

  private var sceneID: AppModelCommandSceneID {
    .images(self.images.id)
  }

  var body: some View {
    let isVisible = !self.hiddenLayout.scroll
    || self.isTrackingMenu
    || !self.appearsActive
    || !self.isWindowFullScreen
    || self.columnVisibility != .detailOnly

    NavigationSplitView(columnVisibility: $columnVisibility) {
      ImagesSidebarView2(
        columnVisibility: $columnVisibility,
        isSupplementaryInterfaceVisible: $isSupplementaryInterfaceVisible,
        selection: $selection,
        isFileImporterPresented: $isFileImporterPresented,
        copyFolderSelection: $copyFolderSelection,
        copyFolderError: $copyFolderError,
        isCopyFolderErrorPresented: $isCopyFolderErrorPresented,
      )
      .navigationSplitViewColumnWidth(min: 128, max: 256)
    } detail: {
      ImagesDetailView2(
        copyFolderError: $copyFolderError,
        isCopyFolderErrorPresented: $isCopyFolderErrorPresented,
        columnVisibility: self.columnVisibility,
        isSupplementaryInterfaceVisible: isSupplementaryInterfaceVisible,
      )
      .frame(minWidth: 256)
      // For some reason, applying toolbar(id:content:) to the enclosing NavigationSplitView causes the app to crash.
      // This workaround is flawed since the sidebar toggle may appear in an overflow menu instead of the sidebar.
      //
      //   NSToolbar already contains an item with the identifier com.apple.SwiftUI.navigationSplitView.toggleSidebar.
      //   Duplicate items of this type are not allowed.
      .toolbar(id: "\(Bundle.appID).Images") {
        ToolbarItem(id: "\(Bundle.appID).Images.LiveTextIcon") {
          let key: LocalizedStringKey = self.isSupplementaryInterfaceVisible
            ? "Images.Toolbar.LiveTextIcon.Hide"
            : "Images.Toolbar.LiveTextIcon.Show"

          Toggle(key, systemImage: "text.viewfinder", isOn: $isSupplementaryInterfaceVisible)
            .help(key)
            .disabled(!self.isLiveTextEnabled)
        }
      }
    }
    .background {
      ImagesBackgroundView(isSupplementaryInterfaceVisible: isSupplementaryInterfaceVisible)
    }
    .toolbar(self.isWindowFullScreen ? .hidden : .automatic)
    .cursorVisible(isVisible)
    .scrollIndicators(isVisible ? .automatic : .hidden)
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
    .task(id: self.images) {
      guard !Task.isCancelled else {
        return
      }

      await images.load2()
    }
    .onChange(of: self.images) {
      self.columnVisibility = self.columnVisibilityStorage.columnVisibility
      self.isColumnVisibilitySet = true
    }
    .onChange(of: self.columnVisibility) {
      guard !self.isColumnVisibilitySet else {
        self.isColumnVisibilitySet = false

        return
      }

      guard let columnVisibility = StorageColumnVisibility(self.columnVisibility) else {
        return
      }

      self.columnVisibilityStorage = columnVisibility
    }
    .onChange(
      of: ImagesViewLiveTextID(
        images: images,
        isLiveTextEnabled: isLiveTextEnabled,
        isLiveTextIconEnabled: isLiveTextIconEnabled,
      ),
    ) { prior, id in
      isSupplementaryInterfaceVisible = switch liveTextSupplementaryInterfaceVisibility {
        case .automatic: id.isLiveTextEnabled && id.isLiveTextIconEnabled
        case .visible: id.isLiveTextEnabled
        case .hidden: false
      }

      isSupplementaryInterfaceVisibleSet = true
    }
    .onChange(of: isSupplementaryInterfaceVisible) {
      guard !isSupplementaryInterfaceVisibleSet else {
        isSupplementaryInterfaceVisibleSet = false

        return
      }

      liveTextSupplementaryInterfaceVisibility = isSupplementaryInterfaceVisible ? .visible : .hidden
    }
    .onReceive(self.app.commandsPublisher) { command in
      self.onCommand(command)
    }
  }

  func onCommand(_ command: AppModelCommand) {
    guard command.sceneID == self.sceneID else {
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
          await self.images.showFinder(item: item.id)
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
      case .bookmark:
        guard let item = self.images.currentItem else {
          return
        }

        Task {
          await self.images.bookmark(item: item.id, isBookmarked: !item.isBookmarked)
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
