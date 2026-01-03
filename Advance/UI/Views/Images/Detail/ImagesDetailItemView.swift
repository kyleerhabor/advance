//
//  ImagesDetailItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/11/24.
//

import SwiftUI
@preconcurrency import VisionKit

struct ImagesDetailItemContentAnalysisView: View {
  @Environment(ImagesModel.self) private var images
  @Binding var isHighlighted: Bool

  var body: some View {
    // FIXME: ImageAnalysisView does not discover NSMenu for paged style.
    ImageAnalysisView(
      isHighlighted: $isHighlighted,
      analysis: nil,
      interactionTypes: .automatic,
    )
  }
}

struct ImagesDetailItemContentView: View {
  @State private var phase = ImagesItemPhase.empty
  @State private var isHighlighted = false
  let item: ImagesItemModel

  var body: some View {
    ImagesItemPhaseView(phase: phase)
      .overlay {
        ImagesDetailItemContentAnalysisView(isHighlighted: $isHighlighted)
      }
      .anchorPreference(key: VisiblePreferenceKey<ImagesDetailListVisibleItem>.self, value: .bounds) { anchor in
        let item = ImagesDetailListVisibleItem(item: item, isHighlighted: isHighlighted) { isOn in
          isHighlighted = isOn
        }

        return [VisibleItem(item: item, anchor: anchor)]
      }
  }
}

struct ImagesDetailItemView: View {
  @State private var selectedText = ""
  let item: ImagesItemModel

  var body: some View {
    VStack {
      ImagesDetailItemContentView(item: item)
    }
    .id(item.id)
    .fileDialogConfirmationLabel(Text("Copy"))
  }
}
