//
//  ImagesItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/4/24.
//

import AdvanceCore
import Combine
import CoreGraphics
import OSLog
import SwiftUI

struct ImagesItemResample {
  let id: UUID
  let image: CGImage
  let nsImage: NSImage
}

extension ImagesItemResample: @unchecked Sendable {}

extension ImagesItemResample: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}

enum ImagesItemPhase {
  case empty, success(ImagesItemResample), failure

  var resample: ImagesItemResample? {
    guard case let .success(resample) = self else {
      return nil
    }

    return resample
  }
}

extension ImagesItemPhase: Equatable {}

// This should eventually be useful for animated images (GIF, HEIC, JPEG XL, etc.)
struct ImageView: NSViewRepresentable {
  let image: CGImage?

  func makeNSView(context: Context) -> NSView {
    let view = NSView()
    let layer = CALayer()
    layer.contents = image
    // TODO: Document.
    layer.drawsAsynchronously = true

    view.layer = layer
    view.wantsLayer = true

    return view
  }

  func updateNSView(_ view: NSView, context: Context) {
    view.layer?.contents = image
  }
}

struct ImagesItemPhaseView: View {
  @State private var elapsed = false

  let phase: ImagesItemPhase

  var body: some View {
    let resample = phase.resample
    var isEmpty: Bool {
      switch phase {
        case .empty: true
        default: false
      }
    }
    var isFailure: Bool {
      switch phase {
        case .failure: true
        default: false
      }
    }

    Rectangle()
      .fill(.fill.quaternary)
      .visible(isEmpty)
      .overlay {
        let image = resample?.nsImage ?? NSImage()

        Image(nsImage: image)
          .resizable()
      }
      .overlay {
        let isVisible = isEmpty && elapsed

        ProgressView()
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .overlay {
        let isVisible = isFailure

        Image(systemName: "exclamationmark.triangle.fill")
          .symbolRenderingMode(.multicolor)
          .imageScale(.large)
          .visible(isVisible)
          .animation(.default, value: isVisible)
      }
      .task(id: phase) {
        elapsed = false

        do {
          try await Task.sleep(for: .seconds(1))
        } catch {
          return
        }

        elapsed = true
      }
  }
}

struct ImagesItemContentView: View {
  let item: ImagesItemModel

  @State private var phase = ImagesItemPhase.empty

  var body: some View {
    ImagesItemView(item: item, phase: $phase) {
      ImagesItemPhaseView(phase: phase)
        .aspectRatio(item.properties.aspectRatio, contentMode: .fit)
    }
  }
}

struct ImagesItemView<Content>: View where Content: View {
  private let item: ImagesItemModel
  @Binding private var phase: ImagesItemPhase
  private let content: Content

  @Environment(ImagesModel.self) private var images
  @Environment(\.pixelLength) private var pixelLength
  private let subject = PassthroughSubject<CGSize, Never>()
  private let publisher: AnyPublisher<CGSize, Never>

  var body: some View {
    content
      // We could use onGeometryChange(for:of:action:), but action executes immediately for each transform difference.
      // The immediate execution is troublesome for asynchronous pipelines like Combine, where writing "debounce size
      // updates for 200ms" is required. In addition, the geometry is tracked regardless of the view's appearance on
      // screen. This means transform must be filtered to prevent bursts of resampling from changes to e.g. the
      // navigation separator. This may be a behavior we want, however, as it could allow us to write code like "run
      // this block whenever the view is close to being on-screen".
      //
      // To circumvent such limitations, we could make the modifier never emit a differing value and solely rely on
      // submitting the input to the subject.
      .background {
        SizeView(subject: subject, publisher: publisher) { size in
          let length = Int((size.length / pixelLength).rounded(.up))
          let image = await Self.resampleImage(in: images.resampler.continuation, source: item.source, length: length)
          let phase: ImagesItemPhase = image
            .map { .success($0) }
            ?? .failure

          if case .success = self.phase {
            self.phase = phase
          } else {
            withAnimation {
              self.phase = phase
            }
          }
        }
      }
  }

  init(
    item: ImagesItemModel,
    phase: Binding<ImagesItemPhase>,
    @ViewBuilder content: () -> Content
  ) {
    self.item = item
    self._phase = phase
    self.content = content()
    self.publisher = subject
      .debounce(for: .imagesResizeInteraction, scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  nonisolated static func resampleImage(
    in runGroup: ImagesModel.Resampler.Continuation,
    source: some ImagesItemModelSource & Sendable,
    length: Int
  ) async -> ImagesItemResample? {
    let image = await run(in: runGroup) {
      await source.resampleImage(length: length)
    }

    guard let image else {
      return nil
    }

    return ImagesItemResample(
      id: UUID(),
      image: image,
      nsImage: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    )
  }
}
