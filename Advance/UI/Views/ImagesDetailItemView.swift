//
//  ImagesDetailItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/10/26.
//

import AsyncAlgorithms
import OSLog
import SwiftUI

struct ImagesDetailItemView: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.locale) private var locale
  @AppStorage(StorageKeys.collapseMargins) private var collapseMargins
  @AppStorage(StorageKeys.foldersPathDirection) private var foldersPathDirection
  @AppStorage(StorageKeys.foldersPathSeparator) private var foldersPathSeparator
  @AppStorage(StorageKeys.margins) private var margins
  @AppStorage(StorageKeys.resolveConflicts) private var resolveConflicts
  @State private var copyFolderError: ImagesModelCopyFolderError?
  @State private var isCopyFolderErrorPresented = false
  @State private var copyFolderSelection: ImagesItemModel2.ID?
  @State private var isCopyFolderFileImporterPresented = false
  @State private var searchError: ImagesModelEngineURLError?
  @State private var isSearchErrorPresented = false
  let item: ImagesItemModel2
  let isImageAnalysisSupplementaryInterfaceVisible: Bool
  // At 3, the image's trailing edge and the scroll bar perfectly align.
  private var half: CGFloat { self.margins * 3 }
  private var full: CGFloat { self.half * 2 }
  private var all: EdgeInsets { EdgeInsets(self.full) }
  private var top: EdgeInsets { EdgeInsets(horizontal: self.full, top: self.full, bottom: self.half) }
  private var between: EdgeInsets { EdgeInsets(horizontal: self.full, top: self.half, bottom: self.half) }
  private var bottom: EdgeInsets { EdgeInsets(horizontal: self.full, top: self.half, bottom: self.full) }
  private var insets: EdgeInsets {
    switch self.item.edge {
      case .all:
        self.all
      case .top:
        self.collapseMargins ? self.top : self.all
      case .bottom:
        self.collapseMargins ? self.bottom : self.all
      default:
        self.collapseMargins ? self.between : self.all
    }
  }

  var body: some View {
    // For some reason, we need to wrap this in a VStack for animations to apply.
    //
    // TODO: Figure out how to remove the border when the context menu is open.
    //
    // For some reason, we need to extract accesses to item's properties into dedicated views to prevent slow view
    // updates when switching windows.
    VStack {
      ImagesItemImageView(image: self.item.detailImage)
    }
    .shadow(radius: self.margins / 2)
    .overlay {
      ImagesDetailItemImageAnalysisView(
        searchError: $searchError,
        isSearchErrorPresented: $isSearchErrorPresented,
        item: self.item,
        isSupplementaryInterfaceVisible: self.isImageAnalysisSupplementaryInterfaceVisible,
      )
    }
    .anchorPreference(key: ImagesVisibleItemsPreferenceKey.self, value: .bounds) { anchor in
      [ImagesVisibleItem(item: self.item, anchor: anchor)]
    }
    .contextMenu {
      Section {
        Button("Finder.Item.Show", systemImage: "finder") {
          Task {
            await self.images.showFinder(item: self.item.id)
          }
        }

        Button("Sidebar.Item.Show", systemImage: "sidebar.squares.leading") {
          Task {
            await self.images.sidebar.send(ImagesModelSidebarElement(item: self.item.id, isSelected: true))
          }
        }
      }

      Section {
        Button("Images.Item.Copy", systemImage: "document.on.document") {
          Task {
            await self.images.copy(item: self.item.id)
          }
        }

        ImagesDetailItemCopyFolderView(
          selection: $copyFolderSelection,
          isFileImporterPresented: $isCopyFolderFileImporterPresented,
          error: $copyFolderError,
          isErrorPresented: $isCopyFolderErrorPresented,
          item: self.item.id,
        )
      }

      Section {
        ImagesDetailItemBookmarkView(item: self.item)
      }
    }
    .alert(isPresented: $isCopyFolderErrorPresented, error: self.copyFolderError) {}
    .alert(isPresented: $isSearchErrorPresented, error: self.searchError) { error in
      // Empty
    } message: { error in
      Text(error.recoverySuggestion ?? "")
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
          try await self.images.copyFolder(
            item: self.copyFolderSelection,
            to: url,
            locale: self.locale,
            resolveConflicts: self.resolveConflicts,
            pathSeparator: self.foldersPathSeparator,
            pathDirection: self.foldersPathDirection,
          )
        } catch let error as ImagesModelCopyFolderError {
          self.copyFolderError = error
          self.isCopyFolderErrorPresented = true
        }
      }
    }
    .fileDialogCustomizationID(FoldersSettingsScene.id)
    .listRowInsets(.listRow + self.insets)
    .listRowSeparator(.hidden)
  }
}
