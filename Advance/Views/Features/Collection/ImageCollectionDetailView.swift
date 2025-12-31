//
//  ImageCollectionDetailView.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/13/23.
//

import AdvanceCore
import Combine
import Defaults
import ImageIO
import OSLog
import SwiftUI
@preconcurrency import VisionKit

struct ImageCollectionVisiblePreferenceKey: PreferenceKey {
  typealias Value = [ImageCollectionItemImage]

  static var defaultValue: Value {
    Value(reservingCapacity: VisiblePreferenceKey<Value>.defaultMinimumCapacity)
  }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = nextValue()
  }
}

struct ImageCollectionDetailItemBookmarkView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.imagesID) private var id

  @Binding var bookmarked: Bool
  var bookmark: Binding<Bool> {
    .init {
      bookmarked
    } set: { bookmarked in
      self.bookmarked = bookmarked

      collection.updateBookmarks()

      Task(priority: .medium) {
        do {
          try await collection.persist(id: id)
        } catch {
          Logger.model.error("Could not persist image collection \"\(id)\" (via detail bookmark): \(error)")
        }
      }
    }
  }

  var body: some View {
    ImageCollectionBookmarkView(isOn: bookmark)
  }
}

struct ImageCollectionDetailItemPhaseView: View {
  @State private var phase = ImageResamplePhase.empty
  let image: ImageCollectionItemImage

  var body: some View {
    let size = image.properties.orientedSize

    ImageCollectionItemView(image: image, phase: $phase) {
      ImageCollectionItemPhaseView(phase: phase)
    }
    .aspectRatio(size.width / size.height, contentMode: .fit)
  }
}

struct ImageCollectionDetailItemView: View {
  let image: ImageCollectionItemImage

  var body: some View {
    // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
    VStack {
      // For some reason, we need to isolate the phase state to its own view for SwiftUI to automatically discard the
      // view and its memory.
      ImageCollectionDetailItemPhaseView(image: image)
    }
    .contextMenu {
      @Bindable var image = image

      Section {
        ImageCollectionDetailItemBookmarkView(bookmarked: $image.bookmarked)
      }
    }
    .fileDialogCopy()
  }
}

struct ImageCollectionDetailVisibleView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(ImageCollectionSidebar.self) private var sidebar
  @Environment(\.imagesID) private var id

  let images: [ImageCollectionItemImage]

  private var primary: ImageCollectionItemImage? { images.first }

  var body: some View {
    let analysis = images.filter(\.hasAnalysisResults)
    let hasAnalysis = !analysis.isEmpty
    let isHighlighted = analysis.allSatisfy(\.isAnalysisHighlighted)

    let primaryID: Set<ImageCollectionItemImage.ID> = if let primary {
      [primary.id]
    } else {
      []
    }

    Color.clear
      .focusedSceneValue(\.liveTextHighlight, .init(
        identity: analysis.map(\.id),
        enabled: hasAnalysis,
        state: hasAnalysis && isHighlighted
      ) { highlight in
        analysis.forEach(setter(on: \.isAnalysisHighlighted, value: highlight))
      })
      .onChange(of: primary) {
        collection.current = primary?.id

        Task {
          do {
            try await collection.persist(id: id)
          } catch {
            Logger.model.error("Could not persist image collection \"\(id)\" via current: \(error)")
          }
        }
      }

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
  @Default(.margins) private var margins
  @Default(.collapseMargins) private var collapseMargins
  private var margin: Double { Double(margins) }
  private var half: Double { margin * 3 }
  private var full: Double { half * 2 }
  private var all: EdgeInsets { EdgeInsets(full) }
  private var top: EdgeInsets { EdgeInsets(horizontal: full, top: full, bottom: half) }
  private var middle: EdgeInsets { EdgeInsets(horizontal: full, top: half, bottom: half) }
  private var bottom: EdgeInsets { EdgeInsets(horizontal: full, top: half, bottom: full) }

  init(items: [ImageCollectionDetailItem]) {
    self.items = items
    self.publisher = subject
      .throttle(for: .imagesScrollInteraction, scheduler: DispatchQueue.main, latest: true)
      .eraseToAnyPublisher()
  }

  var body: some View {
    List(items) { item in
      let image = item.image
      let insets: EdgeInsets = if let edge = item.edge {
        switch edge {
          case .top: top
          case .bottom: bottom
        }
      } else {
        middle
      }

      ImageCollectionDetailItemView(image: image)
        .listRowInsets(.listRow + (collapseMargins ? insets : all))
        .listRowSeparator(.hidden)
        .shadow(radius: margin / 2)
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
