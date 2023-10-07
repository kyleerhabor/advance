//
//  ImageCollectionSidebarView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/14/23.
//

import OSLog
import QuickLook
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
  @Environment(\.prerendering) private var prerendering
  @Environment(\.collection) private var collection
  @Environment(\.selection) @Binding private var selection
  @State private var bookmarks = false
  @State private var quicklook = [URL]()
  @State private var quicklookItem: URL?
  @State private var error: String?

  let scrollDetail: () -> Void

  var body: some View {
    let selection = Binding {
      self.selection
    } set: { selection in
      self.selection = selection

      scrollDetail()
    }
    let error = Binding {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }

    List(selection: selection) {
      ForEach(bookmarks ? collection.wrappedValue.bookmarked : collection.wrappedValue.images, id: \.id) { image in
        ImageCollectionSidebarItemView(image: image)
      }
      // FIXME: items order should be independent of bookmarks order.
      //
      // Since bookmarks can either be a file or document containing files, ordering it would be tricky. It probably
      // wouldn't be worth it and instead to base all user-facing choices on it (so, including order). The issue,
      // however, is resolution is currently based on the bookmark order.
//      .onMove { source, destination in
//        collection.wrappedValue.items.move(fromOffsets: source, toOffset: destination)
//        collection.wrappedValue.updateImages()
//      }
    }.safeAreaInset(edge: .bottom, spacing: 0) {
      // I would *really* like this at the top, but I can't justify it since this is more a filter and not a new tab.
      VStack(alignment: .trailing, spacing: 0) {
        Divider()

        ImageCollectionSidebarBookmarkButtonView(bookmarks: $bookmarks)
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

      if !copyDepot.resolved.isEmpty {
        ImageCollectionCopyDestinationView(error: $error) { urls(from: ids) }
      }
      
      Divider()

      let mark: Bool = bookmark(selection: ids)

      Button {
        bookmark(mark, selection: ids)
      } label: {
        Label(mark ? "Bookmark" : "Remove Bookmark", systemImage: "bookmark")
      }
    }.overlay {
      let visible = collection.wrappedValue.items.isEmpty && !prerendering

      VStack {
        if visible {
          ImageCollectionSidebarEmptyView()
        }
      }
      .visible(visible)
      .animation(.default, value: visible)
    }
    .alert(self.error ?? "", isPresented: error) {}
    .task {
      copyDepot.bookmarks = await copyDepot.resolve()
      copyDepot.update()
    }.onKey(" ") {
      quicklook(urls: urls(from: self.selection))
    }.focusedValue(\.sidebarFinder,
      .init(enabled: !self.selection.isEmpty) {
        openFinder(selecting: urls(from: self.selection))
      }
    ).focusedValue(\.sidebarQuicklook, .init(enabled: !self.selection.isEmpty || quicklookItem != nil) {
      guard quicklookItem == nil else {
        quicklookItem = nil

        return
      }

      quicklook(urls: urls(from: self.selection))
    }).focusedValue(\.sidebarBookmark, .init(enabled: !self.selection.isEmpty) {
      bookmark(selection: self.selection)
    }).focusedValue(\.sidebarBookmarkState, bookmark(selection: self.selection) ? .add : .remove)
  }

  func urls(from selection: ImageCollectionView.Selection) -> [URL] {
    collection.wrappedValue.images.filter(in: selection, by: \.id).map(\.url)
  }

  func quicklook(urls: [URL]) {
    // There seems to be a bug where Quick Look lags the whole app when it's open (it's specifically noticeable when
    // flipping through the app menu or context menus).
    quicklook = urls
    quicklookItem = urls.first
  }

  func bookmark(selection: ImageCollectionView.Selection) -> Bool {
    guard selection.isEmpty else {
      return !selection.isSubset(of: collection.wrappedValue.bookmarkedIndex)
    }

    return true
  }

  func bookmark(selection: ImageCollectionView.Selection) {
    bookmark(bookmark(selection: selection), selection: selection)
  }

  func bookmark(_ value: Bool, selection: ImageCollectionView.Selection) {
    collection.wrappedValue.images.filter(in: selection, by: \.id).forEach { image in
      image.item.bookmarked = value
    }

    collection.wrappedValue.updateBookmarks()
  }
}
