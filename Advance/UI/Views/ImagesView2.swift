//
//  ImagesView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/23/25.
//

import AdvanceCore
import OSLog
import SwiftUI

struct ImagesImportLabelStyle: LabelStyle {
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

struct ImagesView2: View {
  @Environment(AppModel.self) private var app
  @Environment(Windowed.self) private var windowed
  @Environment(ImagesModel.self) private var images
  @Environment(FoldersSettingsModel.self) private var folders
  @Environment(\.locale) private var locale
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibilityStorage
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @State private var columnVisibility = StorageKeys.columnVisibility.defaultValue.columnVisibility
  @State private var selection = Set<ImagesItemModel2.ID>()
  @State private var isFileImporterPresented = false
  @State private var copyFolderSelection = Set<ImagesItemModel2.ID>()
  @State private var isCopyFolderFileImporterPresented = false
  @State private var copyFolderError: FoldersSettingsModelCopyError?
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
    NavigationSplitView(columnVisibility: $columnVisibility) {
      List(images.items2, selection: $selection) { item in
        VStack {
          Text(item.title)
            .font(.subheadline)
            .padding(EdgeInsets(vertical: 4, horizontal: 8))
            .background(.fill.tertiary, in: .rect(cornerRadius: 4))
            .help(item.title)
        }
      }
      .copyable(images.urls(forItems: selection))
      .contextMenu { ids in
        Group {
          Section {
            Button("Finder.Item.Show", systemImage: "finder") {
              images.showFinder(items: ids)
            }
          }

          Section {
            Button("Images.Item.Copy", systemImage: "document.on.document") {
              images.copy(items: ids)
            }

            ImagesSidebarItemCopyFolderView(
              selection: $copyFolderSelection,
              isFileImporterPresented: $isCopyFolderFileImporterPresented,
              error: $copyFolderError,
              isErrorPresented: $isCopyFolderErrorPresented,
              items: ids,
            )
          }
        }
        .disabled(images.isInvalidSelection(of: ids))
      }
      .dropDestination(for: ImagesItemTransfer.self) { items, _ in
        Task {
          await images.store(items: items, enumerationOptions: directoryEnumerationOptions)
        }

        return true
      }
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
          .opacity(images.hasLoadedNoImages ? OPACITY_OPAQUE : OPACITY_TRANSPARENT)
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
        }
      }
      .navigationSplitViewColumnWidth(min: 128, max: 256)
    } detail: {

    }
    .alert(isPresented: $isCopyFolderErrorPresented, error: copyFolderError) {}
    .focusedSceneValue(\.commandScene, AppModelCommandScene(
      id: sceneID,
      disablesShowFinder: images.isInvalidSelection(of: selection),
      disablesOpenFinder: true,
      disablesResetWindowSize: false,
    ))
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
          try await folders.copy(
            to: URLSource(url: url, options: [.withSecurityScope]),
            items: copyFolderSelection,
            locale: locale,
            resolveConflicts: resolveConflicts,
            pathSeparator: foldersPathSeparator,
            pathDirection: foldersPathDirection,
          )
        } catch let error as FoldersSettingsModelCopyError {
          self.copyFolderError = error
          self.isCopyFolderErrorPresented = true
        }
      }
    }
    .fileDialogCustomizationID(FoldersSettingsScene.id)
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
        images.showFinder(items: selection)
      case .openFinder:
        // If there are many items, supporting this would be a disaster.
        unreachable()
      case .resetWindowSize:
        windowed.window?.setContentSize(ImagesScene.defaultSize)
    }
  }
}
