//
//  ImageCollectionItemView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 12/21/23.
//

import SwiftUI
import OSLog

struct ImageResample {
  let image: Image
  let size: CGSize
}

enum ImageResamplePhase {
  case empty, success(ImageResample), failure(Error)

  var resample: ImageResample? {
    guard case let .success(resample) = self else {
      return nil
    }

    return resample
  }
}

struct ImageCollectionItemPhaseView: View {
  @AppStorage(Keys.brightness.key) private var brightness = Keys.brightness.value
  @AppStorage(Keys.grayscale.key) private var grayscale = Keys.grayscale.value
  @State private var elapsed = false
  private var imagePhase: ImagePhase {
    .init(phase) ?? .empty
  }

  let phase: ImageResamplePhase

  var body: some View {
    // For transparent images, the fill is still useful to know that an image is supposed to be in the frame, but when
    // the view's image has been cleared (see the .onDisappear), it's kind of weird to see the fill again. Maybe try
    // and determine if the image is transparent and, if so, only display the fill on its first appearance? This would
    // kind of be weird for collections that mix transparent and non-transparent images, however (since there's no
    // clear separator).
    Color.tertiaryFill
      .visible(phase.resample?.image == nil)
      .overlay {
        if let image = phase.resample?.image {
          image
            .resizable()
            .animation(.smooth) { content in
              content
                .brightness(brightness)
                .grayscale(grayscale)
            }
        }
      }.overlay {
        ProgressView()
          .visible(imagePhase == .empty && elapsed)
          .animation(.default, value: elapsed)
      }.overlay {
        if case .failure = phase {
          // We can't really get away with not displaying a failure view.
          Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.multicolor)
            .imageScale(.large)
        }
      }
      .animation(.default, value: imagePhase)
      .task {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch is CancellationError {
          // Fallthrough
        } catch {
          Logger.standard.fault("Image elapse threw an error besides CancellationError: \(error)")
        }

        elapsed = true
      }.onDisappear {
        elapsed = false
      }
  }
}

struct ImageCollectionItemView<Overlay>: View where Overlay: View {
  typealias Resolved = Pair<URLBookmark, URLBookmark?>
  typealias Resampled = Pair<Image, Resolved>

  @Environment(ImageCollection.self) private var collection
  @Environment(\.pixelLength) private var pixel
  @State private var phase = ImageResamplePhase.empty

  let image: ImageCollectionItemImage
  @ViewBuilder var overlay: (ImageResamplePhase) -> Overlay

  var body: some View {
    DisplayView { size in
      // For some reason, some images in full screen mode can cause SwiftUI to believe there are more views on screen
      // than there actually are (usually the first 21). This causes all the .onAppear and .task modifiers to fire,
      // resulting in a massive memory spike (e.g. ~1.8 GB).

      let size = CGSize(
        width: size.width / pixel,
        height: size.height / pixel
      )

      do {
        let image = try await resample(image: image, to: size)

        phase = .success(.init(image: image, size: size))
      } catch is CancellationError {
        return
      } catch {
        Logger.ui.error("Could not resample image at URL \"\(image.url.string)\": \(error)")

        phase = .failure(error)
      }
    } content: {
      ImageCollectionItemPhaseView(phase: phase)
        .overlay {
          overlay(phase)
        }
    }.aspectRatio(image.properties.sized.aspectRatio, contentMode: .fit)
  }

  func resample(imageAt url: URL, to size: CGSize) throws -> Image {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      // FIXME: For some reason, if the user scrolls fast enough in the UI, source returns nil.
      throw ImageError.undecodable
    }

    guard let thumbnail = source.resample(to: size.length.rounded(.up)) else {
      throw ImageError.thumbnail
    }

    Logger.ui.info("Created a resampled image from \"\(url.string)\" at dimensions \(thumbnail.width.description) x \(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return .init(nsImage: .init(cgImage: thumbnail, size: size))
  }

