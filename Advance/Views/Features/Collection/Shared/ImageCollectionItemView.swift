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

struct ImageCollectionItemView<Content>: View where Content: View {
  @Binding private var phase: ImageResamplePhase
  private let content: Content

  var body: some View {
    DisplayImageView { _ in } content: {
      content
    }
  }

  init(phase: Binding<ImageResamplePhase>, @ViewBuilder content: () -> Content) {
    self._phase = phase
    self.content = content()
  }
}

struct ImageCollectionItemImageView: View {
  @State private var phase = ImageResamplePhase.empty

  var body: some View {
    ImageCollectionItemView(phase: $phase) {
      ImageCollectionItemPhaseView(phase: phase)
    }
  }
}
