//
//  SequenceView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import Combine
import ImageIO
import OSLog
import QuickLook
import SwiftUI
import SwiftUIIntrospect

struct ScrollPreferenceKey: PreferenceKey {
  static var defaultValue = CGFloat.zero

  static func reduce(value: inout Self.Value, nextValue: () -> Self.Value) {}
}

struct SequenceImagePhaseView: View {
  @State private var elapsed = false

  let phase: AsyncImagePhase

  var body: some View {
    if let image = phase.image {
      image.resizable()
    } else {
      Color.tertiaryFill
        .overlay {
          if case .failure(let err) = phase {
            Image(systemName: errorSymbol(for: err as! ImageError))
              .symbolRenderingMode(.multicolor)
              .imageScale(.large)
          } else if elapsed {
            ProgressView()
          }
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

  func errorSymbol(for error: ImageError) -> String {
    switch error {
      case .undecodable: "exclamationmark.triangle.fill"
      case .lost: "questionmark.circle"
    }
  }
}

struct SequenceImageCellView: View {
  typealias Subject = CurrentValueSubject<CGSize, Never>

  @Environment(\.pixelLength) private var pixel
  @State private var phase = AsyncImagePhase.empty
  @State private var size = CGSize()
  private var sizeSubject: Subject
  private var sizePublisher: AnyPublisher<CGSize, Never>

  let url: URL

  var body: some View {
    GeometryReader { proxy in
      SequenceImagePhaseView(phase: phase)
        .onChange(of: proxy.size, initial: true) {
          sizeSubject.send(proxy.size)
        }.onReceive(sizePublisher) { size in
          self.size = size
        }.task(id: size) {
          // FIXME: This is a hack to prevent seeing the "failed to load" icon.
          //
          // For some reason, the initial call gets a frame size of zero, and then immediately updates with the proper
          // value. This isn't caused by the default state value of `size` being zero, however. This task is, straight
          // up, just called when there is presumably no frame to present the view.
          guard size != .zero else {
            return
          }

          // For some reason, SwiftUI may choose to block when rendering the image that is scrolled into view. A lot of
          // the time it won't, but it can sometimes. This doesn't seem to necessarily be correlated with size, given
          // that a smaller image I tested with caused the block (and not the larger one). Maybe profile in Instruments
          // later?
          let size = CGSize(
            width: size.width / pixel,
            height: size.height / pixel
          )

          guard let image = await resampleImage(at: url, forSize: size) else {
            if let path = url.fileRepresentation(),
               !FileManager.default.fileExists(atPath: path) {
              phase = .failure(ImageError.lost)
            } else {
              phase = .failure(ImageError.undecodable)
            }

            return
          }

          // Only animate when transitioning from non-successful to successful.
          if case .success = phase {
            phase = .success(image)
          } else {
            withAnimation {
              phase = .success(image)
            }
          }
        }
    }
  }

  init(url: URL) {
    self.url = url

    let size = Subject(.init())

    self.sizeSubject = size
    self.sizePublisher = size
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
}

struct SequenceImageView: View {
  let image: SequenceImage

  var body: some View {
    let url = image.url

    SequenceImageCellView(url: url)
      .id(url)
      .aspectRatio(image.aspectRatio, contentMode: .fit)
      .onAppear {
        if !url.startAccessingSecurityScopedResource() {
          Logger.ui.error("Could not access security scoped resource for \"\(url, privacy: .sensitive)\"")
        }
      }.onDisappear {
        url.stopAccessingSecurityScopedResource()
      }
  }
}

struct SequenceView: View {
  @Environment(\.fullScreen) private var fullScreen
  @Environment(\.window) private var window
  @AppStorage(StorageKeys.fullWindow.rawValue) private var allowsFullWindow = false
  @SceneStorage(StorageKeys.sidebar.rawValue) private var columns = NavigationSplitViewVisibility.detailOnly
  @State private var selection = Set<URL>()
  @State private var visible = [URL]()
  @State private var didFirstScroll = false

  @Bindable var sequence: Sequence

  var body: some View {
    let page = visible.last

    // TODO: On scene restoration, scroll to the last image the user viewed.
    //
    // ScrollView supports scrolling to a specific view, but makes scrolling to its *exact* position possible through
    // anchors. It would require measuring the sizes of the views preceding it, which I imagine could either be done
    // via `images`/the data model.
    //
    // TODO: Implement Touch Bar support.
    //
    // Personally, I think the Touch Bar's most useful feature is it's scrubbing capability (and *not* the buttons).
    // I imagine displaying the images in a line akin to QuickTime Player / IINA's time scrubbing, but it would not
    // have to be fixed to a certain amount of items.
    NavigationSplitView(columnVisibility: $columns) {
      ScrollViewReader { scroller in
        SequenceSidebarView(selection: $selection, images: sequence.images) { source, destination in
          sequence.move(from: source, to: destination)
        } onDrop: { urls, offset in
          sequence.insert(urls, at: offset)
        } onDelete: {
          sequence.delete(selection)
        }.onChange(of: page) {
          // Scrolling off-screen allows the user to not think about the sidebar.
          guard let page, columns == .detailOnly else {
            return
          }

          scroller.scrollTo(page, anchor: .center)
        }
      }.navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ScrollViewReader { scroller in
        SequenceCollectionView(visible: $visible, images: sequence.images)
          .onChange(of: selection) { prior, selection in
            guard let url = selection.subtracting(prior).first else {
              return
            }

            withAnimation {
              scroller.scrollTo(url, anchor: .top)
            }
          }
      }
      // An annoying effect from ignoring the safe area is that the scrolling indicator may be under the title bar.
      .ignoresSafeArea(window != nil && coverFullWindow(for: window!) ? .all : [])
    }
    // If the app is launched with a window already full screened, the toolbar bar is properly hidden (still accessible
    // by bringing the mouse to the top). If the app is full screened manually, however, the title bar remains visible,
    // which ruins the purpose of full screen mode. Until I find a fix, the toolbar is explicitly disabled. Users can
    // still pull up the sidebar by hovering their mouse near (but not exactly at) the leading edge, but not all users
    // may know this.
    .toolbar(fullScreen == true ? .hidden : .automatic)
    .task {
      await sequence.load()
    }.onChange(of: fullScreen) {
      guard let fullScreen,
            let window else {
        return
      }

      if fullScreen {
        setTitleBarVisibility(for: window, to: .visible)

        window.animator().titlebarSeparatorStyle = .none
      } else {
        window.animator().titlebarSeparatorStyle = .automatic
      }
    }
  }

  func coverFullWindow(for window: NSWindow) -> Bool {
    allowsFullWindow && !window.isFullScreened() && columns == .detailOnly
  }

  func setTitleBarVisibility(for window: NSWindow) {
    setTitleBarVisibility(for: window, to: coverFullWindow(for: window) ? .hidden : .visible)
  }

  func setTitleBarVisibility(for window: NSWindow, to visibility: Visibility) {
    let isVisible = visibility == .automatic || visibility == .visible

    window.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = isVisible ? 1 : 0
  }
}

#Preview {
  SequenceView(sequence: .init(bookmarks: []))
}
