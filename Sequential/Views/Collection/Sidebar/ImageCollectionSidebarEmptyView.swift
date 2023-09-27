//
//  ImageCollectionSidebarEmptyView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/15/23.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

typealias Offset<T> = (offset: Int, value: T)

struct ImageCollectionEmptySidebarLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 8) {
      configuration.icon
        .symbolRenderingMode(.hierarchical)

      configuration.title
        .font(.subheadline)
        .fontWeight(.medium)
    }
  }
}

struct ImageCollectionSidebarEmptyView: View {
  @Environment(\.collection) @Binding private var collection

  @State private var fileDialog = false

  var body: some View {
    Button {
      fileDialog = true
    } label: {
      Label {
        Text("Drop images here")
      } icon: {
        Image(systemName: "square.and.arrow.down")
          .resizable()
          .scaledToFit()
          .frame(width: 24)
      }.labelStyle(ImageCollectionEmptySidebarLabelStyle())
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .fileImporter(isPresented: $fileDialog, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
      switch result {
        case .success(let urls):
          Task {
            do {
              let bookmarks = try await resolveImported(urls: urls)
                .sorted { $0.offset < $1.offset }
                .map(\.value)

              collection.bookmarks = bookmarks
              collection.updateImages()
              collection.updateBookmarks()
            } catch {
              Logger.ui.error("\(error)")
            }
          }
        case .failure(let err):
          Logger.ui.error("Import images from sidebar failed: \(err)")
      }
    }.onDrop(of: [.image], isTargeted: nil) { providers in
      Task {
        do {
          let urls = try await withThrowingTaskGroup(of: Offset<URL>.self) { group in
            for (offset, provider) in providers.enumerated() {
              group.addTask { @MainActor in
                let url = try await loadProviderURL(provider)

                return (offset, url)
              }
            }

            var results = [Offset<URL>]()
            results.reserveCapacity(providers.count)

            return try await group.reduce(into: results) { partialResult, pair in
              partialResult.append(pair)
            }
          }

          let bookmarks = try await resolveDragged(urls: urls)
            .sorted { $0.offset < $1.offset }
            .map(\.value)

          collection.bookmarks = bookmarks
          collection.updateImages()
          collection.updateBookmarks()
        } catch {
          Logger.ui.error("Could not load URLs of dropped images from providers \"\(providers)\": \(error)")
        }
      }

      return true
    }
  }

  @MainActor
  func loadProviderURL(_ provider: NSItemProvider) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      provider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, inPlace, err in
        if let err {
          continuation.resume(throwing: err)

          return
        }

        if let url {
          // Note that when this happens, the image is copied to ~/Library/Containers/<sandbox>/Data/Library/Caches.
          // We most likely want to allow the user to clear this data (in case it becomes excessive).
          if !inPlace {
            Logger.ui.info("URL from dragged image \"\(url.string)\" is a local copy")
          }

          continuation.resume(returning: url)

          return
        }

        fatalError()
      }
    }
  }

  func resolve(_ bookmark: ImageCollectionBookmark, url: URL) async throws {
    guard let properties = await ImageProperties(at: url) else {
      throw ImageError.undecodable
    }

    bookmark.image = .init(url: url, bookmark: bookmark, properties: properties)
  }

  func resolveImported(urls: [URL]) async throws -> [Offset<ImageCollectionBookmark>] {
    try await withThrowingTaskGroup(of: Offset<ImageCollectionBookmark>.self) { group in
      for (offset, url) in urls.enumerated() {
        group.addTask {
          let bookmark = try await url.scoped {
            let data = try url.bookmark()
            let bookmark = ImageCollectionBookmark(
              data: data,
              url: url,
              scoped: true,
              bookmarked: false
            )

            try await resolve(bookmark, url: url)

            return bookmark
          }

          return (offset, bookmark)
        }
      }

      var results = [Offset<ImageCollectionBookmark>]()
      results.reserveCapacity(urls.count)

      return try await group.reduce(into: results) { partialResult, pair in
        partialResult.append(pair)
      }
    }
  }

  func resolveDragged(urls: [Offset<URL>]) async throws -> [Offset<ImageCollectionBookmark>] {
    try await withThrowingTaskGroup(of: Offset<ImageCollectionBookmark>.self) { group in
      for (offset, url) in urls {
        group.addTask {
          let data = try url.bookmark()
          let bookmark = ImageCollectionBookmark(
            data: data,
            url: url,
            scoped: false,
            bookmarked: false
          )

          try await resolve(bookmark, url: url)

          return (offset, bookmark)
        }
      }

      var results = [Offset<ImageCollectionBookmark>]()
      results.reserveCapacity(urls.count)

      return try await group.reduce(into: results) { partialResult, pair in
        partialResult.append(pair)
      }
    }
  }
}
