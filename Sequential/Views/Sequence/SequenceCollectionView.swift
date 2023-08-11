//
//  SequenceCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/9/23.
//

import SwiftUI

struct SequenceCollectionView: View {
  @AppStorage(StorageKeys.margin.rawValue) private var margins = 0

  @Binding var visible: [URL]
  let images: [SequenceImage]

  var body: some View {
    let margin = Double(margins)
    let page = visible.last

    // A killer limitation in using List is it doesn't support magnification, like how an NSScrollView does. Maybe try
    // reimplementing an NSCollectionView / NSTableView again?
    List(images, id: \.url) { image in
      let url = image.url

      // TODO: Implement Live Text.
      //
      // I tried this before, but it came out poorly since I was using an NSImageView.
      SequenceImageView(image: image)
        .listRowInsets(.listRow)
        .listRowSeparator(.hidden)
        .padding(margin * 6)
        .shadow(radius: margin)
        .contextMenu {
          Button("Show in Finder") {
            openFinder(for: url)
          }
        }
        // We can't just use .navigationTitle and .navigationDocument on the view since List will only update the title
        // when its succeeding view is loaded.
        .onAppear {
          visible.append(url)
        }.onDisappear {
          // An ordered set would have less complexity (Swift Collections's implementation is O(n), while this is O(n * 2)),
          // but the size of this array will likely be too small to make a notable difference (Set requiring Hashable
          // conformance likely blows away any performance gains).
          visible.remove(at: visible.firstIndex(of: url)!)
        }
    }
    .listStyle(.plain)
    .navigationTitle(page == nil ? "Sequential" : page!.deletingPathExtension().lastPathComponent)
    .navigationDocument(page ?? .blank)
  }
}

#Preview {
  SequenceCollectionView(visible: .constant([]), images: [])
}
