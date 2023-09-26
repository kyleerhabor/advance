//
//  ImageCollectionSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/14/23.
//

import OSLog
import SwiftUI

struct ImageCollectionSidebarView: View {
  @Environment(\.prerendering) private var prerendering
  @Environment(\.collection) @Binding private var collection
  @Environment(\.selection) @Binding private var selection
  @State private var bookmarks = false
  @State private var quicklook = [URL]()
  @State private var quicklookItem: URL?

  let scrollDetail: () -> Void

  var body: some View {
    let selection = Binding {
      self.selection
    } set: { selection in
      self.selection = selection

      scrollDetail()
    }

    List(selection: selection) {
      ForEach(bookmarks ? collection.bookmarked : collection.images, id: \.id) { image in
        VStack {
          ImageCollectionItemView(image: image)
            .overlay(alignment: .topTrailing) {
              Image(systemName: "bookmark")
                .symbolVariant(.fill)
                .foregroundStyle(.red.opacity(0.8))
                .imageScale(.large)
                .shadow(radius: 0.5)
                .padding(4)
                .visible(image.bookmark.bookmarked)
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
      }.onMove { source, destination in
        collection.bookmarks.move(fromOffsets: source, toOffset: destination)
        collection.images.move(fromOffsets: source, toOffset: destination)
      }
    }.safeAreaInset(edge: .bottom, spacing: 0) {
      VStack(alignment: .trailing, spacing: 0) {
        Divider()
        
        Toggle("Show Bookmarks", systemImage: "bookmark", isOn: $bookmarks)
          .labelStyle(.iconOnly)
          .buttonStyle(.plain)
          .toggleStyle(.button)
          .symbolVariant(bookmarks ? .fill : .none)
          .foregroundStyle(Color(bookmarks ? .controlAccentColor : .secondaryLabelColor))
          .padding(8)
      }
    }
    .copyable(urls(from: self.selection))
    .quickLookPreview($quicklookItem, in: quicklook)
    .contextMenu { ids in
      Button("Show in Finder") {
        openFinder(selecting: urls(from: ids))
      }

      // I tried replacing this for a Toggle, but the shift in items for the toggle icon didn't make it look right,
      // defeating the purpose.
      Button("Quick Look", systemImage: "eye") {
        guard quicklookItem == nil else {
          quicklookItem = nil

          return
        }

        quicklook(urls: urls(from: ids))
      }

      Divider()

      // Should we state how many images will be copied?
      Button("Copy", systemImage: "doc.on.doc") {
        let urls = urls(from: ids)

        if !NSPasteboard.general.write(items: urls as [NSURL]) {
          Logger.ui.error("Failed to write URLs \"\(urls.map(\.string))\" to pasteboard")
        }
      }

      // TODO: Implement "Copy to Folder"

      Divider()

      // TODO: Apply bookmarks based on state.
      //
      // If A and B aren't bookmarked, bookmark. If A is bookmarked and B isn't, bookmark. If A and B are bookmarked, remove bookmark.
      Button {
        let images = collection.images.filter(in: ids, by: \.id)
        let bookmark = images.allSatisfy { !$0.bookmark.bookmarked }

        images.forEach { image in
          image.bookmark.bookmarked = bookmark
        }

//        withAnimation {
          collection.bookmarked = collection.images.filter { $0.bookmark.bookmarked }
//        }
      } label: {
        Label("Bookmark", systemImage: "bookmark")
      }

      Button("Get Info", systemImage: "info.circle") {
        // TODO: Implement.
      }
    }.overlay {
      let visible = collection.bookmarks.isEmpty && !prerendering

      VStack {
        if visible {
          ImageCollectionSidebarEmptyView()
        }
      }.animation(.default, value: visible)
    }.onKeyPress(.space, phases: .down) { event in
      quicklook(urls: urls(from: self.selection))

      return .handled
    }.focusedSceneValue(\.sidebarFinder,
      .init(enabled: !self.selection.isEmpty) {
        openFinder(selecting: urls(from: self.selection))
      }
    ).focusedSceneValue(\.sidebarQuicklook,
      .init(enabled: !self.selection.isEmpty || quicklookItem != nil) {
        guard quicklookItem == nil else {
          quicklookItem = nil

          return
        }

        quicklook(urls: urls(from: self.selection))
      }
    )
  }

  func urls(from selection: ImageCollectionView.Selection) -> [URL] {
    collection.images.filter(in: selection, by: \.id).map(\.url)
  }

  func quicklook(urls: [URL]) {
    // There seems to be a bug where Quick Look lags the whole app when it's open (it's specifically noticeable when
    // flipping through the app menu or context menus).
    quicklook = urls
    quicklookItem = urls.first
  }
}
