//
//  ImagesDetailItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/11/24.
//

import AdvanceCore
import Algorithms
import OSLog
import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import VisionKit

struct ImagesDetailItemContentAnalysisView: View {
  let item: ImagesItemModel
  let phase: ImagesItemPhase
  @Binding var selectedText: String
  @Binding var isHighlighted: Bool
  let transformMenu: ImageAnalysisView.TransformMenu

  @Environment(ImagesModel.self) private var images
  @Environment(\.isImageAnalysisEnabled) private var isImageAnalysisEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  @State private var analysis: ImageAnalysis?
  private var interactionTypes: ImageAnalysisOverlayView.InteractionTypes {
    var types = ImageAnalysisOverlayView.InteractionTypes()

    guard isImageAnalysisEnabled else {
      return types
    }

    types.insert(.automaticTextOnly)

    if isLiveTextSubjectEnabled {
      types.insert(.automatic)
    }

    return types
  }

  var body: some View {
    // FIXME: ImageAnalysisView does not discover NSMenu for paged style.
    ImageAnalysisView(
      selectedText: $selectedText,
      isHighlighted: $isHighlighted,
      analysis: analysis,
      interactionTypes: interactionTypes,
      transformMenu: transformMenu
    )
    .task(id: phase.resample) {
      analysis = await analyze()
    }
  }

  func analyze() async -> ImageAnalysis? {
    guard !interactionTypes.isEmpty,
          let resample = phase.resample else {
      return nil
    }

    let analyzer = ImageAnalyzer()

    do {
      return try await Self.analyze(
        analyzer,
        in: images.analyzer.continuation,
        source: item.source,
        resample: resample
      )
    } catch {
      Logger.ui.error("Could not analyze image from source \"\(item.source)\": \(error, privacy: .public)")

      return nil
    }
  }

  nonisolated static func analyze(
    _ analyzer: ImageAnalyzer,
    in runGroup: ImagesModel.Analyzer.Continuation,
    source: some ImagesItemModelSource & Sendable,
    resample: ImagesItemResample
  ) async throws -> ImageAnalysis {
    try await run(in: runGroup) {
      let execution = try await ContinuousClock.continuous.time {
        try await analyzer.analyze(
          resample.image,
          orientation: .up,
          configuration: ImageAnalyzer.Configuration(.text)
        )
      }

      Logger.ui.info("Took \(execution.duration) to analyze image from source \"\(source)\"")

      return execution.value
    }
  }
}

struct ImagesDetailItemContentView: View {
  let item: ImagesItemModel
  @Binding var selectedText: String
  let transformMenu: ImageAnalysisView.TransformMenu

  @State private var phase = ImagesItemPhase.empty
  @State private var isHighlighted = false

  var body: some View {
    ImagesItemView(item: item, phase: $phase) {
      ImagesItemPhaseView(phase: phase)
        .aspectRatio(item.properties.aspectRatio, contentMode: .fit)
        .overlay {
          ImagesDetailItemContentAnalysisView(
            item: item,
            phase: phase,
            selectedText: $selectedText,
            isHighlighted: $isHighlighted,
            transformMenu: transformMenu
          )
        }
        .anchorPreference(key: VisiblePreferenceKey<ImagesDetailListVisibleItem>.self, value: .bounds) { anchor in
          let item = ImagesDetailListVisibleItem(item: item, isHighlighted: isHighlighted) { isOn in
            isHighlighted = isOn
          }

          return [VisibleItem(item: item, anchor: anchor)]
        }
    }
  }
}

struct ImagesDetailItemView: View {
  @State private var selectedText = ""
  let item: ImagesItemModel

  var body: some View {
    VStack {
      ImagesDetailItemContentView(
        item: item,
        selectedText: $selectedText,
        transformMenu: { menu, bind in menu }
      )
    }
    .id(item.id)
    .fileDialogConfirmationLabel(Text("Copy"))
  }
}
