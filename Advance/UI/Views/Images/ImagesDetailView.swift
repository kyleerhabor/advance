//
//  ImagesDetailView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import AdvanceCore
import OSLog
import SwiftUI

struct ImagesDetailVisible {
  var items: [ImagesItemModel]
  var highlights: [ImagesDetailListVisibleItem.HighlightAction]
}

struct ImagesDetailVisiblePreferenceKey: PreferenceKey {
  static var defaultValue: ImagesDetailVisible {
    ImagesDetailVisible(items: [], highlights: [])
  }

  static func reduce(value: inout ImagesDetailVisible, nextValue: () -> ImagesDetailVisible) {
    value = nextValue()
  }
}

struct ImagesDetailView: View {
  var body: some View {
    ImagesDetailListView()
  }
}
