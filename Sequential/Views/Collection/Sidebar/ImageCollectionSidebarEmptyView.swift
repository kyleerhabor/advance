//
//  ImageCollectionSidebarEmptyView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/15/23.
//

import OSLog
import SwiftUI

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
  @AppStorage(Keys.importHidden.key) private var importHidden = Keys.importHidden.value
  @AppStorage(Keys.importSubdirectories.key) private var importSubdirectories = Keys.importSubdirectories.value
  @State private var isFilePickerPresented = false

  var body: some View {
    Button {
      isFilePickerPresented.toggle()
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
    .fileImporter(isPresented: $isFilePickerPresented, allowedContentTypes: [.image, .folder], allowsMultipleSelection: true) { result in
      switch result {
        case .success(let urls):
          Task {
            do {
              let resolved = try await resolve(urls: urls.enumerated())

              collection.wrappedValue.bookmarks.append(contentsOf: resolved.map(\.0))
              collection.wrappedValue.items.append(contentsOf: resolved.flatMap(\.1))
              collection.wrappedValue.updateImages()
            } catch {
              Logger.model.error("\(error)")
            }
          }
        case .failure(let err):
          Logger.ui.error("Import images from sidebar failed: \(err)")
      }
    }
    .fileDialogOpen()
    .onDrop(of: [.image, .folder], isTargeted: nil) { providers in
      NSApp.abortModal()

      Task {
        do {
          let urls = try await withThrowingTaskGroup(of: Offset<URL>.self) { group in
            providers.enumerated().forEach { (offset, provider) in
              group.addTask { @MainActor in
                // There's an interesting bug where some providers aren't loaded even when their UTType is correct.
                do {
                  return (offset, try await provider.resolve(.image))
                } catch {
                  return (offset, try await provider.resolve(.folder))
                }
              }
            }

            var results = [Offset<URL>]()
            results.reserveCapacity(providers.count)

            return try await group.reduce(into: results) { partialResult, offset in
              partialResult.append(offset)
            }
          }

          let resolved = try await resolve(urls: urls)

          collection.wrappedValue.bookmarks = resolved.map(\.0)
          collection.wrappedValue.items = resolved.flatMap(\.1)
          collection.wrappedValue.updateImages()
        } catch {
          Logger.model.error("\(error)")
        }
      }

      return true
    }.focusedSceneValue(\.openFileImporter, .init(identity: .window) {
      isFilePickerPresented.toggle()
    })
  }

  func resolve(urls: some Sequence<Offset<URL>>) async throws -> [(BookmarkKind, [ImageCollectionItem])] {
    let bookmarks = try await ImageCollection.resolve(urls: urls, hidden: importHidden, subdirectories: importSubdirectories).ordered()
    let resolved = await ImageCollection.resolve(bookmarks: bookmarks.enumerated()).ordered()

    // TODO: De-duplicate (see ImageCollectionView).
    return resolved.map { bookmark in
      switch bookmark {
        case .document(let document):
          let doc = BookmarkDocument(data: document.data, url: document.url)
          let items = document.images.map { image in
            ImageCollectionItem(image: image, document: doc)
          }

          doc.files = items.map(\.bookmark)

          return (BookmarkKind.document(doc), items)
        case .file(let image):
          let item = ImageCollectionItem(image: image, document: nil)

          return (BookmarkKind.file(item.bookmark), [item])
      }
    }
  }
}
