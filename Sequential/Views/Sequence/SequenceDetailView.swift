//
//  SequenceDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/9/23.
//

import SwiftUI

struct SequenceDetailView: View {
  @AppStorage(Keys.margin.key) private var margins = Keys.margin.value

  let images: [SeqImage]

  var body: some View {
    let margin = Double(margins)

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
    //
    // TODO: Figure out how to remove that annoying ring when right clicking on an image.
    //
    // I played around with adding a list item whose sole purpose was to capture the scrolling state, but couldn't get
    // it to not take up space and mess with the ForEach items.
    List {
      ForEach(images, id: \.url) { image in
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
      }
    }
    .listStyle(.plain)
  }
}

#Preview {
  SequenceDetailView(images: [])
}
