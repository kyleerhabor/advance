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
  @Binding var selection: Set<SeqImage.ID>
  let scroll: () -> Void

  var body: some View {
    // We don't want the "Drop Images Here" button to appear while the view is pre-rendering since it may change to
    // have data immediately after.
    let empty = !prerendering && sequence.bookmarks.isEmpty

    VStack {
      if empty {
        SequenceSidebarEmptyView(sequence: sequence)
      } else {
        SequenceSidebarContentView(sequence: sequence, selection: $selection, scroll: scroll)
      }
    }
    .animation(.default, value: empty)
    .onDeleteCommand { // onDelete(perform:) doesn't seem to work.
      sequence.delete(selection)
    }
  }
}

#Preview {
  SequenceSidebarView(
    sequence: try! .init(urls: []),
    selection: .constant([]),
    scroll: {}
  ).padding()
}