  func resample(image: ImageCollectionItemImage, to size: CGSize) async throws -> Image {
    try image.scoped { try resample(imageAt: image.url, to: size) }
  }

//  func recreating<T>(
//    bookmark: URLBookmark,
//    relativeTo relative: URL?,
//    body: (URLBookmark) throws -> T
//  ) throws -> T {
//    do {
//      return try body(bookmark)
//    } catch {
//      let mark = bookmark.bookmark
//      let hash = BookmarkStoreItem.hash(data: mark.data)
//
//      if let id = collection.store.items[hash],
//         let item = collection.store.bookmarks[id],
//         let url = collection.store.urls[item.hash],
//         bookmark.url != url {
//        let bookmarked = URLBookmark(url: url, bookmark: item.bookmark)
//
//        return try body(bookmarked)
//      }
//
//      let resolved = try BookmarkURL(
//        data: mark.data,
//        options: .init(mark.options),
//        relativeTo: relative
//      )
//
//      guard resolved.stale else {
//        throw error
//      }
//
//      let source = URLSource(url: resolved.url, options: mark.options)
//      let bookmarked = try source.scoped {
//        try URLBookmark(url: source.url, options: source.options, relativeTo: relative)
//      }
//
//      return try body(bookmarked)
//    }
//  }
//
//  func resample(image: ImageCollectionItemImage, to size: CGSize) async throws -> Resampled {
//    guard let item = collection.store.bookmarks[image.bookmark] else {
//      throw BookmarkStoreError.notFound
//    }
//
//    let bookmark = URLBookmark(url: image.url, bookmark: item.bookmark)
//    let relative = item.relative.flatMap { id -> URLBookmark? in
//      image.relative.flatMap { url -> URLBookmark? in
//        guard let item = collection.store.bookmarks[id] else {
//          return nil
//        }
//
//        return URLBookmark(url: url, bookmark: item.bookmark)
//      }
//    }
//
//    return if let relative {
//      try recreating(bookmark: relative, relativeTo: nil) { relative in
//        try relative.scoped {
//          try recreating(bookmark: bookmark, relativeTo: relative.url) { bookmark in
//            Resampled(
//              left: try bookmark.scoped {
//                try resample(imageAt: bookmark.url, to: size)
//              },
//              right: .init(left: bookmark, right: relative)
//            )
//          }
//        }
//      }
//    } else {
//      try recreating(bookmark: bookmark, relativeTo: nil) { bookmark in
//        Resampled(
//          left: try bookmark.scoped {
//            try resample(imageAt: bookmark.url, to: size)
//          },
//          right: .init(left: bookmark, right: nil)
//        )
//      }
//    }
//  }
//
//  @MainActor
//  func submit(image: ImageCollectionItemImage, resolved: Resolved) async {
//    let bookmark = resolved.left
//    let relative = resolved.right
//    let relativeId = collection.store.bookmarks[image.bookmark]?.relative
//
//    if image.url != bookmark.url {
//      image.url = bookmark.url
//    }
//
//    if image.relative != relative?.url {
//      image.relative = relative?.url
//    }
//
//    image.properties = await resolve(image: image) ?? {
//      Logger.ui.error("Could not resolve image properties for image at URL \"\(image.url.string)\"; using previous set...")
//
//      return image.properties
//    }()
//
//    image.analysis = nil
//    image.highlighted = false
//
//    let hash = BookmarkStoreItem.hash(data: bookmark.bookmark.data)
//    let item = BookmarkStoreItem(
//      id: image.bookmark,
//      bookmark: bookmark.bookmark,
//      hash: hash,
//      relative: relativeId
//    )
//
//    collection.store.register(item: item)
//    collection.store.urls[hash] = image.url
//
//    if let relative,
//       let id = relativeId {
//      let hash = BookmarkStoreItem.hash(data: relative.bookmark.data)
//      let item = BookmarkStoreItem(
//        id: id,
//        bookmark: relative.bookmark,
//        hash: hash,
//        relative: nil
//      )
//
//      collection.store.register(item: item)
//      collection.store.urls[hash] = image.relative
//    }
//  }
//
//  func resolve(image: ImageCollectionItemImage) async -> ImageProperties? {
//    image.scoped { image.resolve() }
//  }
}

extension ImageCollectionItemView where Overlay == EmptyView {
  init(image: ImageCollectionItemImage) {
    self.init(image: image) { _ in }
  }
}
