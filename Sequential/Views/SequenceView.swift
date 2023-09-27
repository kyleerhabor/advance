//
//  SequenceView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/27/23.
//

import Combine
import OSLog
import SwiftUI

struct SeqInspectingEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(false)
}

struct SeqInspectionEnvironmentKey: EnvironmentKey {
  static var defaultValue = Binding.constant(SequenceView.Selection())
}

extension EnvironmentValues {
  var seqInspecting: SeqInspectingEnvironmentKey.Value {
    get { self[SeqInspectingEnvironmentKey.self] }
    set { self[SeqInspectingEnvironmentKey.self] = newValue }
  }

  var seqInspection: SeqInspectionEnvironmentKey.Value {
    get { self[SeqInspectionEnvironmentKey.self] }
    set { self[SeqInspectionEnvironmentKey.self] = newValue }
  }
}

struct SequenceImagePhaseView<Content>: View where Content: View {
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
      .overlay {
        if let image = phase.image {
          content(image)
        } else if case .failure = phase {
          // We can't really get away with not displaying a failure view.
          Image(systemName: "exclamationmark.triangle.fill")
            .symbolRenderingMode(.multicolor)
            .imageScale(.large)
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
        // eliminate it, but severely halts it. As an example, I have a copy of the first volume of Soloist in a Cage (~700 MBs).
        // When the window size is the default and the sidebar is open but hasn't been scrolled through, by time I
        // reach page 24, the memory has ballooned to ~600 MB. With this little trick, however, it rests at about ~150-200 MBs,
        // and is nearly eliminated by the window being closed. Note that the memory creep is mostly applicable to
        // regular memory and not so much real memory.
        //
        // In the future, I'd like to improve image loading so images are preloaded before they appear on screen (at
        // least one image beforehand).
        phase = .empty
      }
  }
}

struct SequenceImageView<Content>: View where Content: View {
  let image: SeqImage
  @ViewBuilder var content: (Image) -> Content

  var body: some View {
//    DisplayImageView(url: url, transaction: .init(animation: .default)) { $phase in
//      SequenceImagePhaseView(phase: $phase, content: content)
//    }
    Text("...")
    .id(image.id)
    .aspectRatio(image.size.aspectRatio, contentMode: .fit)
  }
}

extension SequenceImageView where Content == Image {
  init(image: SeqImage) {
    self.init(image: image) { image in
      image.resizable()
    }
  }
}

struct SequenceView: View {
  typealias Selection = Set<SeqImage.ID>

  @Environment(Window.self) private var win
  @Environment(\.fullScreen) private var fullScreen
  @SceneStorage("sidebar") private var columns: NavigationSplitViewVisibility?
  @State private var selection = Selection()
  @State private var inspecting = false
  @State private var inspection = Selection()
  var window: NSWindow? { win.window }

  @Binding var sequence: Seq

  var body: some View {
    let columns = Binding {
      self.columns ?? .all
    } set: { self.columns = $0 }

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
    NavigationSplitView(columnVisibility: columns) {
      ScrollViewReader { scroller in
        SequenceSidebarView(sequence: sequence, scrollDetail: noop)
      }.navigationSplitViewColumnWidth(min: 128, ideal: 192, max: 256)
    } detail: {
      ScrollViewReader { scroller in
        SequenceDetailView(images: sequence.images, scrollSidebar: noop)
      }
    }
//    .inspector(isPresented: $inspecting) {
//      let images = inspection.isEmpty
//        ? sequence.images
//        // If we really don't want to filter on the view body, we'd need to filter in the model whenever it changes
//        // (i.e. in update(_:)). I *really* want a property wrapper that updates when a data dependency does. In other
//        // words, I want the benefit of computed properties (no synchronization required) without the cost of unnecessary
//        // evaluation.
//        : sequence.images.filter(in: inspection, by: \.id)
//
//      VStack {
//        if !images.isEmpty {
//          SequenceInspectorView(images: images)
//        }
//      }
//      .inspectorColumnWidth(min: 200, ideal: 250, max: 300)
//      .toolbar {
//        Spacer()
//
//        Button("Toggle Inspector", systemImage: "info.circle") {
//          inspecting.toggle()
//        }
//      }
//    }
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
      window?.titlebarSeparatorStyle = fullScreen! ? .none : .automatic
    }
    .environment(\.seqInspecting, $inspecting)
    .environment(\.seqInspection, $inspection)
  }
}
