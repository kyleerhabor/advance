//
//  ImageCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

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

  var image: ImageCollectionItem
  @ViewBuilder var overlay: (Binding<AsyncImagePhase>) -> Overlay

  var body: some View {
    DisplayImageView(url: image.url, transaction: .init(animation: .default)) { $phase in
      ImageCollectionItemPhaseView(phase: $phase, overlay: overlay)
        .task { await check() }
    } failure: {
      // TODO: See if failure from the URL changing can be handled better.
      await check()
    }
    .aspectRatio(image.aspectRatio, contentMode: .fit)
    .onDisappear {
      closeSecurityScope()
    }
  }

  // This is a mess. Is there a better way we could handle this?

  func openSecurityScope() -> Bool {
    accessingSecurityScope = image.url.startAccessingSecurityScopedResource()

    return accessingSecurityScope
  }

  func closeSecurityScope() {
    if accessingSecurityScope {
      image.url.stopAccessingSecurityScopedResource()

      accessingSecurityScope = false
    }
  }

  func resolve() async throws -> (Bookmark, ImageProperties) {
    let bookmark = try await image.bookmark.resolve()

    guard let properties = await ImageProperties(at: bookmark.url) else {
      throw ImageError.undecodable
    }

    return (bookmark, properties)
  }

  func reachable(url: URL) -> Bool {
    do {
      return try url.checkResourceIsReachable()
    } catch {
      if let err = error as? CocoaError, err.code == .fileReadNoSuchFile {
        // We don't need to see the error.
        return false
      }

      Logger.ui.error("\(error)")

      return false
    }
  }

  @MainActor
  func check() async {
    let url = image.url

    // Image I/O does not give us any useful information on *why* it failed (here, at creating either an image
    // source or thumbnail). As a result, we have to resort to this less efficient method (as per the documentation).
    // Unfortunately this produces noise in logs from the task failure in DisplayImageView.
    //
    // To do this properly, I need a way to plug into DisplayImageView at the point of CGImageSourceCreateThumbnailAtIndex
    // so I can run this check.
    if !reachable(url: url) {
      Logger.ui.info("Image at URL \"\(url.string)\" is unreachable. Attempting to update...")

      closeSecurityScope()

      do {
        let resolved = try await resolve()

        image.update(bookmark: resolved.0, properties: resolved.1)
      } catch {
        Logger.ui.error("Could not resolve bookmark for image \"\(url.string)\": \(error)")

        return
      }
    }

    if image.bookmark.scoped && !openSecurityScope() {
      Logger.ui.error("Could not access security scope for \"\(url.string)\"")
    }
  }
}

extension ImageCollectionItemView where Overlay == EmptyView {
  init(image: ImageCollectionItem) {
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
  @Environment(\.collection) @Binding private var collection
  @Environment(\.selection) @Binding private var selection
  @AppStorage(Keys.offScreenScrolling.key) private var offScreenScrolling = Keys.offScreenScrolling.value
  @FocusedValue(\.detailScroller) private var detailScroller
  @Binding var columns: NavigationSplitViewVisibility

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionSidebarView(scrollDetail: detailScroller?.scroll ?? noop)
        .onChange(of: collection.currentImage) {
          guard offScreenScrolling, columns == .detailOnly,
                let id = collection.currentImage?.id else {
            return
          }

          proxy.scrollTo(id, anchor: .center)
        }.focusedSceneValue(\.jumpToCurrentImage, .init(enabled: collection.currentImage != nil) {
          let id = collection.currentImage!.id

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

  @Binding var images: [ImageCollectionItem]

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
  typealias Selection = Set<ImageCollectionItem.ID>

  @Environment(Window.self) private var win
  @Environment(\.collection) private var collection
  @AppStorage(Keys.displayTitleBarImage.key) private var displayTitleBarImage = Keys.displayTitleBarImage.value
  @SceneStorage("sidebar") private var columns = NavigationSplitViewVisibility.all
  @State private var selection = Selection()
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
    // point anywhere (the system decides to just use "the computer").
    .navigationDocument(visible ?? .none)
    .task {
      collection.wrappedValue.bookmarks = await collection.wrappedValue.load()
      collection.wrappedValue.updateImages()
      collection.wrappedValue.updateBookmarks()

      // FIXME: This does not work when the window is restored in full screen mode.
      guard let delegate = window?.delegate else {
        return
      }

      let prior = #selector(NSWindowDelegate.window(_:willUseFullScreenPresentationOptions:))
      let selector = #selector(WindowDelegate.window(_:willUseFullScreenPresentationOptions:))
      let method = class_getClassMethod(WindowDelegate.self, selector)!
      let impl = method_getImplementation(method)

      class_addMethod(delegate.superclass, prior, impl, nil)
    }.environment(\.selection, $selection)
  }
}
