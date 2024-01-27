//
//  ImageCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Defaults
import Combine
import SwiftUI

// MARK: - Environment keys

struct ImageCollectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = UUID()
}

struct VisibleEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant([ImageCollectionItemImage]())
}

extension EnvironmentValues {
  var id: ImageCollectionEnvironmentKey.Value {
    get { self[ImageCollectionEnvironmentKey.self] }
    set { self[ImageCollectionEnvironmentKey.self] = newValue }
  }

  var visible: VisibleEnvironmentKey.Value {
    get { self[VisibleEnvironmentKey.self] }
    set { self[VisibleEnvironmentKey.self] = newValue }
  }
}

// MARK: - Views

struct ImageCollectionNavigationSidebarView: View {
  @Environment(\.navigationColumns) @Binding private var columns
  @FocusState private var focused: Bool

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionSidebarView()
        .focused($focused)
        .focusedSceneValue(\.sidebarScroller, .init(identity: .sidebar) { item in
          Task {
            // We're using completion blocks to synchronize actions in the UI.
            //
            // If the sidebar is not open, the scroll should happen off-screen before presenting it to the user. In addition,
            // we need the selected image to gain focus, which can only occur after the sidebar is fully open.
            //
            // There is unfortunately a slight continuation of the scroll animation that may occur during the columns animation,
            // but it's subtle and miles ahead of the prior implementation.
            withAnimation {
              proxy.scrollTo(item.id, anchor: .center)
            } completion: {
              withAnimation {
                columns = .all
              } completion: {
                focused = true

                // With our current calls, this just sets the sidebar selection. We want to make sure the sidebar has
                // focus beforehand so the selection is not given a muted background.
                item.completion()
              }
            }
          }
        })
    }
  }
}

struct ImageCollectionNavigationDetailView: View {
  var images: [ImageCollectionDetailItem]

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionDetailView(items: images)
        .focusedSceneValue(\.detailScroller, .init(identity: .detail) { id in
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
  @Environment(ImageCollection.self) private var collection
  @Environment(WindowCapture.self) private var capture
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
  @State private var isVisible = true
  private var window: NSWindow? { capture.window }
  private var isDetailOnly: Bool { columns == .detailOnly }

  private let scrollSubject = PassthroughSubject<CGPoint, Never>()
  private let cursorSubject = PassthroughSubject<Void, Never>()
  private let visibleSubject = PassthroughSubject<Bool, Never>()
  private let visiblePublisher: AnyPublisher<Bool, Never>

  var body: some View {
    NavigationSplitView(columnVisibility: $columns) {
      // TODO: Add a feature to scroll the sidebar when opened
      //
      // This requires knowing the sidebar was explicitly opened by the user (and not through implicit means like scrolling
      // to a particular image, aka "Show in Sidebar")
      ImageCollectionNavigationSidebarView()
        .navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
        .environment(\.detailScroller, detailScroller ?? .init(identity: .unknown, scroll: noop))
    } detail: {
      ImageCollectionNavigationDetailView(images: collection.detail)
        .scrollIndicators(hideScroll && isDetailOnly ? .hidden : .automatic)
        .frame(minWidth: 256)
        .environment(\.sidebarScroller, sidebarScroller ?? .init(identity: .unknown, scroll: noop))
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
    .onContinuousHover { phase in
      guard let window,
            !window.inLiveResize  else {
        return
      }

      switch phase {
        case .active: cursorSubject.send()
        case .ended: isVisible = true
      }
    }.onChange(of: columns) {
      visibleSubject.send(true)
    }.onChange(of: trackingMenu) {
      visibleSubject.send(true)
    }.onReceive(visiblePublisher) { isVisible in
      self.isVisible = isVisible
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

    self.visiblePublisher = scroller
      .map { _ in cursor }
      .switchToLatest()
      .merge(with: visibleSubject)
      .removeDuplicates()
      .eraseToAnyPublisher()
  }
}
