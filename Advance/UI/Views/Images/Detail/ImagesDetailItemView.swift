//
//  ImagesDetailItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/11/24.
//

import SwiftUI

struct ImagesDetailItemContentView: View {
  @State private var phase = ImagesItemPhase.empty
  @State private var isHighlighted = false
  let item: ImagesItemModel

  var body: some View {
    ImagesItemPhaseView(phase: phase)
      .anchorPreference(key: VisiblePreferenceKey<ImagesDetailListVisibleItem>.self, value: .bounds) { anchor in
        let item = ImagesDetailListVisibleItem(item: item)

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
