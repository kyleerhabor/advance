//
//  ImageCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Combine
import OSLog
import SwiftUI

struct ImageCollectionItemPhaseView<Overlay>: View where Overlay: View {
  @State private var elapsed = false

  @Binding var phase: AsyncImagePhase
  @ViewBuilder var overlay: (Binding<AsyncImagePhase>) -> Overlay

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
      }.overlay {
        overlay($phase)
      }.task {
        guard (try? await Task.sleep(for: .seconds(1))) != nil else {
          return
        }

        withAnimation {
          elapsed = true
        }
      }
  }
}

struct ImageCollectionItemView<Overlay>: View where Overlay: View {
  typealias ImageTask = Task<AsyncImagePhase, Error>
  typealias KeyPath = WritableKeyPath<ImageCollectionItemImage, AsyncImagePhase>

  @Environment(\.pixelLength) private var pixel

  @State private var phase = AsyncImagePhase.empty
  @State private var task: ImageTask?

  let image: ImageCollectionItemImage
  @ViewBuilder var overlay: (Binding<AsyncImagePhase>) -> Overlay

  var body: some View {
    DisplayView { size in
      // Does Image I/O round up when you provide a pixel size? If not, we should do so so images are never lesser
      // in quality.
      let size = CGSize(
        width: size.width / pixel,
        height: size.height / pixel
      )

      let task = ImageTask {
        do {
          let thumbnail = try await image.scoped { try await resample(url: image.url, size: size) }

          return .success(thumbnail)
        } catch ImageError.thumbnail {
          guard let resolved = await resolve(image: image) else {
            return .failure(ImageError.thumbnail)
          }

          let url = resolved.bookmark.url

          image.item.bookmark.data = resolved.bookmark.data
          image.item.bookmark.url = url
          image.url = url
          image.aspectRatio = resolved.properties.width / resolved.properties.height
          image.orientation = resolved.properties.orientation
          image.analysis = nil

          do {
            let thumbnail = try await url.scoped { try await resample(url: url, size: size) }

            return .success(thumbnail)
          } catch {
            return .failure(error)
          }
        } catch {
          if let err = error as? CancellationError {
            throw err
          }

          return .failure(error)
        }
      }

      self.task = task

      if case let .success(phase) = await task.result {
        // If we're updating an already existing image with a new image, don't perform an animation.
        if case .success = self.phase, case .success = phase {
          self.phase = phase
        } else {
          withAnimation {
            self.phase = phase
          }
        }
      }

      self.task = nil
    } content: {
      ImageCollectionItemPhaseView(phase: $phase, overlay: overlay)
    }.aspectRatio(image.aspectRatio, contentMode: .fit)
  }

  func resample(url: URL, size: CGSize) async throws -> Image {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ImageError.undecodable
    }

    let thumbnail = try source.resample(to: size.length())

    Logger.ui.info("Created a resampled image from \"\(url.string)\" at dimensions \(thumbnail.width.description)x\(thumbnail.height.description) for size \(size.width) / \(size.height)")

    try Task.checkCancellation()

    return .init(nsImage: .init(cgImage: thumbnail, size: size))
  }

  func resolve(image: ImageCollectionItemImage) async -> ResolvedBookmarkImage? {
    let bookmark: Bookmark

    do {
      if let document = image.item.bookmark.document {
        let mark = try document.resolve()

        document.data = mark.data
        document.url = mark.url

        bookmark = try mark.url.scoped { try image.item.bookmark.resolve() }
      } else {
        bookmark = try image.item.bookmark.resolve()
      }
    } catch {
      Logger.model.error("\(error)")

      return nil
    }

    guard bookmark.url != image.url else {
      Logger.model.error("Image resampling for URL \"\(image.url.string)\" failed and bookmark was not stale")

      return nil
    }

    Logger.model.info("Image resampling for URL \"\(image.url.string)\" failed and bookmark was stale. Refreshing...")

    guard let properties = bookmark.url.scoped({ ImageProperties(at: bookmark.url) }) else {
      return nil
    }

    return .init(id: image.id, bookmark: bookmark, properties: properties)
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

struct SidebarScroller: Equatable, Hashable {
  let selection: ImageCollectionView.Selection
  let scroll: () -> Void

  init(selection: ImageCollectionView.Selection, _ scroll: @escaping () -> Void) {
    self.selection = selection
    self.scroll = scroll
  }

  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.selection == rhs.selection
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(selection)
  }
}

struct Scroller {
  // While we're not directly using this property, it helps SwiftUI not excessively re-evaluate the view body (presumably
  // because a closure doesn't have an identity).
  let selection: ImageCollectionView.Selection
  let scroll: () -> Void

  init(selection: ImageCollectionView.Selection, _ scroll: @escaping () -> Void) {
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
            withAnimation {
              proxy.scrollTo(id, anchor: .center)

              columns = .all
            }

            // Yes, this is convoluted; but it fixes an issue where focus won't apply when the sidebar is not already open.
            Task {
              focused = true
            }
          }
        }).focusedSceneValue(\.sidebarScroller, .init(selection: selection) {
          // The only place we're calling this is in ImageCollectionDetailItemView with a single item.
          let id = selection.first!

          Task {
            withAnimation {
              proxy.scrollTo(id, anchor: .center)

              columns = .all
            }
          }
      })
    }
  }
}

struct ImageCollectionNavigationDetailView: View {
  @Environment(\.selection) @Binding private var selection
  @FocusedValue(\.sidebarScroller) private var sidebarScroller

  @Binding var images: [ImageCollectionItemImage]

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionDetailView(images: images, scrollSidebar: sidebarScroller?.scroll ?? noop)
        .focusedSceneValue(\.detailScroller, .init(selection: selection) { [selection] in
          guard let id = images.filter(
            in: self.selection.subtracting(selection),
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
  @SceneStorage("sidebar") private var columns = NavigationSplitViewVisibility.all
  @State private var selection = Selection()
  private let subject = PassthroughSubject<CGPoint, Never>()
  private let publisher: AnyPublisher<Void, Never>
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
    }
    .navigationTitle(Text(visible?.deletingPathExtension().lastPathComponent ?? "Sequential"))
    // I wish it were possible to pass nil to not use this modifier. This workaround displays a blank file that doesn't
    // point anywhere.
    .navigationDocument(visible ?? .none)
    .toolbar(fullScreen == true ? .hidden : .automatic)
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
    }.onPreferenceChange(ScrollPositionPreferenceKey.self) { origin in
      subject.send(origin)
    }.onReceive(publisher) {
      guard columns == .detailOnly && fullScreen == false else {
        return
      }

      setTitleBarVisibility(false)
    }.onContinuousHover { _ in
      guard window?.inLiveResize == false else {
        return
      }

      setTitleBarVisibility(true)
    }.onChange(of: columns) {
      setTitleBarVisibility(true)
    }.environment(\.selection, $selection)
  }

  init() {
    // When the user toggles the sidebar, I don't want the title bar to be hidden.
    self.publisher = subject
      .collect(6) // 12?
      .filter { origins in
        origins.dropFirst().allSatisfy { $0.x == origins.first?.x }
      }
      .map { _ in }
      .eraseToAnyPublisher()
  }

  func setTitleBarVisibility(_ visible: Bool) {
    guard windowless, let window else {
      return
    }

    let opacity: CGFloat = visible ? 1 : 0

    if window.standardWindowButton(.closeButton)?.superview?.alphaValue != opacity {
      window.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = opacity
      window.animator().titlebarSeparatorStyle = visible ? .automatic : .none
    }
  }
}
