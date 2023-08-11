//
//  SequenceCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/9/23.
//

import SwiftUI

struct SequenceCollectionView: View {
  @AppStorage(StorageKeys.margin.rawValue) private var margins = 0
  @State private var scale: CGFloat = 1
  @State private var priorScale: CGFloat = 1

  @Binding var visible: [URL]
  let images: [SequenceImage]

  var body: some View {
    let margin = Double(margins)
    let page = visible.last

    // A killer limitation in using List is it doesn't support magnification, like how an NSScrollView does. Maybe try
    // reimplementing an NSCollectionView / NSTableView again? I tried implementing a MagnifyGesture solution but ran
    // into the following issues:
    // - The list, itself, was zoomed out, and not the cells. This made views that should've been visible not appear
    // unless explicitly scrolling down the new list size.
    // - When setting the scale factor on the cells, they would maintain their frame size, creating varying gaps
    // between each other
    // - At a certain magnification level (somewhere past `x < 0.25` and `x > 4`), the app may have crashed.
    //
    // This is not even commenting on how it's not a one-to-one equivalent to the native experience of magnifying.
    //
    // For reference, I tried implementing a simplified version of https://github.com/fuzzzlove/swiftui-image-viewer
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
