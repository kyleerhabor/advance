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

  // I don't know if I really need ot do anything here.
  static func reduce(value: inout Self.Value, nextValue: () -> Self.Value) {}
}

struct SequenceImagePhaseView: View {
  @State private var elapsed = false

  let phase: AsyncImagePhase

  var body: some View {
    if let image = phase.image {
      image.resizable()
    } else {
      Color(nsColor: .tertiarySystemFill)
        .overlay {
          if case .failure(let err) = phase {
            Image(systemName: errorSymbol(for: err as! ImageError))
              .symbolRenderingMode(.multicolor)
              .resizable()
              .frame(maxWidth: 32, maxHeight: 32)
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
      case .lost: "questionmark.circle.fill"
    }
  }
}

struct SequenceImageCellView: View {
  typealias Subject = CurrentValueSubject<CGSize, Never>

  @State private var phase = AsyncImagePhase.empty
  private let sizeSubject: Subject
  private let sizePublisher: AnyPublisher<CGSize, Never>

  let url: URL
  @State private var size: CGSize?

  var body: some View {
    GeometryReader { proxy in
      SequenceImagePhaseView(phase: phase)
        .onChange(of: proxy.size, initial: true) {
          sizeSubject.send(proxy.size)
        }.onReceive(sizePublisher) { size in
          self.size = size
        }
        // We want the task to be bound to the view's lifetime.
        .task(id: size) {
          guard let size else {
            return
          }

          guard let image = await resizeImage(at: url, toSize: size) else {
            var fileUrl = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            fileUrl.scheme = nil

            phase = .failure(
              FileManager.default.fileExists(atPath: fileUrl.string!.removingPercentEncoding!)
                ? ImageError.undecodable
                : ImageError.lost
            )

            return
          }

          // Only animate when transitioning from empty to successful.
          if case .empty = phase {
            withAnimation {
              phase = .success(image)
            }
          } else {
            phase = .success(image)
          }
        }
    }
  }

  init(url: URL) {
    self.url = url

    let subject = Subject(.init())

    self.sizeSubject = subject
    self.sizePublisher = subject
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .removeDuplicates { $0.height == $1.height }
      .eraseToAnyPublisher()
  }
}

struct SequenceImageView: View {
  let image: SequenceImage

  var body: some View {
    let url = image.url

    SequenceImageCellView(url: url)
      .id(url)
      .aspectRatio(image.width / image.height, contentMode: .fit)
      .onAppear {
        if !url.startAccessingSecurityScopedResource() {
          Logger.ui.error("Could not access security scoped resource for \"\(url, privacy: .sensitive)\"")
        }
      }.onDisappear {
        url.stopAccessingSecurityScopedResource()
      }
  }
}

struct SequenceItemView: View {
  let image: SequenceImage
  let margins: Double

  var body: some View {
    let url = image.url

    // TODO: Implement Live Text.
    //
    // I tried this before, but it came out poorly since I was using an NSImageView.
    SequenceImageView(image: image)
      .navigationTitle(url.deletingPathExtension().lastPathComponent)
      .navigationDocument(url)
      .padding(margins * 6)
      .shadow(radius: CGFloat(margins))
      .contextMenu {
        Button("Show in Finder") {
          openFinder(for: url)
        }
      }
  }
}

struct SequenceSidebarView: View {
  @State private var preview = [URL]()
  @State private var previewItem: URL?

  let images: [SequenceImage]
  @Binding var selection: Set<URL>
  let onMove: (IndexSet, Int) -> Void

  var body: some View {
    // There's an uncomfortable amount of padding missing from the top when in full screen mode.
    //
    // TODO: Support drag and drop, removal, and additions.
    List(selection: $selection) {
      ForEach(images, id: \.url) { image in
        VStack {
          SequenceImageView(image: image)
          
          let path = image.url.lastPathComponent
          
          Text(path)
            .font(.subheadline)
            .padding(.init(top: 4, leading: 8, bottom: 4, trailing: 8))
            .background(Color(nsColor: .secondarySystemFill))
            .clipShape(.rect(cornerRadius: 4, style: .continuous))
            .help(path)
        }
      }.onMove(perform: onMove)
    }
    .quickLookPreview($previewItem, in: preview)
    .contextMenu { urls in
      Button("Show in Finder") {
        openFinder(for: Array(urls))
      }

      // TODO: Figure out how to bind this to the space key while the context menu is not open.
      //
      // I tried using .onKeyPress(_:action:) on the list, but the action was never called. Maybe related to 109799056?
      // "View.onKeyPress(_:action:) can't filter key presses when bridged controls have focus."
      Button("Quick Look") {
        quicklook(urls: urls)
      }
    } primaryAction: { urls in
      openFinder(for: Array(urls))
    }
  }

  func quicklook(urls: Set<URL>) {
    let images = images
      .enumerated()
      .reduce(into: [:]) { partialResult, pair in
        partialResult[pair.1.url] = pair.0
      }

    preview = urls.sorted { a, b in
      guard let ai = images[a] else {
        return false
      }

      guard let bi = images[b] else {
        return true
      }

      return ai < bi
    }

    previewItem = preview.first
  }
}

struct SequenceView: View {
  @Environment(\.window) private var window
  @AppStorage(StorageKeys.fullWindow.rawValue) private var allowsFullWindow = false
  @AppStorage(StorageKeys.margin.rawValue) private var margins = 0
  @SceneStorage(StorageKeys.sidebar.rawValue) private var columns = NavigationSplitViewVisibility.detailOnly
  @State private var selection = Set<URL>()
  @State private var didFirstScroll = false
  @State private var item: URL?

  @Binding var sequence: Sequence

  var body: some View {
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
      // Extracted to prevent the compiler from hanging.
      SequenceSidebarView(images: sequence.images, selection: $selection) { source, destination in
        sequence.move(from: source, to: destination)
      }.navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ScrollViewReader { scroller in
        // TODO: Figure out how to support .scrollPosition (or something like it)
        List(sequence.images, id: \.url) { image in
          SequenceItemView(image: image, margins: Double(margins))
            // Normally, NSTableView's style can just be set to .plain, which will take up the full size of the
            // container. List, for some reason, doesn't want to do that, so I have to do this arbitrary dance.
            .listRowInsets(.init(top: 0, leading: -8, bottom: 0, trailing: -9))
            .listRowSeparator(.hidden)
        }.listStyle(.plain)
//        ScrollView {
//          LazyVStack(spacing: 0) {
//            ForEach(sequence.images, id: \.url) { image in
//              // Extracted to prevent the compiler from hanging.
//              SequenceItemView(image: image)
//            }.introspect(.scrollView, on: .macOS(.v14), scope: .ancestor) { scrollView in
//              scrollView.allowsMagnification = true
//              // I tried constraining the scroll view's center X anchor to its first subview, but that resulted in the view
//              // being blank. For now, we'll deal with this.
//              scrollView.minMagnification = 1
//            }
//          }
//          // I read somewhere that LazyVStack does not reuse cells, and it seems to be that LazyVStack cannot size very
//          // well vertically. This is what I believe results in scrolling feeling slower than a List implementation.
//          // The Layout protocol may be able to resolve this issue, but it's fairly complex, and I don't know how to
//          // fully use it yet. I would like to try it soon, however, since it's my longest-standing issue that would
//          // make the app Preview-replaceable.
//          .background {
//            if let window, coverFullWindow(for: window) {
//              // This seems to significantly hinder performance (though, I'm not sure if it's in updating the title bar
//              // visibility or publishing changes to the preference).
//              GeometryReader { proxy in
//                Color.clear
//                  .preference(key: ScrollPreferenceKey.self, value: proxy.frame(in: .scrollView).origin.y)
//              }
//            }
//          }
//        }
        .onChange(of: selection) { prior, selection in
          guard let url = selection.subtracting(prior).first else {
            return
          }

          withAnimation {
            scroller.scrollTo(url, anchor: .top)
          }
        }
      }.onPreferenceChange(ScrollPreferenceKey.self) { _ in
        guard didFirstScroll else {
          didFirstScroll = true

          return
        }

        guard let window, !window.isFullScreened() else {
          return
        }

        withAnimation {
          setTitleBarVisibility(for: window)
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
    .toolbar(.hidden)
    .task {
      sequence.images = await sequence.load()
    }
    // .onHover's action doesn't get called when "some other event" interrupts its focus streak (e.g. the user begins
    // hovering inside a view, then starts scrolling, and then goes back to hovering, in which the action isn't called).
    // .onContinuousHover does that, though it feels kind of wasteful for how often it's called. I just want to say
    // "when the user is hovering over this view and is not scrolling"
    .onContinuousHover(coordinateSpace: .global) { phase in
      // The title bar will constantly flicker from the hover position and view size (for determining scrolling)
      // constantly updating in tandem. Since only the hover state will be excluded, the user gets a really nice effect
      // where resizing reveals the full window and brings back the title bar when it ends.
      guard let window, !window.isFullScreened(), !window.inLiveResize else {
        return
      }

      withAnimation {
        setTitleBarVisibility(for: window, to: .visible)
      }
    }.onReceive(NotificationCenter.default.publisher(for: NSWindow.willEnterFullScreenNotification)) { notification in
      let window = notification.object as! NSWindow

      setTitleBarVisibility(for: window, to: .visible)
      window.animator().titlebarSeparatorStyle = .none
    }.onReceive(NotificationCenter.default.publisher(for: NSWindow.willExitFullScreenNotification)) { notification in
      let window = notification.object as! NSWindow

      window.animator().titlebarSeparatorStyle = .line
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
  SequenceView(sequence: .constant(.init(from: [])))
}
