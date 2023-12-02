//
//  ImageCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Combine
import OSLog
import SwiftUI

struct SelectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(ImageCollectionView.Selection())
}

struct VisibleEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant([ImageCollectionItemImage]())
}

extension EnvironmentValues {
  var selection: SelectionEnvironmentKey.Value {
    get { self[SelectionEnvironmentKey.self] }
    set { self[SelectionEnvironmentKey.self] = newValue }
  }

  var visible: VisibleEnvironmentKey.Value {
    get { self[VisibleEnvironmentKey.self] }
    set { self[VisibleEnvironmentKey.self] = newValue }
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

struct ImageCollectionItemPhaseView: View {
  @State private var elapsed = false
  private var imagePhase: ImagePhase {
    .init(phase) ?? .empty
  }

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
        }
      }.overlay {
        ProgressView()
          .visible(imagePhase == .empty && elapsed)
          .animation(.default, value: elapsed)
      }.overlay {
        if case .failure = phase {
          // We can't really get away with not displaying a failure view.
          Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.multicolor)
            .imageScale(.large)
        }
      }
      .animation(.default, value: imagePhase)
      .task {
        do {
          try await Task.sleep(for: .seconds(1))
        } catch is CancellationError {
          // Fallthrough
        } catch {
          Logger.ui.fault("Image elapse threw an error besides CancellationError: \(error)")
        }

        elapsed = true
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

      Task {
        guard let phase = await resample(image: image, size: size) else {
          return
        }
        
        if case let .failure(err) = phase {
          Logger.ui.error("Could not resample image \"\(image.url.string)\": \(err)")
        }

        self.phase = phase
      }
    } content: {
      @Bindable var image = image

      ImageCollectionItemPhaseView(phase: $phase)
        .overlay {
          overlay($phase)
        }
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
      // FIXME: For some reason, if the user scrolls fast enough in the UI, source returns nil.
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
        .focusedSceneValue(\.sidebarScroller, .init(selection: selection) { selection in
          // The only place we're calling this is in ImageCollectionDetailItemView with a single item.
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
  @AppStorage(Keys.trackCurrentImage.key) private var trackCurrentImage = Keys.trackCurrentImage.value
  @AppStorage(Keys.displayTitleBarImage.key) private var displayTitleBarImage = Keys.displayTitleBarImage.value
  @FocusedValue(\.sidebarScroller) private var sidebarScroller
  // If we could move this to a background view while keeping it in the environment, we'd probably have no animation hitches.
  @State private var visible = [ImageCollectionItemImage]()
  private var visibleImage: ImageCollectionItemImage? { visible.last }
  private var visibleImageURL: URL? {
    guard displayTitleBarImage else {
      return nil
    }

    return visible.last?.url
  }

  var images: [ImageCollectionItemImage]

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionDetailView(images: images, scrollSidebar: sidebarScroller?.scroll ?? noop)
        .navigationTitle(Text(visibleImageURL?.deletingPathExtension().lastPathComponent ?? "Sequential"))
        // I wish it were possible to pass nil to not use this modifier. This workaround displays a blank file that doesn't
        // point anywhere.
        .navigationDocument(visibleImageURL ?? .file)
        .environment(\.visible, $visible)
        .focusedSceneValue(\.detailScroller, .init(selection: selection) { selection in
          guard let id = images.filter(
            in: selection.subtracting(self.selection),
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
        }).focusedSceneValue(\.jumpToCurrentImage, .init(enabled: visibleImage != nil) {
          let id = visibleImage!.id

          selection = [id]

          sidebarScroller?.scroll([id])
        }).onChange(of: trackCurrentImage) {
          guard !trackCurrentImage else {
            return
          }

          visible = []
        }
    }
  }
}

struct ImageCollectionView: View {
  typealias Selection = Set<ImageCollectionItemImage.ID>

  @Environment(Window.self) private var win
  @Environment(\.fullScreen) private var fullScreen
  @Environment(\.collection) private var collection
  @AppStorage(Keys.windowless.key) private var windowless = Keys.windowless.value
  @SceneStorage("sidebar") private var columns = NavigationSplitViewVisibility.all
  @State private var selection = Selection()
  private let scrollSubject = PassthroughSubject<CGPoint, Never>()
  private let cursorSubject = PassthroughSubject<Void, Never>()
  private let toolbarSubject = PassthroughSubject<Bool, Never>()
  private let toolbarPublisher: AnyPublisher<Bool, Never>
  private var window: NSWindow? { win.window }

  var body: some View {
    NavigationSplitView(columnVisibility: $columns) {
      ImageCollectionNavigationSidebarView(columns: $columns)
        .navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ImageCollectionNavigationDetailView(images: collection.wrappedValue.images)
        .frame(minWidth: 256)
    }
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
    }
    .environment(\.selection, $selection)
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
      // We can't use toolbarSubject since duplicate elements are dropped. If the user has the toolbar visible (therefore,
      // the last value is true) and tries to enter full screen, setToolbarVisibility won't be called, causing the title
      // bar separator to be set to .automatic instead of .none (which is bad in light mode, where a thin line is drawn
      // at the top of the screen)
      setToolbarVisibility(true)
    }.onReceive(toolbarPublisher) { visible in
      setToolbarVisibility(visible)
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

  func setToolbarVisibility(_ visible: Bool) {
    guard let window else {
      return
    }

    Self.setToolbarVisibility(visible, for: window)
  }

  static func setToolbarVisibility(_ visible: Bool, for window: NSWindow) {
    window.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = visible ? 1 : 0

    // For some reason, full screen windows in light mode draw a slight line under the top of the screen after
    // scrolling for a bit. This doesn't occur in dark mode, which is interesting.
    window.animator().titlebarSeparatorStyle = visible && !window.isFullScreen() ? .automatic : .none
  }
}
