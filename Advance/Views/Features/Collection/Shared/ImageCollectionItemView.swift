//
//  ImageCollectionItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/21/23.
//

import SwiftUI
import OSLog

struct ImageResample {
  let image: Image
  let size: CGSize
}

extension ImageResample: Equatable {}

enum ImageResampleError {
  case failed
}

extension ImageResampleError: Error, Equatable {}

typealias ImageResamplePhase = ResultPhase<ImageResample, ImageResampleError>

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
//      .transaction(setter(value: true, on: \.disablesAnimations))
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
        let visible = imagePhase == .empty && elapsed

        ProgressView()
          .visible(visible)
          .animation(.default, value: visible)
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
        } catch {
          // Fallthrough
        }

        elapsed = true
      }.onDisappear {
        elapsed = false
      }
  }
}

struct ImageCollectionItemView<Scope, Content>: View where Scope: URLScope, Content: View {
  @State private var phase = ImageResamplePhase.empty

  let image: Scope
  @ViewBuilder var content: (ImageResamplePhase) -> Content

  var body: some View {
    DisplayImageView { size in
      await resample(size: size)
    } content: {
      content(phase)
    }
  }

  static func resample(imageAt url: URL, to size: CGSize) throws -> Image {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ImageError.undecodable
    }

    guard let thumbnail = source.resample(to: size.length.rounded(.up)) else {
      throw ImageError.thumbnail
    }

    Logger.ui.info("Created a resampled image from \"\(url.string)\" at dimensions \(thumbnail.width.description) x \(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return .init(nsImage: .init(cgImage: thumbnail, size: size))
  }

  static func resample(image: Scope, to size: CGSize) async throws -> Image {
    try image.withSecurityScope { try resample(imageAt: image.url, to: size) }
  }

  func resample(size: CGSize) async {
    do {
      let image = try await Self.resample(image: image, to: size)

      phase = .result(.success(.init(image: image, size: size)))
    } catch is CancellationError {
      return
    } catch {
      Logger.ui.error("Could not resample image at URL \"\(image.url.string)\": \(error)")

      phase = .result(.failure(.failed))
    }
  }
}

extension ImageCollectionItemView where Content == ImageCollectionItemPhaseView {
  init(image: Scope) {
    self.init(image: image) { phase in
      ImageCollectionItemPhaseView(phase: phase)
    }
  }
}
