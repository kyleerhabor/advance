//
//  ImageCollectionSidebarEmptyView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/15/23.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

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
  @Environment(\.collection) private var collection

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
    .fileImporter(isPresented: $fileDialog, allowedContentTypes: [.image, .folder], allowsMultipleSelection: true) { result in
      switch result {
        case .success(let urls):
          Task {
            do {
              let (bookmarks, items) = try await resolve(urls: urls.enumerated())

              collection.wrappedValue.bookmarks.append(contentsOf: bookmarks)
              collection.wrappedValue.items.append(contentsOf: items)
              collection.wrappedValue.updateImages()
            } catch {
              Logger.model.error("\(error)")
            }
          }
        case .failure(let err):
          Logger.ui.error("Import images from sidebar failed: \(err)")
      }
    }.onDrop(of: [.image, .folder], isTargeted: nil) { providers in
      Task {
        do {
          let urls = try await withThrowingTaskGroup(of: Offset<URL>.self) { group in
            providers.enumerated().forEach { (offset, provider) in
              group.addTask { @MainActor in
                do {
                  do {
                    return (offset, try await provider.resolve(.image))
                  } catch {
                    let url = try await provider.resolve(.folder)

                    return (offset, url)
                  }
                } catch {
                  Logger.model.error("\(error)")

                  throw error
                }
              }
            }

            var results = [Offset<URL>]()
            results.reserveCapacity(providers.count)

            return try await group.reduce(into: results) { partialResult, offset in
              partialResult.append(offset)
            }
          }

          let (bookmarks, items) = try await resolve(urls: urls)

          collection.wrappedValue.bookmarks = bookmarks
          collection.wrappedValue.items = items
          collection.wrappedValue.updateImages()
        } catch {
          Logger.model.error("\(error)")
        }
      }

      return true
    }
  }

  func resolve(urls: some Sequence<Offset<URL>>) async throws -> ([BookmarkKind], [ImageCollectionItem]) {
    let bookmarks = try await ImageCollection.resolve(urls: urls).ordered()
    let resolved = await ImageCollection.resolve(bookmarks: bookmarks.enumerated()).ordered()
    let items = resolved.flatMap { bookmark in
      switch bookmark {
        case .document(let document):
          document.images.map { image in
            ImageCollectionItem(image: image, document: document.url)
          }
        case .file(let image):
          [ImageCollectionItem(image: image, document: nil)]
      }
    }

    return (bookmarks, items)
  }
}
