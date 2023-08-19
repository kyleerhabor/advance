//
//  SequenceView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import OSLog
import SwiftUI

struct SequenceImagePhaseView<Content>: View where Content: View {
  @State private var elapsed = false

  @Binding var phase: AsyncImagePhase
  @ViewBuilder var content: (Image) -> Content

  var body: some View {
    Color.tertiaryFill
      .overlay {
        switch phase {
          case .success(let image):
            content(image)
          case .failure(let err):
            if !(err is CancellationError) {
              Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.multicolor)
                .imageScale(.large)
            }
          default:
            ProgressView().opacity(elapsed ? 1 : 0)
        }
      }.task {
        guard (try? await Task.sleep(for: .seconds(1))) != nil else {
          return
        }

        withAnimation {
          elapsed = true
        }
      }.onDisappear {
        // This is necessary to slow down the memory creep SwiftUI creates when rendering images. It does not
        // eliminate it, but severely halts it. As an example, I have a copy of the first volume of Mysterious
        // Girlfriend X, which weights in at ~700 MBs. When the window size is the default and the sidebar is
        // open but hasn't been scrolled through, by time I reach page 24, the memory has ballooned to ~600 MBs.
        // With this little trick, however, it rests at about ~150-200 MBs. Note that I haven't profiled the app
        // to see if the remaining memory comes from SwiftUI or Image I/O.
        //
        // I'd like to change this so one or more images are preloaded before they come into view and disappear
        // as such.
        phase = .empty
      }
  }
}

struct SequenceImageView<Content>: View where Content: View {
  @State private var phase = AsyncImagePhase.empty

  let image: SeqImage
  @ViewBuilder var content: (Image) -> Content

  var body: some View {
    let url = image.url

    DisplayImageView(url: url, phase: $phase, transaction: .init(animation: .default)) {
      SequenceImagePhaseView(phase: $phase, content: content)
    }
    .id(image.id)
    .aspectRatio(image.ratio, contentMode: .fit)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onAppear {
      if !url.startAccessingSecurityScopedResource() {
        Logger.ui.error("Could not access security scoped resource for \"\(url)\"")
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
  @State private var selection = Set<SeqImage.ID>()

  @Binding var sequence: Seq

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
    //
    // TODO: Display the current page in the title.
    //
    // This used to be a feature, but I removed it since it was based on .onAppear/.onDisappear, which was unreliable.
    // It can really only be implemented in a custom List implementation (e.g. NSCollectionView or NSTableView).
    //
    // TODO: Add a setting to fade the title bar while scrolling.
    //
    // This used to be a feature, but it was removed due to issues with capturing the scrolling position in List. The
    // implementation can't use .toolbar since it'd remove itself from the view hierarchy, messing with the scroll.
    // Note that the title bar should only be faded while the sidebar is not visible.
    NavigationSplitView(columnVisibility: $columns) {
      ScrollViewReader { scroller in
        SequenceSidebarView(sequence: sequence, selection: $selection)
      }.navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ScrollViewReader { scroller in
        SequenceDetailView(images: sequence.images)
          .onChange(of: selection) { prior, selection in
            guard let id = selection.subtracting(prior).first else {
              return
            }

            withAnimation {
              scroller.scrollTo(id, anchor: .top)
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
      sequence.bookmarks = await sequence.load()
      sequence.update()
    }.onChange(of: fullScreen) {
      guard let window,
            let fullScreen else {
        return
      }

      // With the toolbar visibility logic gone, would it potentially make more sense to extract this into a modifier?
      window.animator().titlebarSeparatorStyle = fullScreen ? .none : .automatic
    }
  }

  func selectionDescription() -> SequenceSelection {
    .init(
      enabled: columns == .all && !selection.isEmpty,
      resolve: { sequence.urls(from: selection) }
    )
  }
}
