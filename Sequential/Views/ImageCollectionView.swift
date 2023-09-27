//
//  ImageCollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import OSLog
import SwiftUI

struct ImageCollectionItemPhaseView<Content>: View where Content: View {
  @State private var elapsed = false

  @Binding var phase: AsyncImagePhase
  @ViewBuilder var content: (Image) -> Content

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
          content(image)
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
        // This is necessary to slow down the memory creep SwiftUI creates when rendering some images. It does not
        // eliminate it, but severely halts it. As an example, I have a copy of the first volume of Soloist in a Cage (~700 MBs).
        // When the window size is the default and the sidebar is open but hasn't been scrolled through, by time I
        // reach page 24, the memory has ballooned to ~600 MB. With this little trick, however, it rests at about ~150-200 MBs,
        // and is nearly eliminated by the window being closed. Note that the memory creep is mostly applicable to
        // regular memory and not so much real memory. In addition, not all image collections need it, since there are
        // some which (magically) handle their own memory while not destroying the image (in other words, it rests at a
        // good average, like ~150 MB).
        //
        // In the future, I'd like to improve image loading so images are preloaded before they appear on-screen.
        phase = .empty
      }
  }
}

struct ImageCollectionItemView<Content>: View where Content: View {
  @State private var accessingSecurityScope = false
  @State private var phase = AsyncImagePhase.empty

  var image: ImageCollectionItem
  @ViewBuilder var content: (Image) -> Content

  var body: some View {
    DisplayImageView(url: image.url, transaction: .init(animation: .default)) { $phase in
      ImageCollectionItemPhaseView(phase: $phase, content: content)
        .task { await check() }
    } failure: {
      // This unfortunately produces a "flash" due to the URL change, but it's not the end of the world.
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

extension ImageCollectionItemView where Content == Image {
  init(image: ImageCollectionItem) {
    self.init(image: image) { img in
      img.resizable()
    }
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
  @Environment(\.selection) @Binding private var selection
  @FocusedValue(\.detailScroller) private var detailScroller
  @Binding var columns: NavigationSplitViewVisibility

  var body: some View {
    ScrollViewReader { proxy in
      ImageCollectionSidebarView(scrollDetail: detailScroller?.scroll ?? noop)
        .focusedSceneValue(\.sidebarScroller, .init(selection: selection) {
          // The only place we're calling this is in ImageCollectionDetailItemView with a single item.
          let id = selection.first!

          // https://stackoverflow.com/a/72808733/14695788
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

  @Environment(\.collection) private var collection
  @Environment(\.fullScreen) private var fullScreen
  @SceneStorage("sidebar") private var columns = NavigationSplitViewVisibility.all
  @State private var selection = Selection()

  var body: some View {
    NavigationSplitView(columnVisibility: $columns) {
      ImageCollectionNavigationSidebarView(columns: $columns)
        .navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ImageCollectionNavigationDetailView(images: collection.images)
    }
    .toolbar(fullScreen == true ? .hidden : .automatic)
    .task {
      collection.wrappedValue.bookmarks = await collection.wrappedValue.load()
      collection.wrappedValue.updateImages()
      collection.wrappedValue.updateBookmarks()
    }.environment(\.selection, $selection)
  }
}

#Preview {
  ImageCollectionView()
}
