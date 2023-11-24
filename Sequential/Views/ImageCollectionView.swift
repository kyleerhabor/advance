//
//  ImageCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Combine
import OSLog
import SwiftUI

struct ImageCollectionItemPhaseView: View {
  @State private var elapsed = false

  @Binding var phase: AsyncImagePhase

  var body: some View {
    // For transparent images, the fill is still useful to know that an image is supposed to be in the frame, but when
    // the view's image has been cleared (see the .onDisappear), it's kind of weird to see the fill again. Maybe try
    // and determine if the image is transparent and, if so, only display the fill on its first appearance? This would
    // kind of be weird for collections that mix transparent and non-transparent images, however (since there's no
    // clear separator).
    Color.tertiaryFill
      .visible(phase.image == nil)
      .overlay {
        if let image = phase.image {
          image.resizable()
        } else if case .failure = phase {
          // We can't really get away with not displaying a failure view.
          Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.multicolor)
            .imageScale(.large)
        } else {
          ProgressView().visible(elapsed)
        }
      }.task {
        guard (try? await Task.sleep(for: .seconds(1))) != nil else {
          return
        }

        withAnimation {
          elapsed = true
        }
      }.onDisappear {
        elapsed = false
      }
  }
}

struct ImageCollectionItemView<Overlay>: View where Overlay: View {
  @Environment(\.pixelLength) private var pixel
  @State private var phase = AsyncImagePhase.empty

  let image: ImageCollectionItemImage
  @ViewBuilder var overlay: (Binding<AsyncImagePhase>) -> Overlay

  var body: some View {
    DisplayView { size in
      let size = CGSize(
        width: size.width / pixel,
        height: size.height / pixel
      )

      guard let phase = await resample(image: image, size: size) else {
        return
      }

      if case let .failure(err) = phase {
        Logger.ui.error("Could not resample image \"\(image.url.string)\": \(err)")
      }

      // If we're replacing an already existing image with a new image, don't animate.
      if case .success = self.phase,
         case .success = phase {
        // Either storing image data in @State is slow, rendering it is slow, or transferring it across actors is slow.
        // This seems to only be the case for certain images, too.
        self.phase = phase
      } else {
        withAnimation {
          self.phase = phase
        }
      }
    } content: {
      ImageCollectionItemPhaseView(phase: $phase)
        .overlay { overlay($phase) }
    }.aspectRatio(image.aspectRatio, contentMode: .fit)
  }

  @MainActor
  func resample(image: ImageCollectionItemImage, size: CGSize) async -> AsyncImagePhase? {
    let thumbnail: Image

    do {
      thumbnail = try await image.scoped { try await resample(url: image.url, size: size) }
    } catch ImageError.thumbnail {
      do {
        let snapshot = try await resolve(image: image)

        if let document = snapshot.document {
          image.item.bookmark.document?.data = document.data
          image.item.bookmark.document?.url = document.url
        }

        image.url = snapshot.image.bookmark.url
        image.aspectRatio = snapshot.image.properties.width / snapshot.image.properties.height
        image.orientation = snapshot.image.properties.orientation
        image.item.bookmark.data = snapshot.image.bookmark.data
        image.item.bookmark.url = snapshot.image.bookmark.url
        image.analysis = nil

        thumbnail = try await image.scoped { try await resample(url: image.url, size: size) }
      } catch is CancellationError {
        return nil
      } catch {
        return .failure(error)
      }
    } catch is CancellationError {
      return nil
    } catch {
      return .failure(error)
    }

    return .success(thumbnail)
  }

  func resample(url: URL, size: CGSize) async throws -> Image {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      // FIXME: For some reason, if the user scrolls fast enough in the UI, this returns nil and throws.
      throw ImageError.undecodable
    }

    let thumbnail = try source.resample(to: size.length().rounded(.up))

    Logger.ui.info("Created a resampled image from \"\(url.string)\" at dimensions \(thumbnail.width.description)x\(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return .init(nsImage: .init(cgImage: thumbnail, size: size))
  }

