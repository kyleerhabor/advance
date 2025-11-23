//
//  ImageCollectionItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/21/23.
//

import AdvanceCore
import OSLog
import SwiftUI

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
  @State private var elapsed = false

  let phase: ImageResamplePhase

  private var imagePhase: ResultPhaseItem { .init(phase) }

  var body: some View {
    Rectangle()
      .fill(.fill.quaternary)
      .visible(phase.success == nil)
      .overlay {
        let image = phase.success?.image ?? .init(nsImage: .init())

        image.resizable()
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
      .contentTransition(.opacity)
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

struct ImageCollectionItemView<Scope, Content>: View where Scope: SecurityScopedResource, Content: View {
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

  nonisolated static func resample(imageAt url: URL, to size: CGSize) throws -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ImageError.undecodable
    }

    try Task.checkCancellation()

    guard let thumbnail = source.resample(to: size.length.rounded(.up)) else {
      throw ImageError.thumbnail
    }

    Logger.ui.info("Created a resampled image from \"\(url.pathString)\" at dimensions \(thumbnail.width.description) x \(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return thumbnail
  }

  nonisolated static func resample(image: Scope, to size: CGSize) async throws -> ImageResample {
    let thumbnail = try image.accessingSecurityScopedResource {
      // I can't be asked to reimplement this.
      try resample(imageAt: .temporaryDirectory, to: size)
//      try resample(imageAt: image.url, to: size)
    }

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
//      Logger.ui.error("Could not resample image at URL \"\(image.url.pathString)\": \(error)")

      phase = .result(.failure(.failed))
    }
  }
}

struct ImageCollectionItemImageView<Scope>: View where Scope: SecurityScopedResource {
  @State private var phase = ImageResamplePhase.empty

  let image: Scope

  var body: some View {
    ImageCollectionItemView(image: image, phase: $phase) {
      ImageCollectionItemPhaseView(phase: phase)
    }
  }
}
