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

extension ImageResample {}

enum ImageResampleError {
  case failed
}

extension ImageResampleError: Error {}

typealias ImageResamplePhase = ResultPhase<ImageResample, ImageResampleError>

struct ImageCollectionItemPhaseView: View {
  @AppStorage(Keys.brightness.key) private var brightness = Keys.brightness.value
  @AppStorage(Keys.grayscale.key) private var grayscale = Keys.grayscale.value
  @State private var elapsed = false

  let phase: ImageResamplePhase

  private var imagePhase: ResultPhaseItem { .init(phase) }
  private var isEmpty: Bool {
    switch phase {
      case .empty: return true
      default: return false
    }
  }

  var body: some View {
    Rectangle()
      .fill(.fill.quaternary)
      .visible(isEmpty)
//      .transaction(setter(value: true, on: \.disablesAnimations))
      .overlay {
        let image = phase.success?.image ?? .init(nsImage: .init())

        image
          .resizable()
          .animation(.smooth) { content in
            content
              .brightness(brightness)
              .grayscale(grayscale)
          }
      }.overlay {
        let visible = imagePhase == .empty && elapsed

        ProgressView()
          .visible(visible)
          .animation(.default, value: visible)
      }.overlay {
        // We can't really get away with not displaying a failure view.
        Image(systemName: "exclamationmark.triangle.fill")
          .symbolRenderingMode(.multicolor)
          .imageScale(.large)
          .visible(phase.failure != nil)
      }
      .animation(.default, value: imagePhase)
      .task {
        guard (try? await Task.sleep(for: .seconds(1))) == nil else {
          return
        }

        elapsed = true
      }.onDisappear {
        elapsed = false
      }
  }
}

struct ImageCollectionItemView<Scope, Content>: View where Scope: URLScope, Content: View {
  @Binding private var phase: ImageResamplePhase
  private let image: Scope
  private let content: Content

  var body: some View {
    DisplayImageView { size in
      await resample(size: size)
    } content: {
      content
    }
  }

  init(image: Scope, phase: Binding<ImageResamplePhase>, @ViewBuilder content: () -> Content) {
    self._phase = phase
    self.image = image
    self.content = content()
  }

  static func resample(imageAt url: URL, to size: CGSize) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ImageError.undecodable
    }

    try Task.checkCancellation()

    guard let thumbnail = source.resample(to: size.length.rounded(.up)) else {
      throw ImageError.thumbnail
    }

    Logger.ui.info("Created a resampled image from \"\(url.string)\" at dimensions \(thumbnail.width.description) x \(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return thumbnail
  }

  static func resample(image: Scope, to size: CGSize) async throws -> ImageResample {
    let thumbnail = try image.withSecurityScope { try resample(imageAt: image.url, to: size) }

    return .init(
      image: .init(nsImage: .init(cgImage: thumbnail, size: size)),
      size: size
    )
  }

  func resample(size: CGSize) async {
    do {
      let resample = try await Self.resample(image: image, to: size)

      phase = .result(.success(resample))
    } catch is CancellationError {
      return
    } catch {
      Logger.ui.error("Could not resample image at URL \"\(image.url.string)\": \(error)")

      phase = .result(.failure(.failed))
    }
  }
}

struct ImageCollectionItemImageView<Scope>: View where Scope: URLScope {
  @State private var phase = ImageResamplePhase.empty

  let image: Scope

  var body: some View {
    ImageCollectionItemView(image: image, phase: $phase) {
      ImageCollectionItemPhaseView(phase: phase)
    }
  }
}
