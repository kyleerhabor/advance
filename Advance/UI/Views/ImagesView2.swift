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
  @Environment(ImagesModel.self) private var images
  @Environment(\.locale) private var locale
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibilityStorage
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @State private var columnVisibility = StorageKeys.columnVisibility.defaultValue.columnVisibility
  private var directoryEnumerationOptions: FileManager.DirectoryEnumerationOptions {
    StorageKeys.directoryEnumerationOptions(
      importHiddenFiles: importHiddenFiles,
      importSubdirectories: importSubdirectories,
    )
  }

  var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      @Bindable var images = images

      List(images.items2, selection: $images.selection) { item in
        VStack {
          Text(item.title)
            .font(.subheadline)
            .padding(EdgeInsets(vertical: 4, horizontal: 8))
            .background(.fill.tertiary, in: .rect(cornerRadius: 4))
            .help(item.title)
        }
      }
      .copyable(images.urls(forItems: images.selection))
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
        .disabled(images.hasInvalidSelection(forItems: ids))
      }
      .dropDestination(for: ImagesItemTransferable.self) { items, _ in
        Task {
          await images.store(items: items, enumerationOptions: directoryEnumerationOptions)
        }

        return true
      }
      .overlay {
        ContentUnavailableView {
          Button {
            images.isFileImporterPresented = true
          } label: {
            Label("Images.Sidebar.Import", systemImage: "square.and.arrow.down")
              .labelStyle(ImagesSidebarImportLabelStyle())
          }
          .buttonStyle(.plain)
          .disabled(!images.hasLoadedNoImages)
          .opacity(images.hasLoadedNoImages ? OPACITY_OPAQUE : OPACITY_TRANSPARENT)
          .fileImporter(
            isPresented: $images.isFileImporterPresented,
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
    .task(id: images) {
      guard !Task.isCancelled else {
        return
      }

      await images.load2()
    }
    .onChange(of: columnVisibility) {
      columnVisibilityStorage = StorageColumnVisibility(columnVisibility)
    }
  }
}
