//
//  SettingsCopyingView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 12/22/23.
//

import OSLog
import SwiftUI

struct CopyDepotItemTransferable: Transferable {
  let url: URL
  let original: Bool

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(importedContentType: .folder, shouldAttemptToOpenInPlace: true) { received in
      .init(url: received.file, original: received.isOriginalFile)
    }
  }
}

extension CopyDepotItemTransferable: URLScope {
  func startSecurityScope() -> Bool {
    !original && url.startSecurityScope()
  }

  func endSecurityScope(scope: Bool) {
    if scope {
      url.endSecurityScope()
    }
  }
}

struct SettingsCopyingView: View {
  typealias Selection = Set<CopyDepotItemDestination.ID>

  @Environment(CopyDepot.self) private var depot
  @Environment(\.dismiss) private var dismiss
  @State private var selection = Selection()
  @State private var isPresentingCopyDestinationFilePicker = false
  var resolutions: [CopyDepotItemResolution] { depot.settings }

  var body: some View {
    List(selection: $selection) {
      ForEach(resolutions) { resolution in
        Label {
          Text(resolution.destination.string)
        } icon: {
          resolution.destination.icon
            .resizable()
            .symbolRenderingMode(.hierarchical)
            .scaledToFit()
            .help(resolution.resolved ? "" : "The folder at this path could not be found. This may happen when the folder has been deleted or is temporarily unavailable, such as when on a removable volume.")
        }
      }.onDelete { offsets in
        delete(selection: offsets.map { resolutions[$0].id })
        depot.update()
      }
    }
    .animation(.default, value: resolutions)
    .contextMenu(forSelectionType: CopyDepotItemDestination.ID.self) { ids in
      Section {
        Button("Finder.Open") {
          open(selection: ids)
        }
      }

      Section {
        Button("Remove", role: .destructive) {
          delete(selection: ids)
          depot.update()
        }
      }
    }.toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Close", role: .cancel) {
          dismiss()
        }
      }

      ToolbarItem(placement: .primaryAction) {
        Button("Add...") {
          isPresentingCopyDestinationFilePicker.toggle()
        }.fileImporter(
          isPresented: $isPresentingCopyDestinationFilePicker,
          allowedContentTypes: [.folder],
          allowsMultipleSelection: true
        ) { result in
          switch result {
            case .success(let urls):
              let imports = urls.compactMap { url -> URLBookmark? in
                do {
                  return try url.withSecurityScope {
                    try .init(url: url, options: [.withSecurityScope, .withoutImplicitSecurityScope], relativeTo: nil)
                  }
                } catch {
                  Logger.model.error("Could not create bookmark for imported copy destination (via file importer at URL \"\(url.string)\"): \(error)")

                  return nil
                }
              }

              insert(imports: imports)
              depot.update()
            case .failure(let err):
              Logger.ui.error("Could not import copy destinations: \(err)")
          }
        }.fileDialogCopying()
      }
    }.task {
      let state = await depot.resolve(in: depot.store)
      
      depot.store = state.store
      depot.apply(ids: state.value)
      depot.update()

      Task(priority: .medium) {
        await depot.persist()
      }
    }.dropDestination(for: CopyDepotItemTransferable.self) { items, _ in
      insert(imports: bookmark(items: items))
      depot.update()

      return true
    }.focusedValue(\.openFinder, .init(identity: selection, enabled: !selection.isEmpty) {
      open(selection: selection)
    })
    .onDeleteCommand {
      delete(selection: selection)
      depot.update()
    }
  }

  func open(selection: Selection) {
    selection
      .compactMap { depot.items[$0] }
      .filter(\.resolved)
      .forEach { item in
        let url = item.url

        url.withSecurityScope { openFinder(for: url) }
      }
  }

  func bookmark(items: some Sequence<CopyDepotItemTransferable>) -> [URLBookmark] {
    items.compactMap { item -> URLBookmark? in
      do {
        return try item.withSecurityScope {
          let options: URL.BookmarkCreationOptions = item.original
          ? .init()
          : [.withSecurityScope, .withoutImplicitSecurityScope]

          return try .init(url: item.url, options: options, relativeTo: nil)
        }
      } catch {
        Logger.model.error("Could not create bookmark for imported copy destination (via transfer at URL \"\(item.url.string)\"): \(error)")

        return nil
      }
    }
  }

  func insert(imports: some Sequence<URLBookmark>) {
    let pairs = imports.map { imp in
      let bookmark = imp.bookmark
      let hash = BookmarkStoreItem.hash(data: bookmark.data)

      return Pair(
        left: imp.url,
        right: BookmarkStoreItem(
          id: depot.store.items[hash] ?? .init(),
          bookmark: bookmark,
          hash: hash,
          relative: nil
        )
      )
    }

    pairs.forEach { pair in
      let url = pair.left
      let bookmark = pair.right

      depot.store.register(item: bookmark)
      depot.store.urls[bookmark.hash] = url
      depot.items[bookmark.id] = .init(url: url, bookmark: bookmark.id, resolved: true)
    }

    Task(priority: .medium) {
      await depot.persist()
    }
  }

  func delete(selection: some Sequence<CopyDepotItemResolution.ID>) {
    selection.forEach { id in
      depot.items[id] = nil
    }

    Task(priority: .medium) {
      await depot.persist()
    }
  }
}
