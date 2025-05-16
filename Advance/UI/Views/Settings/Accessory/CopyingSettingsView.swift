//
//  CopyingSettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/4/24.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

let copyingContentTypes: [UTType] = [.folder]

enum CopyingTransferError: Error {
  case notOriginal
}

struct CopyingTransfer: Transferable {
  let url: URL

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .folder, shouldAttemptToOpenInPlace: true) { received in
      let url = received.file

      guard received.isOriginalFile else {
        throw CopyingTransferError.notOriginal
      }

      return Self(url: url)
    }
  }
}

struct CopyingSettingsIconView: View {
  let item: CopyingSettingsItem

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

struct CopyingSettingsView: View {
  @Environment(CopyingSettingsModel.self) private var copying
  @State private var isFileImporterPresented = false
  @State private var selection = Set<CopyingSettingsItem.ID>()

  var body: some View {
    List(selection: $selection) {
      ForEach(copying.items) { item in
        Label {
          Text(item.string)
        } icon: {
          CopyingSettingsIconView(item: item)
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .help(item.data.isResolved ? Text() : Text("Settings.Accessory.Copying.Unresolved"))
        .transaction(setter(on: \.disablesAnimations, value: true))
      }
      .onDelete { iset in
        removeItems(iset.map { copying.items[$0] })
      }
    }
    .animation(.default, value: copying.items.ids)
    .listStyle(.inset)
    .contextMenu(forSelectionType: CopyingSettingsItem.ID.self) { ids in
      Button("Settings.Accessory.Copying.Remove", role: .destructive) {
        removeItems(ids.compactMap { copying.items[id: $0] })
      }
    }
    .toolbar {
      Button("Add", systemImage: "plus") {
        isFileImporterPresented = true
      }
      .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: copyingContentTypes, allowsMultipleSelection: true) { result in
        let urls: [URL]

        switch result {
          case .success(let items):
            urls = items
          case .failure(let error):
            Logger.ui.error("\(error)")

            return
        }

        submit(urls: urls)
      }
      .fileDialogCustomizationID(NSUserInterfaceItemIdentifier.copyingOpen.rawValue)
      .fileDialogConfirmationLabel(Text("Add"))
    }
    .focusedSceneValue(\.windowOpen, AppMenuActionItem(identity: .copying, enabled: true) {
      isFileImporterPresented = true
    })
    .focusedSceneValue(\.finderShow, AppMenuActionItem(identity: .copying(selection), enabled: !selection.isEmpty) {
      let urls = copying.items
        .filter(in: selection, by: \.id)
        .map(\.data.source.url)

      NSWorkspace.shared.activateFileViewerSelecting(urls)
    })
    .focusedSceneValue(\.finderOpen, AppMenuActionItem(identity: selection, enabled: !selection.isEmpty) {
      let items = copying.items.filter(in: selection, by: \.id)

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
    .dropDestination(for: CopyingTransfer.self) { transfers, _ in
      submit(urls: transfers.map(\.url))

      return true
    }
    .onDeleteCommand {
      removeItems(copying.items.filter(in: selection, by: \.id))
    }
  }

  func submit(urls: [URL]) {
    Task {
      do {
        try await copying.submit(urls: urls)
      } catch {
        Logger.model.error("\(error)")
      }
    }
  }

  func removeItems(_ items: some Sequence<CopyingSettingsItem>) {
    Task {
      do {
        try await copying.submit(removalOf: items)
      } catch {
        Logger.model.error("\(error)")
      }
    }
  }
}
