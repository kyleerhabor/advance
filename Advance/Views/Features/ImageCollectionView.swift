//
//  ImageCollectionView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Combine
import Defaults
import OSLog
import SwiftUI

// MARK: - Environment keys

struct ImageCollectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = UUID()
}

extension EnvironmentValues {
  var id: ImageCollectionEnvironmentKey.Value {
    get { self[ImageCollectionEnvironmentKey.self] }
    set { self[ImageCollectionEnvironmentKey.self] = newValue }
  }
}

// MARK: - Views

struct ImageCollectionNavigationRestoreView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.loaded) private var loaded

  let action: (ImageCollectionItemImage.ID) -> Void

  var body: some View {
    // FIXME: Use onChange(of:initial:_:) instead of task(id:priority:_:)
    //
    // For some reason, using onChange causes the detail view to be behind by two images. task resolves this, but
    // introduces a delay visible to the user.
    Color.clear.task(id: loaded) {
      guard loaded,
            let id = collection.currentSuper else {
        return
      }

      action(id)
    }
  }
}

struct ImageCollectionNavigationSidebarView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.id) private var id
  @Environment(\.loaded) private var loaded
  @Environment(\.navigationColumns) @Binding private var columns
  @Default(.windowRestoreLastImage) private var windowRestoreLastImage
  @FocusState private var focused: Bool

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionSidebarView()
        .focused($focused)
        .background {
          ImageCollectionNavigationRestoreView { id in
            guard windowRestoreLastImage else {
              return
            }

            Self.scroll(proxy: proxy, id: id)
          }
        }
        .focusedSceneValue(\.sidebarScroller, .init(identity: .sidebar) { item in
          Task {
            // We're using completion blocks to synchronize actions in the UI.
            //
            // If the sidebar is not open, the scroll should happen off-screen before presenting it to the user. In addition,
            // we need the selected image to gain focus, which can only occur after the sidebar is fully open.
            //
            // There is unfortunately a slight continuation of the scroll animation that may occur during the columns animation,
            // but it's subtle and miles ahead of the previous implementation.
            await animate {
              proxy.scrollTo(item.id, anchor: .center)
            }

            await showSidebar()

            // With our current calls, this just sets the sidebar selection. We want to make sure the sidebar has
            // focus beforehand so the selection is not given a muted background.
            item.completion()
          }
        })
        .focusedSceneValue(\.navigator, .init(identity: id, enabled: loaded) { navigator in
          collection.sidebarPage = navigator.page

          Task {
            // For some reason, we need to animate this for the sidebar to always animate when opening.
            await animate {
              collection.updateBookmarks()
            }

            await showSidebar()
          }
        })
    }
  }

  static func scroll(proxy: ScrollViewProxy, id: some Hashable) {
    proxy.scrollTo(id, anchor: .center)
  }

  func animate(body: () -> Void) async {
    await withCheckedContinuation { continuation in
      withAnimation {
        body()
      } completion: {
        continuation.resume()
      }
    }
  }

  func showSidebar() async {
    await animate {
      columns = .all
    }

    focused = true
  }
}

struct ImageCollectionNavigationDetailView: View {
  @Environment(ImageCollection.self) private var collection
  @Default(.windowRestoreLastImage) private var windowRestoreLastImage

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionDetailView(items: collection.detail)
        .background {
          ImageCollectionNavigationRestoreView { id in
            guard windowRestoreLastImage else {
              return
            }

            Self.scroll(proxy: proxy, id: id)
          }
        }
        .focusedSceneValue(\.detailScroller, .init(identity: .detail) { id in
          Self.scroll(proxy: proxy, to: id)
        })
    }
  }

  @MainActor
  static func scroll(proxy: ScrollViewProxy, to id: some Hashable) {
    // https://stackoverflow.com/a/72808733/14695788
    Task {
      // TODO: Figure out how to change the animation (the parameter is currently ignored)
      withAnimation {
        proxy.scrollTo(id, anchor: .top)
      }
    }
  }

  static func scroll(proxy: ScrollViewProxy, id: some Hashable) {
    proxy.scrollTo(id, anchor: .top)
  }
}

