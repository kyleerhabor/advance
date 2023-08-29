//
//  SettingsDestinationsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/25/23.
//

import OSLog
import SwiftUI

struct SettingsDestinationsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(Depot.self) private var depot
  @State private var file = false

  var body: some View {
    // I can't get selection working on this, for some reason.
    List(depot.urls, id: \.self) { url in
      Link(destination: url) {
        Label {
          Text(url.lastPathComponent)
        } icon: {
          Image(nsImage: NSWorkspace.shared.icon(forFile: url.string))
            .resizable()
            .scaledToFit()
        }
      }
      .buttonStyle(.plain)
      .contextMenu {
        Button("Remove") {
          withAnimation {
            depot.destinations.removeAll { $0.url == url }
            depot.store()
          }
        }
      }
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

                depot.destinations.removeAll { $0.bookmark == bookmark }
                depot.destinations.append(.init(bookmark: bookmark, url: url))
                depot.store()
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
        // in its parent directory).
        let opened = try url.scoped { openFinder(in: url) }

        if !opened {
          openFinder(selecting: url)
        }
      } catch {
        Logger.ui.error("\(error)")
      }

      return .handled
    }).onAppear {
      depot.resolve()
    }
  }
}

#Preview {
  SettingsDestinationsView()
}
