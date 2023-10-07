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
  @State private var accessingSecurityScope = false
  @State private var phase = AsyncImagePhase.empty

  let image: ImageCollectionItemImage
  @ViewBuilder var overlay: (Binding<AsyncImagePhase>) -> Overlay

  var body: some View {
    DisplayImageView(url: image.url, transaction: .init(animation: .default)) { $phase in
      ImageCollectionItemPhaseView(phase: $phase, overlay: overlay)
//        .task { await check() }
    } failure: {
      // TODO: See if failure from the URL changing can be handled better.
//      await check()
    }.aspectRatio(image.aspectRatio, contentMode: .fit)
  }

  // TODO: Make this nicer.
//  func resolve() async throws -> (Bookmark, ImageProperties) {
//    let bookmark = try image.bookmark.resolve()
//
//    guard let properties = ImageProperties(at: bookmark.url) else {
//      throw ImageError.undecodable
//    }
//
//    return (bookmark, properties)
//  }

  func reachable(url: URL) -> Bool {
    do {
      return try url.checkResourceIsReachable()
    } catch {
      if let err = error as? CocoaError, err.code == .fileReadNoSuchFile {
        // We don't need to see the error.
        return false
      }

      Logger.model.error("Checking URL \"\(url.string)\" for reachable status resulted in an error: \(error)")

      return false
    }
  }

//  @MainActor
//  func check() async {
//    let url = image.url
//
//    // Image I/O does not give us any useful information on *why* it failed (here, at creating either an image
//    // source or thumbnail). As a result, we have to resort to this less efficient method (as per the documentation).
//    // Unfortunately this produces noise in logs from the task failure in DisplayImageView.
//    //
//    // To do this properly, I need a way to plug into DisplayImageView at the point of CGImageSourceCreateThumbnailAtIndex
//    // so I can run this check.
//    if !reachable(url: url) {
//      Logger.ui.error("Image at URL \"\(url.string)\" is unreachable. Attempting to update...")
//
//      do {
//        let resolved = try await resolve()
//
//        image.update(bookmark: resolved.0, properties: resolved.1)
//      } catch {
//        Logger.ui.error("Could not resolve bookmark for image \"\(url.string)\": \(error)")
//
//        return
//      }
//    }
//  }
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

          focused = true
          selection = [id]

          Task {
            withAnimation {
              proxy.scrollTo(id, anchor: .center)

              columns = .all
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
            Logger.ui.info("\(self.selection) vs. \(selection) vs. \(images)")

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
  @Environment(\.prerendering) private var prerendering
  @Environment(\.collection) private var collection
  @Environment(\.fullScreen) private var fullScreen
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
        .ignoresSafeArea(edges: windowless ? .top : [])
    }
    .navigationTitle(Text(visible?.deletingPathExtension().lastPathComponent ?? "Sequential"))
    // I wish it were possible to pass nil to not use this modifier. This workaround displays a blank file that doesn't
    // point anywhere.
    .navigationDocument(visible ?? .none)
    .task {
      let resolved = await collection.wrappedValue.load()
      let items = Dictionary(collection.wrappedValue.items.map { ($0.bookmark.id, $0) }) { _, item in item }
      let results = resolved.map { bookmark in
        switch bookmark {
          case .document(let document):
            let items = document.images.map { image in
              ImageCollectionItem(
                image: image,
                document: document.url,
                bookmarked: items[image.id]?.bookmarked ?? false
              )
            }

            let bookmark = BookmarkKind.document(.init(
              data: document.data,
              files: items.map(\.bookmark)
            ))

            return (bookmark, items)
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