struct ImageCollectionView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(Windowed.self) private var windowed
  @Environment(\.prerendering) private var prerendering
  @Environment(\.trackingMenu) private var trackingMenu
  @Environment(\.fullScreen) private var fullScreen
  @Environment(\.id) private var id
  @Default(.hideToolbarScrolling) private var hideToolbar
  @Default(.hideCursorScrolling) private var hideCursor
  @Default(.hideScrollIndicator) private var hideScroll
  @SceneStorage("sidebar") private var columns = NavigationSplitViewVisibility.all
  @FocusedValue(\.sidebarScroller) private var sidebarScroller
  @FocusedValue(\.detailScroller) private var detailScroller
  @State private var isHovering = false
  @State private var isScrolling = false
  private var isVisible: Bool { !(isHovering && isScrolling) }
  private var window: NSWindow? { windowed.window }
  private var isDetailOnly: Bool { columns == .detailOnly }

  private let cursorSubject = PassthroughSubject<Void, Never>()
  private let scrollSubject = PassthroughSubject<CGPoint, Never>()
  private let scrollingSubject = PassthroughSubject<Bool, Never>()
  private let scrollingPublisher: AnyPublisher<Bool, Never>

  var body: some View {
    NavigationSplitView(columnVisibility: $columns) {
      // TODO: Add a feature to scroll the sidebar when opened
      //
      // This requires knowing the sidebar was explicitly opened by the user (and not through implicit means like scrolling
      // to a particular image, aka "Show in Sidebar")
      ImageCollectionNavigationSidebarView()
        .navigationSplitViewColumnWidth(min: 128, ideal: 128, max: 256)
        .environment(\.detailScroller, detailScroller ?? .init(identity: .unknown, scroll: noop))
    } detail: {
      ImageCollectionNavigationDetailView()
        .scrollIndicators(hideScroll && isDetailOnly ? .hidden : .automatic)
        .frame(minWidth: 256)
        .environment(\.sidebarScroller, sidebarScroller ?? .init(identity: .unknown, scroll: noop))
        .onContinuousHover { phase in
          guard let window,
                !window.inLiveResize  else {
            return
          }

          switch phase {
            case .active:
              isHovering = true

              cursorSubject.send()
            case .ended:
              isHovering = false

              scrollingSubject.send(false)
          }
        }
    }.backgroundPreferenceValue(ScrollOffsetPreferenceKey.self) { anchor in
      GeometryReader { proxy in
        let origin = anchor.map { proxy[$0].origin }

        Color.clear.onChange(of: origin) {
          guard let origin,
                isDetailOnly && !trackingMenu else {
            return
          }

          scrollSubject.send(origin)
        }
      }
    }
    .toolbar(fullScreen ? .hidden : .automatic)
    .toolbarHidden(hideToolbar && !fullScreen && !isVisible)
    .cursorHidden(hideCursor && !isVisible)
    .environment(collection.sidebar)
    .environment(\.navigationColumns, $columns)
    // Yes, the code listed below is dumb.
    .onChange(of: columns) {
      scrollingSubject.send(false)
    }
    .onChange(of: trackingMenu) {
      scrollingSubject.send(false)
    }
    .onReceive(scrollingPublisher) { isScrolling in
      self.isScrolling = isScrolling
    }
  }

  init() {
    let cursor = cursorSubject
      .map { _ in false }
      .prepend(true)
      // This, combined (pun) with the joining of the scroller publisher, is to prevent instances where the cursor
      // slightly moves when the user meant to scroll. Note that this currently best suits trackpads, as the duration
      // is too short to effectively counter a physical mouse (especially if it's heavy).
      .throttle(for: .milliseconds(500), scheduler: DispatchQueue.main, latest: true)

    let scroller = scrollSubject
      // When the user hides the sidebar, the toolbar shouldn't be hidden (it normally produces at most 6 events).
      .collect(6)
      .filter { origins in
        origins.dropFirst().allSatisfy { $0.x == origins.first?.x }
      }.map { _ in true }

    self.scrollingPublisher = scroller
      .map { _ in cursor }
      .switchToLatest()
      .merge(with: scrollingSubject)
      .removeDuplicates()
      .eraseToAnyPublisher()
  }
}
