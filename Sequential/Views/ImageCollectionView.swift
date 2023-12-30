//
//  ImageCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Defaults
import Combine
import OSLog
import SwiftUI

// MARK: - Environment keys

struct ImageCollectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = UUID()
}

struct SelectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(ImageCollectionView.Selection())
}

struct VisibleEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant([ImageCollectionItemImage]())
}

extension EnvironmentValues {
  var id: ImageCollectionEnvironmentKey.Value {
    get { self[ImageCollectionEnvironmentKey.self] }
    set { self[ImageCollectionEnvironmentKey.self] = newValue }
  }

  var selection: SelectionEnvironmentKey.Value {
    get { self[SelectionEnvironmentKey.self] }
    set { self[SelectionEnvironmentKey.self] = newValue }
  }

  var visible: VisibleEnvironmentKey.Value {
    get { self[VisibleEnvironmentKey.self] }
    set { self[VisibleEnvironmentKey.self] = newValue }
  }
}

// MARK: - Focused value keys

struct Scroller<I> where I: Equatable {
  typealias Scroll = (ImageCollectionView.Selection) -> Void

  let identity: I
  let scroll: Scroll
}

extension Scroller: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.identity == rhs.identity
  }
}

enum SidebarScrollerIdentity: Equatable {
  case sidebar
}

struct SidebarScrollerFocusedValueKey: FocusedValueKey {
  typealias Value = Scroller<SidebarScrollerIdentity>
}

struct DetailScrollerIdentity: Equatable {
  let images: [ImageCollectionDetailImage]
  let selection: ImageCollectionView.Selection
}

struct DetailScrollerFocusedValueKey: FocusedValueKey {
  typealias Value = Scroller<DetailScrollerIdentity>
}

extension FocusedValues {
  var sidebarScroller: SidebarScrollerFocusedValueKey.Value? {
    get { self[SidebarScrollerFocusedValueKey.self] }
    set { self[SidebarScrollerFocusedValueKey.self] = newValue }
  }

  var detailScroller: DetailScrollerFocusedValueKey.Value? {
    get { self[DetailScrollerFocusedValueKey.self] }
    set { self[DetailScrollerFocusedValueKey.self] = newValue }
  }
}

// MARK: - Views

struct ImageCollectionNavigationSidebarView: View {
  @Environment(\.selection) @Binding private var selection
  @FocusedValue(\.detailScroller) private var detailScroller
  @FocusState private var focused: Bool

  @Binding var columns: NavigationSplitViewVisibility

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionSidebarView(scrollDetail: detailScroller?.scroll ?? noop)
        .focused($focused)
        .focusedSceneValue(\.sidebarScroller, .init(identity: .sidebar) { selection in
          let id = selection.first!

          Task {
            scroll(proxy, to: id)
          }
        })
    }
  }

  func scroll(_ proxy: ScrollViewProxy, to id: some Hashable) {
    // We're using completion blocks to synchronize actions in the UI.
    //
    // If the sidebar is not open, the scroll should happen off-screen before presenting it to the user. In addition,
    // we need the selected image to gain focus, which can only occur after the sidebar is fully open.
    //
    // There is unfortunately a slight continuation of the scroll animation that may occur during the columns animation,
    // but it's subtle and miles ahead of the prior implementation.
    withAnimation {
      proxy.scrollTo(id, anchor: .center)
    } completion: {
      withAnimation {
        columns = .all
      } completion: {
        focused = true
      }
    }
  }
}

struct ImageCollectionNavigationDetailView: View {
  @Environment(\.selection) @Binding private var selection
  @FocusedValue(\.sidebarScroller) private var sidebarScroller

  var images: [ImageCollectionDetailImage]

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionDetailView(images: images, scrollSidebar: sidebarScroller?.scroll ?? noop)
        .focusedSceneValue(\.detailScroller, .init(identity: .init(images: images, selection: selection)) { selection in
          guard let id = images.filter(
            in: selection.subtracting(self.selection),
            by: \.id
          ).last?.id else {
            return
          }

          // https://stackoverflow.com/a/72808733/14695788
          Task {
            // TODO: Figure out how to change the animation (the parameter is currently ignored)
            withAnimation {
              proxy.scrollTo(id, anchor: .top)
            }
          }
        })
    }
  }
}

struct ImageCollectionView: View {
  typealias Selection = Set<ImageCollectionItemImage.ID>

