//
//  FoldersSettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import OSLog
import SwiftUI

enum FolderTransferError: Error {
  case notOriginal
}

struct FolderTransfer: Transferable {
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .folder, shouldAttemptToOpenInPlace: true) { received in
      let url = received.file

      guard received.isOriginalFile else {
        throw FolderTransferError.notOriginal
      }

      return Self(url: url)
    }
  }
}

struct FoldersSettingsIconView: View {
  let item: FoldersSettingsItem

  var body: some View {
    image.resizable()
  }

  var image: Image {
    if item.data.isResolved {
      Image(nsImage: item.icon)
    } else {
      Image(systemName: "questionmark.circle.fill")
    }
  }
}

struct FoldersSettingsView: View {
  @Environment(FoldersSettingsModel.self) private var folders
  @State private var isFileImporterPresented = false
  @State private var selection = Set<FoldersSettingsItem.ID>()

  var body: some View {
    List(selection: $selection) {
      ForEach(folders.items) { item in
        Label {
          Text(item.string)
        } icon: {
          FoldersSettingsIconView(item: item)
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .help(item.data.isResolved ? Text() : Text("Settings.Accessory.Folders.Unresolved"))
        .transaction(setter(on: \.disablesAnimations, value: true))
      }
      .onDelete { iset in
        removeItems(iset.map { folders.items[$0] })
      }
    }
//    .animation(.default, value: folders.items.ids)
    .listStyle(.inset)
    .contextMenu { ids in
      Button("Settings.Accessory.Folders.Remove", role: .destructive) {
        removeItems(ids.compactMap { folders.items[id: $0] })
      }
    }
    .toolbar {
      Button("Settings.Accessory.Folders.Add", systemImage: "plus") {
        isFileImporterPresented = false
      }
      .fileImporter(
        isPresented: $isFileImporterPresented,
        allowedContentTypes: foldersContentTypes,
        allowsMultipleSelection: true,
      ) { result in
        let urls: [URL]

        switch result {
          case .success(let items):
            urls = items
          case .failure(let error):
            // TODO: Elaborate.
            Logger.ui.error("\(error)")

            return
        }

        submit(urls: urls)
      }
      .fileDialogCustomizationID(NSUserInterfaceItemIdentifier.foldersOpen.rawValue)
      // TODO: Localize.
      .fileDialogConfirmationLabel(Text("Add"))
    }
    .focusedSceneValue(\.windowOpen, AppMenuActionItem(identity: .folders, enabled: true) {
      isFileImporterPresented = true
    })
    .focusedSceneValue(\.finderShow, AppMenuActionItem(identity: .folders(selection), enabled: !selection.isEmpty) {
      let urls = folders.items
        .filter(in: selection, by: \.id)
        .map(\.data.source.url)

      NSWorkspace.shared.activateFileViewerSelecting(urls)
    })
    .focusedSceneValue(\.finderOpen, AppMenuActionItem(identity: selection, enabled: !selection.isEmpty) {
      let items = folders.items.filter(in: selection, by: \.id)

      items.forEach { item in
        let source = item.data.source
        let path = source.url.pathString
        let success = source.accessingSecurityScopedResource {
          NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }

        if !success {
          Logger.ui.log("Could not open file at URL \"\(path)\" in Finder")
        }
      }
    })
    .dropDestination(for: FolderTransfer.self) { transfers, _ in
      submit(urls: transfers.map(\.url))

      return true
    }
    .onDeleteCommand {
      removeItems(folders.items.filter(in: selection, by: \.id))
    }
  }

  func submit(urls: [URL]) {
    Task {
      do {
        try await folders.submit(urls: urls)
      } catch {
        Logger.model.error("\(error)")
      }
    }
  }

  func removeItems(_ items: some Sequence<FoldersSettingsItem>) {
    Task {
      do {
        try await folders.submit(removalOf: items)
      } catch {
        Logger.model.error("\(error)")
      }
    }
  }
}
