//
//  SequenceSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/11/23.
//

import OSLog
import SwiftUI

struct SequenceSidebarView: View {
  @Environment(\.prerendering) private var prerendering

  let sequence: Seq
  @Binding var selection: Set<URL>

  var body: some View {
    VStack {
      if !prerendering && sequence.bookmarks.isEmpty {
        SequenceSidebarEmptyView(sequence: sequence)
      } else {
        SequenceSidebarContentView(sequence: sequence, selection: $selection)
      }
    }
    .animation(.default, value: prerendering || !sequence.bookmarks.isEmpty)
    .onDeleteCommand { // onDelete(perform:) doesn't seem to work.
      sequence.delete(selection)
    }
  }
}

#Preview {
  SequenceSidebarView(
    sequence: .init(bookmarks: []),
    selection: .constant([])
  ).padding()
}
