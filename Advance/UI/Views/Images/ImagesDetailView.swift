//
//  ImagesDetailView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import AdvanceCore
import Combine
import OSLog
import SwiftUI

struct ImagesDetailVisible {
  var items: [ImagesItemModel]
  var identity: Set<ImagesItemModel.ID>
  var isHighlighted: Bool?
  var highlights: [ImagesDetailListVisibleItem.HighlightAction]
}

struct ImagesDetailVisiblePreferenceKey: PreferenceKey {
  static var defaultValue: ImagesDetailVisible {
    ImagesDetailVisible(items: [], identity: [], highlights: [])
  }

  static func reduce(value: inout ImagesDetailVisible, nextValue: () -> ImagesDetailVisible) {
    value = nextValue()
  }
}

struct ImagesDetailView: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.isImageAnalysisEnabled) private var isImageAnalysisEnabled
  @AppStorage(StorageKeys.layoutStyle) private var layoutStyle

  var body: some View {
    Group {
      switch layoutStyle {
        case .paged: ImagesDetailPageView()
        case .continuous: ImagesDetailListView()
      }
    }
    .backgroundPreferenceValue(ImagesDetailVisiblePreferenceKey.self) { visible in
      Color.clear
        .focusedSceneValue(\.imagesLiveTextHighlight, AppMenuToggleItem(
          identity: visible.identity,
          enabled: isImageAnalysisEnabled && visible.isHighlighted != nil,
          state: visible.isHighlighted ?? false
        ) { isOn in
          visible.highlights.forEach(applying(isOn))
        })
    }
    .onChange(of: layoutStyle) {
      guard let item = images.item else {
        return
      }

      // TODO: Document async behavior.
      Task {
        images.incomingItemID.send(item.id)
      }
    }
  }
}
