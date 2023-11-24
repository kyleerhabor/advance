//
//  ImageCollectionSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/14/23.
//

import OSLog
import SwiftUI

struct ImageCollectionSidebarItemView: View {
  let image: ImageCollectionItemImage

  var body: some View {
    VStack {
      ImageCollectionItemView(image: image)
        .overlay(alignment: .topTrailing) {
          Image(systemName: "bookmark")
            .symbolVariant(.fill)
            .symbolRenderingMode(.multicolor)
            .opacity(0.8)
            .imageScale(.large)
            .shadow(radius: 0.5)
            .padding(4)
            .visible(image.item.bookmarked)
        }

      // Interestingly, this can be slightly expensive.
      let path = image.url.lastPathComponent

      Text(path)
        .font(.subheadline)
        .padding(.init(vertical: 4, horizontal: 8))
        .background(Color.secondaryFill)
        .clipShape(.rect(cornerRadius: 4))
        // TODO: Replace this for an expansion tooltip (like how NSTableView has it)
        //
        // I tried this before, but couldn't get sizing or the trailing ellipsis to work properly.
        .help(path)
    }
    // This is not an image editor, but I don't mind some functionality that's associated with image editors. Being
    // able to drag images out of the app and drop them elsewhere just feels natural.
    .draggable(image.url) {
      ImageCollectionItemView(image: image)
    }
  }
}

struct ImageCollectionSidebarBookmarkButtonView: View {
  @Binding var bookmarks: Bool

  var body: some View {
    Toggle("\(bookmarks ? "Hide" : "Show") Bookmarks", systemImage: "bookmark", isOn: $bookmarks)
      .labelStyle(.iconOnly)
      .buttonStyle(.plain)
      .toggleStyle(.button)
      .symbolVariant(bookmarks ? .fill : .none)
      .foregroundStyle(Color(bookmarks ? .controlAccentColor : .secondaryLabelColor))
  }
}

struct ImageCollectionSidebarView: View {
  @Environment(CopyDepot.self) private var copyDepot
  @Environment(\.collection) @Binding private var collection
  @Environment(\.prerendering) private var prerendering

  let scrollDetail: Scroller.Scroll

  var body: some View {
    ImageCollectionSidebarContentView(scrollDetail: scrollDetail)
      .overlay {
        let visible = collection.items.isEmpty && !prerendering

        VStack {
          if visible {
            ImageCollectionSidebarEmptyView()
          }
        }
        .visible(visible)
        .animation(.default, value: visible)
      }
  }
}