  func resolve(image: ImageCollectionItemImage) async throws -> ResolvedBookmarkImageSnapshot {
    let document: Bookmark?
    let bookmark: Bookmark

    if let docu = image.item.bookmark.document {
      let doc = try docu.resolve()

      document = doc
      bookmark = try doc.url.scoped {
        try Bookmark(data: image.item.bookmark.data, resolving: [], relativeTo: doc.url) { url in
          try url.scoped {
            try url.bookmark(options: [], document: doc.url)
          }
        }
      }
    } else {
      document = nil
      bookmark = try image.item.bookmark.resolve()
    }

    guard image.url != bookmark.url else {
      throw BookmarkResolutionError()
    }

    guard let properties = bookmark.url.scoped({ ImageProperties(at: bookmark.url) }) else {
      throw ImageError.undecodable
    }

    return .init(
      document: document,
      image: .init(
        id: image.id,
        bookmark: bookmark,
        properties: properties
      )
    )
  }
}

extension ImageCollectionItemView where Overlay == EmptyView {
  init(image: ImageCollectionItemImage) {
    self.init(image: image) { _ in }
  }
}

struct SelectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(ImageCollectionView.Selection())
}

extension EnvironmentValues {
  var selection: SelectionEnvironmentKey.Value {
    get { self[SelectionEnvironmentKey.self] }
    set { self[SelectionEnvironmentKey.self] = newValue }
  }
}

struct Scroller {
  typealias Scroll = (ImageCollectionView.Selection) -> Void

  // While we're not directly using this property, it helps SwiftUI not excessively re-evaluate the view body (presumably
  // because a closure doesn't have an identity).
  let selection: ImageCollectionView.Selection
  let scroll: Scroll

  init(selection: ImageCollectionView.Selection, _ scroll: @escaping Scroll) {
    self.selection = selection
    self.scroll = scroll
  }
}

extension Scroller: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.selection == rhs.selection
  }
}

struct SidebarScrollerFocusedValueKey: FocusedValueKey {
  typealias Value = Scroller
}

struct DetailScrollerFocusedValueKey: FocusedValueKey {
  typealias Value = Scroller
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

struct ImageCollectionNavigationSidebarView: View {
  @Environment(\.prerendering) private var prerendering
  @Environment(\.collection) private var collection
  @Environment(\.selection) @Binding private var selection
  @FocusedValue(\.detailScroller) private var detailScroller
  @FocusState private var focused: Bool

  @Binding var columns: NavigationSplitViewVisibility

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionSidebarView(scrollDetail: detailScroller?.scroll ?? noop)
        .focused($focused)
        .focusedSceneValue(\.jumpToCurrentImage, .init(enabled: collection.wrappedValue.currentImage != nil) {
          let id = collection.wrappedValue.currentImage!.id

          selection = [id]

          Task {
            scroll(id: id, proxy: proxy)
          }
        }).focusedSceneValue(\.sidebarScroller, .init(selection: selection) { selection in
          // The only place we're calling this is in ImageCollectionDetailItemView with a single item.
          let id = selection.first!

          Task {
            scroll(id: id, proxy: proxy)
          }
      })
    }
  }

  func scroll(id: some Hashable, proxy: ScrollViewProxy) {
    withAnimation {
      // Idea: Let the proxy finish scrolling before opening the sidebar.
      //
      // This will most likely involve the same tactic used to determine when the user is scrolling in the
      // detail view.
      proxy.scrollTo(id, anchor: .center)

      columns = .all
    }

    focused = true
  }
}

struct ImageCollectionNavigationDetailView: View {
  @Environment(\.selection) private var selection
  @FocusedValue(\.sidebarScroller) private var sidebarScroller

