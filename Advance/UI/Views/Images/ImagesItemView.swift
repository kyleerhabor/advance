//
//  ImagesItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/4/24.
//

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
  @State private var phase = ImagesItemPhase.empty

  var body: some View {
    ImagesItemPhaseView(phase: phase)
  }
}
