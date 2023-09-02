//
//  SettingsDestinationsView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/25/23.
//

import OSLog
import SwiftUI

struct CopyDepotBookmark: Codable {
  let data: Data
  let url: URL
  let resolved: Bool

  init(data: Data, url: URL, resolved: Bool = false) {
    self.data = data
    self.url = url
    self.resolved = resolved
  }

  func resolve() throws -> Self {
    var data = data
    var resolved = try ResolvedBookmark(from: data)

    if resolved.stale {
      let url = resolved.url
      data = try url.scoped { try url.bookmark(options: .withSecurityScope) }
      resolved = try ResolvedBookmark(from: data)
    }

    return .init(data: data, url: resolved.url, resolved: true)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.init(
      data: try container.decode(Data.self, forKey: .data),
      url: try container.decode(URL.self, forKey: .url)
    )
  }

  enum CodingKeys: CodingKey {
    case data, url
  }
}

@Observable
// I tried writing a @DataStorage property wrapper to act like @AppStorage but specifically for storing Data types
// automatically (via Codable conformance), but had trouble reflecting changes across scenes. In addition, changes
// would only get communicated to the property wrapper on direct assignment (making internal mutation not simple)
class CopyDepot {
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  var bookmarks = [CopyDepotBookmark]()
  var resolved = [URL]()
  var unresolved = [URL]()

  func resolve() {
    guard let data = UserDefaults.standard.data(forKey: "copyDestinations") else {
      Logger.model.info("No data for copy destinations found in user defaults")

      return
    }

    do {
      self.bookmarks = try decoder
        .decode([CopyDepotBookmark].self, from: data)
        .map { bookmark in
          do {
            return try bookmark.resolve()
          } catch {
            guard let err = error as? CocoaError, err.code == .fileNoSuchFile else {
              Logger.model.error("Could not resolve bookmark \"\(bookmark.url)\" (\(bookmark.data)): \(error)")

              return bookmark
            }

            Logger.model.info("Bookmark \"\(bookmark.url)\" (\(bookmark.data)) could not be resolved because it's associated file does not exist. Is it temporarily unavailable?")

            return bookmark
          }
        }

      update()
    } catch {
      Logger.model.error("\(error)")
    }
  }

  func update() {
    resolved = bookmarks.filter(\.resolved).map(\.url)
    unresolved = bookmarks.filter { !$0.resolved }.map(\.url)
  }

  func store() {
    do {
      let data = try encoder.encode(bookmarks)

      UserDefaults.standard.set(data, forKey: "copyDestinations")
    } catch {
      Logger.model.error("\(error)")
    }
  }
}

struct SettingsDestinationView: View {
  let url: URL
  let action: () -> Void

  var body: some View {
    Link(destination: url) {
      Label {
        Text(url.lastPathComponent)
      } icon: {
        let image = NSWorkspace.shared.icon(forFile: url.string)

        Image(nsImage: image)
          .resizable()
          .scaledToFit()
      }
    }
    .buttonStyle(.plain)
    .contextMenu {
      Button("Remove", action: action)
    }
  }
}

struct SettingsDestinationsCollectionView: View {
  let urls: [URL]
  let action: (URL) -> Void

  var body: some View {
    ForEach(urls, id: \.self) { url in
      SettingsDestinationView(url: url) {
        action(url)
      }
    }
  }
}

struct SettingsDestinationsView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(CopyDepot.self) private var copyDepot
  @State private var file = false

  var body: some View {
    List {
      SettingsDestinationsCollectionView(urls: copyDepot.resolved, action: remove(url:))

      let unresolved = copyDepot.unresolved

      if !unresolved.isEmpty {
        Section("Unresolved") {
          SettingsDestinationsCollectionView(urls: unresolved, action: remove(url:))
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
