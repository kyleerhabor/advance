//
//  ImagesDetailListView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/11/24.
//

import AdvanceCore
import Combine
import OSLog
import SwiftUI

struct ImagesDetailListVisibleItem {
  typealias HighlightAction = (Bool) -> Void

  let item: ImagesItemModel
  let isHighlighted: Bool
  let highlight: HighlightAction
}

extension ImagesDetailListVisibleItem: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.item == rhs.item && lhs.isHighlighted == rhs.isHighlighted
  }
}

@Observable
class ImagesDetailListViewModel {
  var isHovering = false
  var isActive = false
  @ObservationIgnored let cursorSubject = PassthroughSubject<Void, Never>()
  @ObservationIgnored let scrollSubject = PassthroughSubject<CGPoint, Never>()
  @ObservationIgnored let isScrollingSubject = PassthroughSubject<Bool, Never>()
  @ObservationIgnored let visiblesSubject = PassthroughSubject<[VisibleItem<ImagesItemModel>], Never>()
  @ObservationIgnored let visiblesPublisher: AnyPublisher<[VisibleItem<ImagesItemModel>], Never>
  @ObservationIgnored private var isActiveCancellable: AnyCancellable?

  init() {
    let scroll = scrollSubject
      // When toggling the sidebar, the origin of the relevant view regularly changes, producing up to ~6 values. Here,
      // we capture the values and compare the x-axis to verify it hasn't changed. If it did, all we can tell is the
      // geometry of the relevant view was not consistent.
      .collect(6)
      .filter { origins in
        origins.dropFirst().allSatisfy { origin in
          origin.x == origins.first?.x
        }
      }
      .map(constantly(true))
      .eraseToAnyPublisher()

    let cursor = cursorSubject
      .map(constantly(false))
      .prepend(true)
      // This, combined (pun) with the the scroll publisher, is to prevent instances where the cursor slightly moves
      // where the user meant to scroll. This implementation is optimized for trackpads, as the duration is too short
      // to effectively counter a mouse (especially if it's heavy).
      .throttle(for: .imagesHoverInteraction, scheduler: DispatchQueue.main, latest: false)

    self.visiblesPublisher = visiblesSubject
      .throttle(for: .imagesScrollInteraction, scheduler: DispatchQueue.main, latest: true)
      .eraseToAnyPublisher()

    self.isActiveCancellable = scroll
      .map { _ in cursor }
      .switchToLatest()
      .merge(with: isScrollingSubject)
      .removeDuplicates()
      .sink { [weak self] isActive in
        self?.isActive = isActive
      }
  }
}

struct ImagesDetailListView: View {
  static private let defaultScrollAnchor = UnitPoint.top

  @Environment(ImagesModel.self) private var images
  @Environment(\.isTrackingMenu) private var isTrackingMenu
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen
  @Environment(\.isWindowLiveResizeActive) private var isWindowLiveResizeActive
  @AppStorage(StorageKeys.restoreLastImage) private var restoreLastImage
  @AppStorage(StorageKeys.layoutContinuousStyleHidden) private var hidden
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibility
  @State private var model = ImagesDetailListViewModel()

  var body: some View {
    ScrollViewReader { proxy in
      List(images.isReady ? images.items : []) { item in
        ImagesDetailItemView(item: item)
          .localized()
          // TODO: Don't hardcode.
          .listRowInsets(EdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -9))
          .listRowSeparator(.hidden)
          .anchorPreference(key: ScrollOffsetPreferenceKey.self, value: .origin, transform: identity)
      }
      .listStyle(.plain)
      .backgroundPreferenceValue(ScrollOffsetPreferenceKey<CGPoint>.self) { offset in
        GeometryReader { proxy in
          let origin = offset.map { proxy[$0] }

          Color.clear.onChange(of: origin) {
            guard let origin else {
              return
            }

            model.scrollSubject.send(origin)
          }
        }
      }
      .preferencePublisher(VisiblePreferenceKey.self, subject: model.visiblesSubject, publisher: model.visiblesPublisher)
      .overlayPreferenceValue(VisiblePreferenceKey<ImagesDetailListVisibleItem>.self) { items in
        GeometryReader { proxy in
          let local = proxy.frame(in: .local)
          let items = items.filter { local.intersects(proxy[$0.anchor]) }
          let visible = items.reduce(into: ImagesDetailVisible(
            items: Array(reservingCapacity: items.count),
            identity: Set(minimumCapacity: items.count),
            highlights: Array(reservingCapacity: items.count)
          )) { partialResult, item in
            partialResult.items.append(item.item.item)
            partialResult.identity.insert(item.item.item.id)
            partialResult.highlights.append(item.item.highlight)

            guard let isHighlighted = partialResult.isHighlighted else {
              partialResult.isHighlighted = item.item.isHighlighted

              return
            }

            guard isHighlighted else {
              return
            }

            partialResult.isHighlighted = item.item.isHighlighted
          }

          let item = visible.items.first

          Color.clear
            .preference(key: ImagesDetailVisiblePreferenceKey.self, value: visible)
            .onChange(of: item) {
              images.itemID = item?.id

              Task {
                do {
                  try await images.submit(currentItem: item)
                } catch {
                  Logger.model.error("\(error)")
                }
              }
            }
        }
      }
      .toolbarVisible(
        !hidden.toolbar
        || isWindowFullScreen
        || columnVisibility.columnVisibility != .detailOnly
        || !model.isActive
//        || !(model.isHovering && model.isActive)
      )
      .cursorVisible(
        !hidden.cursor
        || columnVisibility.columnVisibility != .detailOnly
        || !model.isActive
//        || !(model.isHovering && model.isActive)
      )
      // TODO: Document rationale for not hiding on scroll.
      .scrollIndicators(hidden.scroll && columnVisibility.columnVisibility == .detailOnly ? .hidden : .automatic)
      .focusedSceneValue(\.imagesDetailJump, ImagesNavigationJumpAction(identity: ImagesNavigationJumpIdentity(id: images.id, isReady: images.isReady)) { item in
        proxy.scrollTo(item.id, anchor: Self.defaultScrollAnchor)
      })
      .onContinuousHover { phase in
        switch phase {
          case .active:
            model.isHovering = true

            model.cursorSubject.send()
          case .ended:
            model.isHovering = false

            // TODO: Document distinction.
            model.isScrollingSubject.send(false)
        }
      }
      // TODO: Document rationale.
      //
      // FIXME: isTrackingMenu may be true while the UI is hidden.
      //
      // I think this can be resolved by discarding attempts to set the UI hidden when it's active. This is distinct
      // from setting a flag, as it may immediately hide the UI after reset.
      .onChange(of: isTrackingMenu) {
        model.isScrollingSubject.send(false)
      }
      .onChange(of: isWindowFullScreen) {
        model.isScrollingSubject.send(false)
      }
      .onChange(of: isWindowLiveResizeActive) {
        model.isScrollingSubject.send(false)
      }
      .onChange(of: columnVisibility.columnVisibility) {
        model.isScrollingSubject.send(false)
      }
      .onReceive(images.incomingItemID) { id in
        guard restoreLastImage else {
          return
        }

        Task {
          proxy.scrollTo(id, anchor: Self.defaultScrollAnchor)
        }
      }
    }
  }
}
