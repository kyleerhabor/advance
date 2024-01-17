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

typealias ImageResamplePhase = ResultPhase<ImageResample, Error>

struct ImageCollectionItemPhaseView: View {
  @AppStorage(Keys.brightness.key) private var brightness = Keys.brightness.value
  @AppStorage(Keys.grayscale.key) private var grayscale = Keys.grayscale.value
  @State private var elapsed = false
  private var imagePhase: ResultPhaseItem { .init(phase) }

  let phase: ImageResamplePhase

  var body: some View {
    Rectangle()
      .fill(.fill.quaternary)
      .visible(phase.success?.image == nil)
      .transaction(setter(value: true, on: \.disablesAnimations))
      .overlay {
        if let image = phase.success?.image {
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
        if phase.failure != nil {
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
  @Environment(\.pixelLength) private var pixel
  @State private var phase = ImageResamplePhase.empty

  let image: ImageCollectionItemImage
  @ViewBuilder let overlay: (ImageResamplePhase) -> Overlay

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

        phase = .result(.success(.init(image: image, size: size)))
      } catch is CancellationError {
        return
      } catch {
        Logger.ui.error("Could not resample image at URL \"\(image.url.string)\": \(error)")

        phase = .result(.failure(error))
      }
    } content: {
      ImageCollectionItemPhaseView(phase: phase)
        // Do we still need this overlay?
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
}

extension ImageCollectionItemView where Overlay == EmptyView {
  init(image: ImageCollectionItemImage) {
    self.init(image: image) { _ in }
  }
}