  @Binding var images: [ImageCollectionItemImage]

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionDetailView(images: images, scrollSidebar: sidebarScroller?.scroll ?? noop)
        .focusedSceneValue(\.detailScroller, .init(selection: selection.wrappedValue) { selection in
          guard let id = images.filter(
            in: selection.subtracting(self.selection.wrappedValue),
            by: \.id
          ).last?.id else {
            return
          }

          // https://stackoverflow.com/a/72808733/14695788
          Task {
            // TODO: Figure out how to change the animation (the parameter is currently ignored).
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

  @Environment(Window.self) private var win
  @Environment(\.fullScreen) private var fullScreen
  @Environment(\.prerendering) private var prerendering
  @Environment(\.collection) private var collection
  @AppStorage(Keys.windowless.key) private var windowless = Keys.windowless.value
  @AppStorage(Keys.displayTitleBarImage.key) private var displayTitleBarImage = Keys.displayTitleBarImage.value
  @AppStorage(Keys.trackCurrentImage.key) private var trackCurrentImage = Keys.trackCurrentImage.value
  @SceneStorage("sidebar") private var columns = NavigationSplitViewVisibility.all
  @State private var selection = Selection()
  private let scrollSubject = PassthroughSubject<CGPoint, Never>()
  private let cursorSubject = PassthroughSubject<Void, Never>()
  private let toolbarSubject = PassthroughSubject<Bool, Never>()
  private let toolbarPublisher: AnyPublisher<Bool, Never>
  private var window: NSWindow? { win.window }

  var body: some View {
    // Interestingly, using @State causes the app to hang whenever the list of URLs is changed. I presume this has to
    // do with how changes are propagated.
    let visible = displayTitleBarImage ? collection.wrappedValue.currentImage?.url : nil

    NavigationSplitView(columnVisibility: $columns) {
      ImageCollectionNavigationSidebarView(columns: $columns)
        .navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ImageCollectionNavigationDetailView(images: collection.images)
        .frame(minWidth: 256)
    }
    .navigationTitle(Text(visible?.deletingPathExtension().lastPathComponent ?? "Sequential"))
    // I wish it were possible to pass nil to not use this modifier. This workaround displays a blank file that doesn't
    // point anywhere.
    .navigationDocument(visible ?? .file)
    .toolbar(fullScreen ? .hidden : .automatic)
    .task {
      let resolved = await collection.wrappedValue.load()
      let items = Dictionary(collection.wrappedValue.items.map { ($0.bookmark.id, $0) }) { _, item in item }
      let results = resolved.map { bookmark in
        switch bookmark {
          case .document(let document):
            let doc = BookmarkDocument(data: document.data, url: document.url)
            let items = document.images.map { image in
              ImageCollectionItem(
                image: image,
                document: doc,
                bookmarked: items[image.id]?.bookmarked ?? false
              )
            }

            doc.files = items.map(\.bookmark)

            return (BookmarkKind.document(doc), items)
          case .file(let image):
            let item = ImageCollectionItem(
              image: image,
              document: nil,
              bookmarked: items[image.id]?.bookmarked ?? false
            )

            return (BookmarkKind.file(item.bookmark), [item])
        }
      }

      collection.wrappedValue.bookmarks = results.map(\.0)
      collection.wrappedValue.items = results.flatMap(\.1)
      collection.wrappedValue.updateImages()
      collection.wrappedValue.updateBookmarks()
    }.onChange(of: trackCurrentImage) {
      guard !trackCurrentImage else {
        return
      }

      collection.wrappedValue.visible = []
    }
    // Yes, the listed code below is dumb.
    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { origin in
      guard let window,
            !window.isFullScreen() && windowless && columns == .detailOnly else {
        return
      }

      scrollSubject.send(origin)
    }.onContinuousHover { _ in
      guard let window, !window.inLiveResize else {
        return
      }

      cursorSubject.send()
    }.onChange(of: columns) {
      toolbarSubject.send(true)
    }.onChange(of: fullScreen) {
      toolbarSubject.send(true)
    }.onReceive(toolbarPublisher) { visible in
      guard let window else {
        return
      }

      Self.setToolbarVisibility(visible, for: window)
    }.environment(\.selection, $selection)
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

  static func setToolbarVisibility(_ visible: Bool, for window: NSWindow) {
    window.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = visible ? 1 : 0
    window.animator().titlebarSeparatorStyle = visible ? .automatic : .none
  }
}
