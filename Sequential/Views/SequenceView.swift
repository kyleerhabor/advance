//
//  SequenceView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import Combine
import OSLog
import QuickLook
import SwiftUI

struct SequenceImagePhaseErrorView: View {
  let error: Error

  var body: some View {
    if error is CancellationError {
      Color.clear
    } else {
      let noSuchFile = isNoSuchFileError()

      Image(systemName: noSuchFile ? "questionmark.diamond" : "exclamationmark.triangle.fill")
        .symbolRenderingMode(noSuchFile ? .hierarchical : .multicolor)
    }
  }

  func isNoSuchFileError() -> Bool {
    guard let err = error as? CocoaError else {
      return false
    }

    return err.code == .fileReadNoSuchFile
  }
}

struct SequenceImagePhaseView: View {
  @State private var elapsed = false

  @Binding var phase: AsyncImagePhase

  var body: some View {
    if let image = phase.image {
      image
        .resizable()
        .onDisappear {
          // This is necessary to slow down the memory creep SwiftUI creates when rendering images. It does not
          // eliminate it, but severely halts it. As an example, I have a copy of the first volume of Mysterious
          // Girlfriend X, which weights in at ~700 MBs. When the window size is the default and the sidebar is open
          // but hasn't been scrolled through, by time I reach page 24, the memory has ballooned to ~600 MBs. With this
          // little trick, however, it rests at about ~150-200 MBs. Note that I haven't profiled the app to see if the
          // remaining memory comes from SwiftUI or Image I/O.
          //
          // I'd like to change this so one or more images are preloaded before they come into view and disappear as such.
          phase = .empty
        }
    } else {
      Color.tertiaryFill
        .overlay {
          if case .failure(let err) = phase {
            SequenceImagePhaseErrorView(error: err)
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
}

struct SequenceImageCellView: View {
  typealias Subject = CurrentValueSubject<CGSize, Never>

  @Environment(\.pixelLength) private var pixel
  @State private var phase = AsyncImagePhase.empty
  @State private var size = CGSize()
  private var sizeSubject: Subject
  private var sizePublisher: AnyPublisher<CGSize, Never>

  let image: SeqImage

  var body: some View {
    GeometryReader { proxy in
      SequenceImagePhaseView(phase: $phase)
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
          
          let size = CGSize(
            width: size.width / pixel,
            height: size.height / pixel
          )
          
          do {
            guard let image = try await resampleImage(at: image.url, forSize: size) else {
              if let path = image.url.fileRepresentation(),
                 !FileManager.default.fileExists(atPath: path) {
                phase = .failure(CocoaError(.fileReadNoSuchFile))
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
          } catch {
            phase = .failure(error)
          }
        }
    }
  }

  init(image: SeqImage) {
    self.image = image

    let size = Subject(.init())

    self.sizeSubject = size
    self.sizePublisher = size
      .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
}

struct SequenceImageView: View {
  let image: SeqImage

  var body: some View {
    let url = image.url

    SequenceImageCellView(image: image)
      .id(url)
      .aspectRatio(image.width / image.height, contentMode: .fit)
      .frame(maxWidth: .infinity, maxHeight: .infinity) // I don't know if this actually has an effect.
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
  @SceneStorage(Keys.sidebar.key) private var columns = Keys.sidebar.value
  @State private var selection = Set<URL>()
  @State private var visible = [URL]()

  @Binding var sequence: Seq

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
        SequenceSidebarView(sequence: sequence, selection: $selection)
          // FIXME: This is often not called (maybe it needs to be right above the list?).
          .onChange(of: page) {
            // Scrolling off-screen allows the user to not think about the sidebar.
            guard let page, columns == .detailOnly else {
              return
            }

            scroller.scrollTo(page, anchor: .center)
          }
      }.navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ScrollViewReader { scroller in
        SequenceDetailView(visible: $visible, images: sequence.images)
          .onChange(of: selection) { prior, selection in
            guard let url = selection.subtracting(prior).first else {
              return
            }

            withAnimation {
              scroller.scrollTo(url, anchor: .top)
            }
          }
      }
      // Interestingly, attaching this to the outer NavigationSplitView causes SwiftUI to repeatedly re-render the
      // scene.
      .focusedSceneValue(\.sequenceSelection, selectionDescription())
    }
    // If the app is launched with a window already full screened, the toolbar bar is properly hidden (still accessible
    // by bringing the mouse to the top). If the app is full screened manually, however, the title bar remains visible,
    // which ruins the purpose of full screen mode. Until I find a fix, the toolbar is explicitly disabled. Users can
    // still pull up the sidebar by hovering their mouse near the leading edge of the screen or use Command-Control-S /
    // the menu bar, but not all users may know this.
    .toolbar(fullScreen == true ? .hidden : .automatic)
    .task {
      sequence.load()
    }.onChange(of: fullScreen) {
      guard let fullScreen,
            let window else {
        return
      }

      // With the toolbar visibility logic gone, would it potentially make more sense to extract this into a modifier?
      window.animator().titlebarSeparatorStyle = fullScreen ? .none : .automatic
    }
  }

  func selectionDescription() -> SequenceSelection {
    .init(
      enabled: columns == .all && !selection.isEmpty,
      resolve: { selection.ordered(by: sequence.images.map(\.url)) }
    )
  }
}
