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

struct ImageCollectionNavigationDetailItemView<Label>: View where Label: View {
  typealias Action = (ImageCollectionItemImage.ID?) -> Void

  private let items: [ImageCollectionPathItem]
  private let action: Action
  private let label: Label

  var body: some View {
    Menu {
      ForEach(items) { item in
        Button(item.url.lastPath) {
          action(item.id)
        }
      }
    } label: {
      label
    } primaryAction: {
      action(items.first?.id)
    }.disabled(items.isEmpty)
  }

  init(items: [ImageCollectionPathItem], action: @escaping Action, @ViewBuilder label: () -> Label) {
    self.action = action
    self.items = items
    self.label = label()
  }
}

struct ImageCollectionNavigationDetailView: View {
  @Environment(ImageCollection.self) private var collection

  var body: some View {
    ScrollViewReader { proxy in
      var back: ImageCollectionItemImage.ID? { collection.path.back.last?.id }
      var forward: ImageCollectionItemImage.ID? { collection.path.forward.first?.id }

      ImageCollectionDetailView(items: collection.detail)
        .toolbar(id: "Navigation") {
          ToolbarItem(id: "Navigation", placement: .navigation) {
            // For some reason, the title is not used in the customize toolbar modal.
            ControlGroup("Navigate") {
              ImageCollectionNavigationDetailItemView(items: collection.path.back.reversed()) { id in
                navigate(proxy: proxy, to: id)
              } label: {
                Label("Back", systemImage: "chevron.backward")
              }.help("Images.Navigation.Back.Help")

              ImageCollectionNavigationDetailItemView(items: collection.path.forward) { id in
                navigate(proxy: proxy, to: id)
              } label: {
                Label("Forward", systemImage: "chevron.forward")
              }.help("Images.Navigation.Forward.Help")
            }.controlGroupStyle(.navigation)
          }
        }
        .focusedSceneValue(\.detailScroller, .init(identity: .detail) { id in
          scroll(proxy: proxy, to: id)
        })
        .focusedSceneValue(\.back, .init(identity: back, enabled: back != nil) {
          navigate(proxy: proxy, to: back)
        })
        .focusedSceneValue(\.forward, .init(identity: forward, enabled: forward != nil) {
          navigate(proxy: proxy, to: forward)
        })
    }
  }

  func navigate(id: ImageCollectionItemImage.ID?) {
    collection.path.item = id

    let urls = collection.path.items
      .compactMap { collection.items[$0]?.image }
      .map { ($0.id, $0.url) }

    collection.path.update(urls: .init(uniqueKeysWithValues: urls))
  }

  @MainActor
  func scroll(proxy: ScrollViewProxy, to id: ImageCollectionItemImage.ID) {
    // https://stackoverflow.com/a/72808733/14695788
    Task {
      // TODO: Figure out how to change the animation (the parameter is currently ignored)
      withAnimation {
        proxy.scrollTo(id, anchor: .top)
      }
    }
  }

  @MainActor
  func navigate(proxy: ScrollViewProxy, to id: ImageCollectionItemImage.ID?) {
    navigate(id: id)

    guard let id else {
      return
    }

    scroll(proxy: proxy, to: id)
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
  @State private var isHovering = false
  @State private var isScrolling = false
  private var isVisible: Bool { !(isHovering && isScrolling) }
  private var window: NSWindow? { capture.window }
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
        .navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
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
    }.onChange(of: trackingMenu) {
      scrollingSubject.send(false)
    }.onReceive(scrollingPublisher) { isScrolling in
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
