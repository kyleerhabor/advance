//
//  SequenceSidebarEmptyView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/12/23.
//

import OSLog
import SwiftUI

struct SequenceSidebarEmptyView: View {
  @State private var importFiles = false

  let sequence: Seq

  var body: some View {
    Button {
      importFiles.toggle()
    } label: {
      VStack(spacing: 8) {
        Image(systemName: "square.and.arrow.down")
          .symbolRenderingMode(.hierarchical)
          .resizable()
          .scaledToFit()
          .frame(width: 24)

        Text("Drop images here")
          .font(.subheadline)
          .fontWeight(.medium)
      }
    }
    .buttonStyle(.plain)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .fileImporter(isPresented: $importFiles, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
      switch result {
        case .success(let urls):
          Task {
            sequence.store(
              bookmarks: await sequence.insert(urls, scoped: true),
              at: 0
            )
          }
        case .failure(let err): Logger.ui.error("Could not import images from sidebar: \(err)")
      }
    }.dropDestination(for: URL.self) { urls, _ in
      Task {
        sequence.store(
          bookmarks: await sequence.insert(urls, scoped: false),
          at: 0
        )
      }

      return true
    }
  }
}

#Preview {
  SequenceSidebarEmptyView(sequence: try! .init(urls: []))
}
