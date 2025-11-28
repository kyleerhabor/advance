//
//  ImagesView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/23/25.
//

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
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibilityStorage
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @State private var columnVisibility = StorageKeys.columnVisibility.defaultValue.columnVisibility
  @State private var selection = Set<ImagesItemModel2.ID>()
  @State private var isFileImporterPresented = false
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
            Button("Images.Item.Copy") {
              images.copy(items: ids)
            }
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
        }
      }
      .navigationSplitViewColumnWidth(min: 128, max: 256)
    } detail: {

    }
    .focusedSceneValue(\.commandScene, AppModelCommandScene(
      id: sceneID,
      disablesShowFinder: images.isInvalidSelection(of: selection),
      disablesOpenFinder: true,
      disablesResetWindowSize: false,
    ))
    .task(id: images) {
      guard !Task.isCancelled else {
        return
      }

      await images.load2()
    }
    .onReceive(app.commandsPublisher) { command in
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
          // If there are many items, calling this would invoke a disaster.
          unreachable()
        case .resetWindowSize:
          windowed.window?.setContentSize(ImagesScene.defaultSize)
      }
    }
    .onChange(of: columnVisibility) {
      columnVisibilityStorage = StorageColumnVisibility(columnVisibility)
    }
  }
}
