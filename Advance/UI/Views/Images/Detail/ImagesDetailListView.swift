//
//  ImagesDetailListView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/11/24.
//

import AdvanceCore
import Combine
import IdentifiedCollections
import SwiftUI

@Observable
class ImagesDetailListViewModel {
  var isHovering = false
  var isActive = false
  @ObservationIgnored let cursorSubject = PassthroughSubject<Void, Never>()
  @ObservationIgnored let scrollSubject = PassthroughSubject<CGPoint, Never>()
  @ObservationIgnored let isScrollingSubject = PassthroughSubject<Bool, Never>()
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

struct ScrollOffsetPreferenceKey<A>: PreferenceKey {
  typealias Value = Anchor<A>?

  static var defaultValue: Value {
    nil
  }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    guard let next = nextValue() else {
      return
    }

    value = next
  }
}

struct ImagesDetailListView: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.isTrackingMenu) private var isTrackingMenu
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen
  @Environment(\.isWindowLiveResizeActive) private var isWindowLiveResizeActive
  @AppStorage(StorageKeys.hiddenLayout) private var hiddenLayout
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibility
  @State private var model = ImagesDetailListViewModel()

  var body: some View {
    ScrollViewReader { proxy in
      List(images.isReady ? images.items2 : []) { _ in
        Color.clear
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
      // TODO: Document rationale for not hiding on scroll.
      .scrollIndicators(hiddenLayout.scroll && columnVisibility == .detailOnly ? .hidden : .automatic)
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
      .onChange(of: self.columnVisibility) {
        self.model.isScrollingSubject.send(false)
      }
    }
  }
}
