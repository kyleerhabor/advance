//
//  ImageCollectionDetailView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/13/23.
//

import AdvanceCore
import Combine
import SwiftUI

struct ImageCollectionVisiblePreferenceKey: PreferenceKey {
  typealias Value = [ImageCollectionItemImage]

  static var defaultValue: Value {
    Value(reservingCapacity: VisiblePreferenceKey<Value>.defaultMinimumCapacity)
  }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = nextValue()
  }
}

struct ImageCollectionDetailItemPhaseView: View {
  @State private var phase = ImageResamplePhase.empty

  var body: some View {
    ImageCollectionItemView(phase: $phase) {
      ImageCollectionItemPhaseView(phase: phase)
    }
    .scaledToFit()
  }
}

struct ImageCollectionDetailItemView: View {
  let image: ImageCollectionItemImage

  var body: some View {
    // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
    VStack {
      // For some reason, we need to isolate the phase state to its own view for SwiftUI to automatically discard the
      // view and its memory.
      ImageCollectionDetailItemPhaseView()
    }
    .fileDialogCopy()
  }
}

struct ImageCollectionDetailVisibleView: View {
  let images: [ImageCollectionItemImage]
  private var primary: ImageCollectionItemImage? { images.first }

  var body: some View {
    if let primary {
      let url = primary.url
      
      Color.clear
        .navigationTitle(Text(url.lastPath))
        .navigationDocument(url)
    }
  }
}

struct ImageCollectionDetailView: View {
  typealias VisibleImagesPreferenceKey = VisiblePreferenceKey<ImageCollectionItemImage>

  private let items: [ImageCollectionDetailItem]
  private let subject = PassthroughSubject<VisibleImagesPreferenceKey.Value, Never>()
  private let publisher: AnyPublisher<VisibleImagesPreferenceKey.Value, Never>

  @Environment(\.imagesID) private var id

  init(items: [ImageCollectionDetailItem]) {
    self.items = items
    self.publisher = subject
      .throttle(for: .imagesScrollInteraction, scheduler: DispatchQueue.main, latest: true)
      .eraseToAnyPublisher()
  }

  var body: some View {
    List(items) { item in
      let image = item.image

      // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
      VStack {
        // For some reason, we need to isolate the phase state to its own view for SwiftUI to automatically discard the
        // view and its memory.
        ImageCollectionDetailItemPhaseView()
      }
      .fileDialogCopy()
      .anchorPreference(key: VisiblePreferenceKey.self, value: .bounds) { [VisibleItem(item: image, anchor: $0)] }
    }
    .listStyle(.plain)
    .preferencePublisher(VisibleImagesPreferenceKey.self, subject: subject, publisher: publisher)
    .overlayPreferenceValue(VisibleImagesPreferenceKey.self) { items in
      GeometryReader { proxy in
        let local = proxy.frame(in: .local)
        let images = items
          .filter { local.intersects(proxy[$0.anchor]) }
          .map(\.item)

        // The reason we're factoring the view into its own preference value is because the current one will be called
        // on *every scroll* event the user performs. While views are cheap, there is a cost to always recreating
        // them—and some are slower than others (navigationDocument(_:), for example). In my experience, this split
        // causes CPU usage to decrease from 60-68% to 47-52%, which is a major performance improvement (before anchor
        // preferences, CPU usage was often 42-48%).
        //
        // Now, the reason we're using preferences to report the filtered images (instead of, say, a @State variable),
        // is because of SwiftUI's ability to track changes. @State, just from observing its effects, has no way of
        // distinguishing itself from other observables besides reporting the change and letting SwiftUI diff them.
        // As a result, users may experience slight hangs when the set of visible images changes (~55ms). A preference
        // key, meanwhile, just floats up the view hierarchy and dispenses its value to an attached view. The result
        // is that using preference values here results in no hangs, making it suitable for this case.
        Color.clear.preference(key: ImageCollectionVisiblePreferenceKey.self, value: images)
      }
    }
    .backgroundPreferenceValue(ImageCollectionVisiblePreferenceKey.self) { images in
      ImageCollectionDetailVisibleView(images: images)
    }
  }
}
