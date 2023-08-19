//
//  SequenceDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/9/23.
//

import SwiftUI

struct SequenceDetailView: View {
  @AppStorage(Keys.margin.key) private var margins = Keys.margin.value
  @AppStorage(Keys.liveText.key) private var appLiveText = Keys.liveText.value
  @AppStorage(Keys.liveTextIcons.key) private var liveTextIcons = Keys.liveTextIcons.value
  @SceneStorage(Keys.liveText.key) private var liveText = Keys.liveText.value

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
    // . . .
    //
    // I played around with adding a list item whose sole purpose was to capture the scrolling state, but couldn't get
    // it to not take up space and mess with the ForEach items.
    List {
      ForEach(images) { image in
        let url = image.url

        SequenceImageView(image: image) { image in
          image.resizable().overlay {
            if liveText {
              // FIXME: The overlayed buttons ("Live Text" and "Copy All") do not respect insets.
              //
              // There is a supplementaryInterfaceContentInsets property, but I'm not sure if it'll be the best
              // solution. The fact the buttons slide from the top and to the bottom probably wouldn't allow for more
              // margins to make it look better. A nice solution would probably involve a fade animation as it scrolls
              // into and out of view.
              LiveTextView(url: url, icons: liveTextIcons)
            }
          }
        }
        .listRowInsets(.listRow + .init(margin * 6))
        .listRowSeparator(.hidden)
        .shadow(radius: margin)
        .contextMenu {
          Button("Show in Finder") {
            openFinder(for: url)
          }
        }
      }
    }
    .listStyle(.plain)
    .toolbar {
      if appLiveText && !images.isEmpty {
        Toggle("Live Text", systemImage: "text.viewfinder", isOn: $liveText)
          .keyboardShortcut(.liveText)
      }
    }.onAppear {
      liveText = appLiveText
    }.onChange(of: appLiveText) {
      if !appLiveText {
        liveText = false
      }
    }
  }
}

#Preview {
  SequenceDetailView(images: [])
}
