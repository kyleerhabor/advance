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
          if case .failure = phase {
            Image(systemName: "exclamationmark.triangle.fill")
              .symbolRenderingMode(.multicolor)
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
}

// Should this work be moved to the model? Maybe it could improve performance...
func resizeImage(at url: URL, to size: CGSize) async -> Image? {
  let options: [CFString : Any] = [
    // We're not going to use kCGImageSourceShouldAllowFloat here since the sizes can get very precise.
    kCGImageSourceShouldCacheImmediately: true,
    // For some reason, resizing images with kCGImageSourceCreateThumbnailFromImageIfAbsent sometimes uses a
    // significantly smaller pixel size than specified with kCGImageSourceThumbnailMaxPixelSize. For example, I have a
    // copy of Mikuni Shimokaway's album "all the way" (https://musicbrainz.org/release/19a73c6d-8a11-4851-bb3b-632bcd6f1adc)
    // with scanned images. Even though the first image's size is 800x677 and I set the max pixel size to 802 (since
    // it's based on the view's size), it sometimes returns 160x135. This is made even worse by how the view refuses to
    // update to the next created image.
    kCGImageSourceCreateThumbnailFromImageAlways: true,
    kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
    kCGImageSourceCreateThumbnailWithTransform: true
  ]

  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
    return nil
  }

  Logger.ui.info("Created a resampled image from \"\(url)\" at dimensions \(image.width)x\(image.height) for size \(size.width) / \(size.height)")

  return Image(nsImage: .init(cgImage: image, size: size))
}

struct SequenceImageCellView: View {
  @State private var phase = AsyncImagePhase.empty
  private let sizeSubject: CurrentValueSubject<CGSize, Never>
  private let sizePublisher: AnyPublisher<CGSize, Never>

  let url: URL

  var body: some View {
    GeometryReader { proxy in
      SequenceImagePhaseView(phase: phase)
        .onChange(of: proxy.size, initial: true) {
          sizeSubject.send(proxy.size)
        }.onReceive(sizePublisher) { size in
          Task {
            guard let image = await resizeImage(at: url, to: size) else {
              phase = .failure(ImageError.undecodable)

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
  }

  init(url: URL) {
    self.url = url

    let subject = CurrentValueSubject<CGSize, Never>(.init())

    self.sizeSubject = subject
    self.sizePublisher = subject
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
      .aspectRatio(image.width / image.height, contentMode: .fit)
      .onAppear {
        if !url.startAccessingSecurityScopedResource() {
          Logger.ui.error("Could not access security scoped resource for \"\(url, privacy: .public)\"")
        }
      }.onDisappear {
        url.stopAccessingSecurityScopedResource()
      }
  }
}

struct SequenceItemView: View {
  @AppStorage(StorageKeys.margin.rawValue) private var margins = 0

  let image: SequenceImage

  var body: some View {
    let url = image.url

    // TODO: Implement Live Text.
    //
    // I tried this before, but it came out poorly since I was using an NSImageView.
    SequenceImageView(image: image)
      .navigationTitle(url.deletingPathExtension().lastPathComponent)
      .navigationDocument(url)
      .padding(Double(margins * 6))
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

  var body: some View {
    // There's an uncomfortable amount of padding missing from the top when in full screen mode. Is
    List(images, id: \.url, selection: $selection) { image in
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
    }
    .quickLookPreview($previewItem, in: preview)
    .contextMenu { urls in
      Button("Show in Finder") {
        openFinder(for: Array(urls))
      }

      // TODO: Figure out how to bind this to the space key while the context menu is not open.
      //
      // I tried using .onKeyPress(_:action:), but the action was never called. Maybe related to 109799056?
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

//struct PersistentLazyStackLayout: Layout {
//  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
//    <#code#>
//  }
//  
//  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
//    <#code#>
//  }
//}

struct SequenceView: View {
  @Environment(\.window) private var window
  @AppStorage(StorageKeys.fullWindow.rawValue) private var allowsFullWindow: Bool = false
  @State private var selection = Set<URL>()
  @State private var columns = NavigationSplitViewVisibility.detailOnly
  @State private var didFirstScroll = false
  let sequence: Sequence

  var body: some View {
    // FIXME: Scrolling through a lot of images feels slightly slow.
    //
    // This is compared to Preview, where slowdowns are only really perceived in PDFs when resizing. AsyncImage blocks
    // when loading the view, which is where this perceived slowness comes from. Is there a way to asynchronously
    // render the image? (which would allow for a proper animation).
    //
    // TODO: On scene restoration, scroll to the last image the user viewed.
    //
    // ScrollView supports scrolling to a specific view, but makes scrolling to its *exact* position possible through
    // anchors. It would require measuring the sizes of the views preceding it, which I imagine could either be done
    // via `images`/the data model.
    NavigationSplitView(columnVisibility: $columns) {
      // Extracted to prevent the compiler from hanging.
      SequenceSidebarView(images: sequence.images, selection: $selection)
        .navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ScrollViewReader { proxy in
        // FIXME: Full screening a window messes up the position.
        //
        // FIXME: Scrolling sometimes jumps.
        //
        // I would really like to use a List here, since it has a very nice layout mechanism that makes scrolling feel
        // smooth, but it has a behavior where it slightly "scrolls to place" when a user with a trackpad releases,
        // which looks jarring. Under the hood, List is an NSTableView, but I don't see a property which disables said
        // behavior.
        ScrollView {
          // I read somewhere that LazyVStack does not reuse cells, and it seems to be that LazyVStack cannot size very
          // well in both directions (even though we arguably know both of them). This is what I believe results in
          // scrolling feeling slower than a List implementation. The Layout protocol may be able to resolve this issue,
          // but it's fairly complex, and I don't know how to fully use it yet. I would like to try it soon, however,
          // since it's my longest-standing issue that would make the app Preview-replaceable.
          LazyVStack(spacing: 0) {
            ForEach(sequence.images, id: \.url) { image in
              // Extracted to prevent the compiler from hanging.
              SequenceItemView(image: image)
            }.introspect(.scrollView, on: .macOS(.v14), scope: .ancestor) { scrollView in
              scrollView.allowsMagnification = true
              // I tried constraining the scroll view's center X anchor to its first subview, but that resulted in the view
              // being blank. For now, we'll deal with this.
              scrollView.minMagnification = 1
            }
          }.background {
            if let window, coverFullWindow(for: window) {
              // This seems to significantly hinder performance (though, I'm not sure if it's in updating the title bar
              // visibility or publishing changes to the preference).
              GeometryReader { proxy in
                Color.clear
                  .preference(key: ScrollPreferenceKey.self, value: proxy.frame(in: .scrollView).origin.y)
              }
            }
          }
        }.onChange(of: selection) { prior, selection in
          guard let url = selection.subtracting(prior).first else {
            return
          }

          withAnimation {
            proxy.scrollTo(url, anchor: .top)
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
    .onAppear {
      sequence.load()
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
  SequenceView(sequence: .init(from: []))
}