  @Environment(ImageCollection.self) private var collection
  @Environment(Window.self) private var win
  @Environment(\.fullScreen) private var fullScreen
  @Environment(\.id) private var id
  @Environment(\.trackingMenu) private var trackingMenu
  @Default(.hideToolbarScrolling) private var hideToolbar
  @Default(.hideCursorScrolling) private var hideCursor
  @Default(.hideScrollIndicator) private var hideScroll
  @SceneStorage("sidebar") private var columns = NavigationSplitViewVisibility.all
  @State private var selection = Selection()
  @State private var visible = true
  private let scrollSubject = PassthroughSubject<CGPoint, Never>()
  private let cursorSubject = PassthroughSubject<Void, Never>()
  private let toolbarSubject = PassthroughSubject<Bool, Never>()
  private let toolbarPublisher: AnyPublisher<Bool, Never>
  private var window: NSWindow? { win.window }

  var body: some View {
    NavigationSplitView(columnVisibility: $columns) {
      // TODO: Add a feature to scroll the sidebar when opened
      //
      // This requires knowing the sidebar was explicitly opened by the user (and not through implicit means like scrolling
      // to a particular image, aka "Show in Sidebar")
      ImageCollectionNavigationSidebarView(columns: $columns)
        .navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ImageCollectionNavigationDetailView(images: collection.detail)
        .scrollIndicators(hideScroll && columns == .detailOnly ? .hidden : .automatic)
        .frame(minWidth: 256)
    }.backgroundPreferenceValue(ScrollOffsetPreferenceKey.self) { anchor in
      GeometryReader { proxy in
        if let anchor {
          let origin = proxy[anchor].origin

          Color.clear.onChange(of: origin) {
            guard columns == .detailOnly else {
              return
            }

            scrollSubject.send(origin)
          }
        }
      }
    }
    .toolbar(fullScreen ? .hidden : .automatic)
    .toolbarHidden(hideToolbar && !visible)
    .cursorHidden(hideCursor && !visible)
    .environment(\.selection, $selection)
    .task(id: collection) {
      let roots = collection.items.values.map(\.root)
      let state = await Self.resolve(roots: roots, in: collection.store)
      let items = collection.order.compactMap { id -> ImageCollectionItem? in
        guard let root = collection.items[id]?.root,
              let image = state.value[id] else {
          return nil
        }

        return .init(root: root, image: image)
      }

      collection.store = state.store

      items.forEach { item in
        collection.items[item.root.bookmark] = item
      }

      let ids = items.map(\.root.bookmark)

      collection.order.append(contentsOf: ids)
      collection.update()

      Task(priority: .medium) {
        do {
          try await collection.persist(id: id)
        } catch {
          Logger.model.error("Could not persist image collection \"\(id)\" (via initialization): \(error)")
        }
      }
    }
    // Yes, the code listed below is dumb.
    .onContinuousHover { phase in
      guard let window, !window.inLiveResize else {
        return
      }

      switch phase {
        case .active: cursorSubject.send()
        case .ended: visible = true
      }
    }.onChange(of: columns) {
      toolbarSubject.send(true)
    }.onChange(of: trackingMenu) {
      toolbarSubject.send(true)
    }.onReceive(toolbarPublisher) { visible in
      self.visible = visible
    }
  }

  init() {
    let cursor = cursorSubject
      .map { _ in true }
      .prepend(false)
      // This, combined (pun) with the joining of the scroller publisher, is to prevent instances where the cursor
      // slightly moves when the user meant to scroll. Note that this currently best suits trackpads, as the duration
      // is too short to effectively counter a physical mouse (especially if it's heavy).
      .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)

    let scroller = scrollSubject
      // When the user hides the sidebar, the toolbar shouldn't be hidden (it normally produces at most 6 events).
      .collect(6)
      .filter { origins in
        origins.dropFirst().allSatisfy { $0.x == origins.first?.x }
      }.map { _ in false }

    self.toolbarPublisher = scroller
      .map { _ in cursor }
      .switchToLatest()
      .merge(with: toolbarSubject)
      .removeDuplicates()
      .eraseToAnyPublisher()
  }

  static func resolve(
    roots: [ImageCollectionItemRoot],
    in store: BookmarkStore
  ) async -> BookmarkStoreState<ImageCollection.Images> {
    let bookmarks = roots.compactMap { store.bookmarks[$0.bookmark] }

    let books = await ImageCollection.resolving(bookmarks: bookmarks, in: store)
    let roots = roots.filter { books.value.contains($0.bookmark) }

    let images = await ImageCollection.resolve(roots: roots, in: books.store)

    return .init(store: books.store, value: images)
  }
}
