//
//  ImageCollectionView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/13/23.
//

import AdvanceCore
import Combine
import OSLog
import SwiftUI

// MARK: - Views

struct ImageCollectionNavigationSidebarView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.imagesID) private var id
  @FocusState private var focused: Bool

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionSidebarView()
        .focused($focused)
        .focusedSceneValue(\.navigator, .init(identity: id, enabled: false) { navigator in
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
//    await animate {
//      columns = .all
//    }

    focused = true
  }
}

struct ImageCollectionNavigationDetailView: View {
  @Environment(ImageCollection.self) private var collection

  var body: some View {
    ImageCollectionDetailView(items: collection.detail)
  }
}

struct ImageCollectionView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(Windowed.self) private var windowed
  @Environment(\.isTrackingMenu) private var isTrackingMenu
  @Environment(\.isWindowFullScreen) private var fullScreen
  @Environment(\.imagesID) private var id
  @State private var columns = NavigationSplitViewVisibility.all
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
    } detail: {
      ImageCollectionNavigationDetailView()
        .scrollIndicators(isDetailOnly ? .hidden : .automatic)
        .frame(minWidth: 256)
        .onContinuousHover { phase in
          guard let window,
                !window.inLiveResize else {
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
    }
    .toolbar(fullScreen ? .hidden : .automatic)
    .environment(collection.sidebar)
    // Yes, the code listed below is dumb.
    .onChange(of: columns) {
      scrollingSubject.send(false)
    }
    .onChange(of: isTrackingMenu) {
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
      .throttle(for: .imagesHoverInteraction, scheduler: DispatchQueue.main, latest: true)

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
