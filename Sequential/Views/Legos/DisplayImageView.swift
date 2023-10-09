//
//  DisplayImageView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/19/23.
//

import Combine
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct DisplayImage: Equatable {
  let scoped: ScopeURL
  let size: CGSize
}

struct DisplayImageView<Content>: View where Content: View {
  typealias Subject = CurrentValueSubject<CGSize, Never>
  typealias PhaseContent = (Binding<AsyncImagePhase>) -> Content
  typealias Retry = () async -> Bool

  @Environment(\.pixelLength) private var pixel
  @State private var phase = AsyncImagePhase.empty
  @State private var size = CGSize()
  @State private var first = true
  private var sizeSubject: Subject
  private var sizePublisher: AnyPublisher<CGSize, Never>

  let scope: ScopeURL
  let transaction: Transaction
  let content: PhaseContent
  let retry: Retry

  var body: some View {
    GeometryReader { proxy in
      content($phase)
        .onChange(of: proxy.size, initial: true) {
          sizeSubject.send(proxy.size)
        }.task(id: DisplayImage(scoped: scope, size: size)) {
          // The reason we can't directly use size is that, on certain occasions, the UI will sometimes not load an
          // image. Using the proxy size, for some reason, always works.
          let size = proxy.size

          // This action will be called twice on initialization:
          // - Once for the default value of .zero
          // - Another for the received size of the container
          //
          // We don't need to waste our time sending Image I/O a size of zero (which will just spit out an error), so
          // we exclude it here. Note that the container shouldn't produce a size of zero afterwards since it's filtered
          // by the Combine publisher.
          guard size != .zero else {
            return
          }

          await resample(size: size)
        }
    }.onReceive(sizePublisher) { size in
      self.size = size
    }
  }

  init(
    scope: ScopeURL,
    transaction: Transaction,
    @ViewBuilder content: @escaping PhaseContent,
    retry: @escaping Retry
  ) {
    self.scope = scope
    self.transaction = transaction
    self.content = content
    self.retry = retry

    let size = Subject(.init())

    self.sizeSubject = size
    self.sizePublisher = size
      .filter { $0 != .zero }
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  @MainActor
  func resample(size: CGSize) async {
    let size = CGSize(
      width: size.width / pixel,
      height: size.height / pixel
    )

    do {
      // TODO: Support animated images
      //
      // This is also a concern for the UI, since Image does not support animations.
      let image = try await resample(to: size)

      // If an image is already present, don't perform an animation.
      //
      // Is it possible to just use .animation(_:value:)?
      if case .success = phase {
        phase = .success(image)
      } else {
        withTransaction(transaction) {
          phase = .success(image)
        }
      }
    } catch ImageError.thumbnail {
      // We don't need to update anything if it succeeds since the task is bound to the URL (which has most likely changed).
      if await !retry() {
        phase = .failure(ImageError.thumbnail)
      }
    } catch is CancellationError {
      // We don't want a CancellationError to e.g. change the visible image to a blank one, or for it to slightly
      // go blank then immediately come back.
    } catch {
      Logger.ui.error("Failed to resample image at \"\(scope.url.string)\": \(error)")

      withTransaction(transaction) {
        phase = .failure(error)
      }
    }
  }

  func resample(to size: CGSize) async throws -> Image {
    let thumbnail = try scope.scoped {
      guard let source = CGImageSourceCreateWithURL(scope.url as CFURL, nil) else {
        throw ImageError.undecodable
      }

      return try source.resample(to: size.length())
    }
    
    Logger.ui.info("Created a resampled image from \"\(scope.url.string)\" at dimensions \(thumbnail.width.description)x\(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return .init(nsImage: .init(cgImage: thumbnail, size: size))
  }
}
