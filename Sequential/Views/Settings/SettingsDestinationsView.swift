//
//  SettingsDestinationsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/25/23.
//

import OSLog
import SwiftUI

struct SettingsDestinationView: View {
  let url: CopyDepotURL

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
  @Environment(\.dismiss) private var dismiss
  @Environment(CopyDepot.self) private var copyDepot
  @State private var file = false

  var body: some View {
    List {
      ForEach(copyDepot.resolved, id: \.url) { url in
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

      let unresolved = copyDepot.unresolved

      Section("Unresolved") {
        ForEach(unresolved, id: \.url) { url in
          SettingsDestinationView(url: url)
            .contextMenu {
              Button("Remove") {
                remove(url: url.url)
              }
            }
        }
      }.opacity(unresolved.isEmpty ? 0 : 1)
    }
    .frame(minWidth: 384, minHeight: 160)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("Close") {
          dismiss()
        }
      }

      ToolbarItem(placement: .primaryAction) {
        Button("Add...", systemImage: "plus") {
          file = true
        }
        .labelStyle(.titleOnly)
        .fileImporter(isPresented: $file, allowedContentTypes: [.folder]) { result in
          do {
            switch result {
              case .success(let url):
                let bookmark = try url.scoped { try url.bookmark(options: .withSecurityScope) }

                copyDepot.bookmarks.removeAll { $0.data == bookmark }
                copyDepot.bookmarks.append(.init(data: bookmark, url: url, resolved: true))
                copyDepot.update()
                copyDepot.store()
              case .failure(let err):
                throw err
            }
          } catch {
            Logger.ui.error("Failed to import copy destination: \(error)")
          }
        }
      }
    }.environment(\.openURL, .init { url in
      do {
        // Surprisingly, scoping the URL is required for opening the actual folder in Finder (and not just selecting it
        // in its parent directory). It doesn't always work, however.
        try url.scoped { openFinder(at: url) }
      } catch {
        Logger.ui.error("\(error)")
      }

      return .handled
    }).onAppear {
      copyDepot.resolve()
    }
  }

  func remove(url: URL) {
    withAnimation {
      copyDepot.bookmarks.removeAll { $0.url == url }
      copyDepot.update()
      copyDepot.store()
    }
  }
}

#Preview {
  SettingsDestinationsView()
}
