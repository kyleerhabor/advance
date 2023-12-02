//
//  SettingsDestinationsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/25/23.
//

import OSLog
import SwiftUI

struct SettingsDestinationView: View {
  let url: CopyDepotDestination

  var body: some View {
    Label {
      Text(url.path)
    } icon: {
      url.icon
        .resizable()
        .scaledToFit()
    }.transaction { transaction in
      transaction.animation = nil
    }
  }
}

struct SettingsDestinationsView: View {
  @Environment(CopyDepot.self) private var depot
  @Environment(\.dismiss) private var dismiss
  @State private var showingFilePicker = false

  var body: some View {
    List {
      ForEach(depot.resolved) { url in
        Link(destination: url.url) {
          SettingsDestinationView(url: url)
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button("Remove") {
            remove(url: url.url)
          }
        }
      }

      let unresolved = depot.unresolved

      // We can't just set the opacity to 0 since the user will still see a divider.
      if !unresolved.isEmpty {
        Section("Unresolved") {
          ForEach(unresolved) { url in
            SettingsDestinationView(url: url)
              .contextMenu {
                Button("Remove") {
                  remove(url: url.url)
                }
              }
          }
        }
      }
    }.toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Close") {
          dismiss()
        }
      }

      ToolbarItem(placement: .primaryAction) {
        Button("Add...", systemImage: "plus") {
          showingFilePicker = true
        }
        .labelStyle(.titleOnly)
        .fileImporter(
          isPresented: $showingFilePicker,
          allowedContentTypes: [.folder],
          allowsMultipleSelection: true
        ) { result in
          switch result {
            case .success(let urls):
              do {
                let imported = try urls.map { url in
                  let bookmark = try url.scoped {
                    try url.bookmark(options: .withSecurityScope)
                  }

                  return (bookmark, url)
                }

                let index = Set(imported.map(\.0))

                depot.bookmarks.removeAll { index.contains($0.data) }

                let bookmarks = imported.map { item in
                  CopyDepotBookmark(data: item.0, url: item.1, resolved: true)
                }

                depot.bookmarks.append(contentsOf: bookmarks)
                depot.update()
                depot.store()
              } catch {
                Logger.ui.error("Could not import copy destinations \"\(urls)\": \(error)")
              }
            case .failure(let err):
              Logger.ui.error("Could not import copy destinations: \(err)")
          }
        }.fileDialogCopyDestination()
      }
    }.task {
      depot.bookmarks = await depot.resolve()

      withAnimation {
        depot.update()
      }
    }.environment(\.openURL, .init { url in
      // Surprisingly, scoping the URL is required for opening the actual folder in Finder (and not just selecting it
      // in its parent directory). It doesn't always work, however.
      url.scoped { openFinder(at: url) }

      return .handled
    })
  }

  func remove(url: URL) {
    withAnimation {
      depot.bookmarks.removeAll { $0.url == url }
      depot.update()
      depot.store()
    }
  }
}

#Preview {
  SettingsDestinationsView()
}
