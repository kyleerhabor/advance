//
//  ImageCollectionDetailView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/13/23.
//

import Defaults
import ImageIO
import OSLog
import SwiftUI
import VisionKit

struct VisibleItem<Item> {
  let item: Item
  let anchor: Anchor<CGRect>
}

extension VisibleItem: Equatable where Item: Equatable {}

// https://swiftwithmajid.com/2020/03/18/anchor-preferences-in-swiftui/
struct VisiblePreferenceKey<Item>: PreferenceKey {
  typealias Value = [VisibleItem<Item>]

  static var defaultValue: Value { .init(minimumCapacity: 8) }

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value.append(contentsOf: nextValue())
  }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
  typealias Value = Anchor<CGRect>?

  static var defaultValue: Value = nil

  static func reduce(value: inout Value, nextValue: () -> Value) {
    guard let next = nextValue() else {
      return
    }

    value = next
  }
}

struct ImageCollectionDetailItemBookmarkView: View {
  @Environment(ImageCollection.self) private var collection
  @Environment(\.id) private var id

  @Binding var bookmarked: Bool
  var bookmark: Binding<Bool> {
    .init {
      bookmarked
    } set: { bookmarked in
      self.bookmarked = bookmarked

      collection.updateBookmarks()

      Task(priority: .medium) {
        do {
          try await collection.persist(id: id)
        } catch {
          Logger.model.error("Could not persist image collection \"\(id)\" (via detail bookmark): \(error)")
        }
      }
    }
  }

  var body: some View {
    ImageCollectionBookmarkView(bookmarked: bookmark)
  }
}

struct ImageCollectionDetailItemSidebarView: View {
  @Environment(\.selection) @Binding private var selection

  let id: ImageCollectionItemImage.ID
  let scroll: Scroller.Scroll

  var body: some View {
    Button("Show in Sidebar") {
      selection = [id]

      scroll(selection)
    }
  }
}

struct ImageCollectionDetailItemView: View {
  @Default(.liveText) private var liveText
  @Default(.liveTextSearchWith) private var liveTextSearchWith
  @Default(.liveTextDownsample) private var liveTextDownsample
  @Default(.resolveCopyingConflicts) private var resolveConflicts
  @State private var isPresentingCopyingFileImporter = false
  @State private var error: String?
  var isPresentingErrorAlert: Binding<Bool> {
    .init {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }
  }

  @Bindable var image: ImageCollectionItemImage
  var liveTextIcon: Bool
  let scrollSidebar: Scroller.Scroll
  var liveTextInteractions: ImageAnalysisOverlayView.InteractionTypes {
    liveText ? .automaticTextOnly : []
  }

  var body: some View {
    let url = image.url

    // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
    VStack {
      ImageCollectionItemView(image: image) { phase in
        if let resample = phase.resample {
          let interactions = liveTextInteractions

          LiveTextView(
            interactions: interactions,
            analysis: image.analysis,
            highlight: $image.highlighted
          )
          .supplementaryInterfaceHidden(!liveTextIcon)
          .searchEngineHidden(!liveTextSearchWith)
          .task(id: image.url) {
            let interactions = liveTextInteractions

            if image.analysis != nil {
              return
            }

            let analysis = await image.scoped {
              await analyze(
                url: image.url,
                orientation: image.properties.orientation,
                interactions: interactions,
                resample: liveTextDownsample,
                resampleTo: Int(resample.size.length.rounded(.up))
              )
            }

            if let analysis {
              image.analysis = analysis
            }
          }
        }
      }
      .anchorPreference(key: VisiblePreferenceKey.self, value: .bounds) { [.init(item: image, anchor: $0)] }
      .anchorPreference(key: ScrollOffsetPreferenceKey.self, value: .bounds) { $0 }
    }
    // I don't know if this actually does anything, but I want the view to always fade in with an opacity. Currently,
    // it will *sometimes* use a scale.
    //
    // I don't think it does anything (at least, here).
    .transition(.opacity)
    .contextMenu {
      Section {
        Button("Show in Finder") {
          openFinder(selecting: url)
        }

        ImageCollectionDetailItemSidebarView(id: image.id, scroll: scrollSidebar)
      }

      Section {
        Button("Copy", systemImage: "doc.on.doc") {
          if !NSPasteboard.general.write(items: [url as NSURL]) {
            Logger.ui.error("Failed to write URL \"\(url.string)\" to pasteboard")
          }
        }

        ImageCollectionCopyingView(isPresented: $isPresentingCopyingFileImporter, error: $error) { destination in
          Task(priority: .medium) {
            do {
              try await save(image: image, to: destination)
            } catch {
              self.error = error.localizedDescription
            }
          }
        }
      }

      Section {
        ImageCollectionDetailItemBookmarkView(bookmarked: $image.bookmarked)
      }
    }.fileImporter(isPresented: $isPresentingCopyingFileImporter, allowedContentTypes: [.folder]) { result in
      switch result {
        case .success(let url):
          Task(priority: .medium) {
            do {
              try await save(image: image, to: url)
            } catch {
              self.error = error.localizedDescription
            }
          }
        case .failure(let err):
          Logger.ui.info("Could not import copy destination from file picker: \(err)")
      }
    }
    .fileDialogCopy()
    .alert(error ?? "", isPresented: isPresentingErrorAlert) {}
  }

  func save(image: ImageCollectionItemImage, to destination: URL) async throws {
    try ImageCollectionCopyingView.saving {
      try destination.scoped {
        try ImageCollectionCopyingView.saving(url: image, to: destination) { url in
          try image.scoped {
            try ImageCollectionCopyingView.save(url: url, to: destination, resolvingConflicts: resolveConflicts)
          }
        }
      }
    }
  }

  func analyze(
    url: URL,
    orientation: CGImagePropertyOrientation,
    interactions: ImageAnalysisOverlayView.InteractionTypes,
    resample: Bool,
    resampleTo resampleSize: Int
  ) async -> ImageAnalysis? {
    let analyzer = ImageAnalyzer()
    let maxSize = ImageAnalyzer.maxSize
    let configuration = ImageAnalyzer.Configuration(.init(interactions))

    do {
      return try await analyze(analyzer: analyzer, imageAt: url, orientation: orientation, configuration: configuration)
    } catch let err as NSError where err.domain == ImageAnalyzer.errorDomain && err.code == ImageAnalyzer.errorCodeMaxSize {
      guard resample else {
        Logger.ui.error("Could not analyze image at URL \"\(url.string)\" as its size is too large: \(err)")

        return nil
      }

      let size = min(resampleSize, maxSize - 1)

      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let type = CGImageSourceGetType(source),
            let image = source.resample(to: size) else {
        return nil
      }

      let directory = URL.temporaryLiveTextImagesDirectory
      let url = directory.appending(component: UUID().uuidString)
      let count = 1
      let destination: CGImageDestination

      do {
        let manager = FileManager.default
        let dest: CGImageDestination? = try manager.creatingDirectories(at: directory, code: .fileNoSuchFile) {
          guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, count, nil) else {
            if manager.fileExists(atPath: url.string) {
              return nil
            }

            throw CocoaError(.fileNoSuchFile)
          }

          return destination
        }

        guard let dest else {
          return nil
        }

        destination = dest
      } catch {
        Logger.ui.error("Could not create destination for image analyzer replacement image: \(error)")

        return nil
      }

      CGImageDestinationAddImage(destination, image, nil)

      guard CGImageDestinationFinalize(destination) else {
        Logger.ui.error("Could not finalize destination for image analyzer replacement image")

        return nil
      }

      do {
        return try await analyze(analyzer: analyzer, imageAt: url, orientation: orientation, configuration: configuration)
      } catch {
        Logger.ui.error("Could not analyze image at URL \"\(url.string)\": \(error)")

        return nil
      }
    } catch {
      Logger.ui.error("Could not analyze image at URL \"\(url.string)\": \(error)")

      return nil
    }
  }

  // For reference, I know VisionKit logs the analysis time in Console; this is just useful for always displaying the
  // time in *our own logs*.
  func analyze(
    analyzer: ImageAnalyzer,
    imageAt url: URL,
    orientation: CGImagePropertyOrientation,
    configuration: ImageAnalyzer.Configuration
  ) async throws -> ImageAnalysis {
    let exec = try await time {
      try await analyzer.analyze(imageAt: url, orientation: orientation, configuration: configuration)
    }

    Logger.ui.info("Took \(exec.duration) to analyze image at URL \"\(url.string)\"")

    return exec.value
  }
}

struct ImageCollectionDetailVisualView: View {
  @AppStorage(Keys.brightness.key) private var brightness = Keys.brightness.value
  @AppStorage(Keys.grayscale.key) private var grayscale = Keys.grayscale.value

  var body: some View {
    // FIXME: Using .focusable on ResetButtonView allows users to select but not perform action.
    //
    // Using .focusable allows me to tab to the button, but not hit Space to perform the action. Sometimes, however,
    // I'll need to tab back once and hit Space for it to function.
    Form {
      HStack(alignment: .firstTextBaseline) {
        LabeledContent {
          Slider(value: $brightness, in: -0.5...0.5, step: 0.1) {
            // Empty
          } minimumValueLabel: {
            Text("50%")
              .fontDesign(.monospaced)
          } maximumValueLabel: {
            Text("150%")
              .fontDesign(.monospaced)
          }.frame(width: 250)
        } label: {
          Text("Brightness:")
        }

        ResetButtonView {
          brightness = Keys.brightness.value
        }.disabled(brightness == Keys.brightness.value)
      }

      HStack(alignment: .firstTextBaseline) {
        LabeledContent {
          Slider(value: $grayscale, in: 0...1, step: 0.1) {
            // Empty
          } minimumValueLabel: {
            // I can't figure out how to align the labels.
            Text(" 0%")
              .fontDesign(.monospaced)
          } maximumValueLabel: {
            Text("100%")
              .fontDesign(.monospaced)
          }.frame(width: 250)
        } label: {
          Text("Grayscale:")
        }

        ResetButtonView {
          grayscale = Keys.grayscale.value
        }.disabled(grayscale == Keys.grayscale.value)
      }
    }
    .formStyle(SettingsFormStyle())
    .padding()
    .frame(width: 384)
  }
}

struct ImageCollectionDetailVisibilityViewModifier: ViewModifier {
  typealias Scroll = SidebarScrollerFocusedValueKey.Value.Scroll

  @Environment(\.selection) @Binding private var selection
  @Default(.displayTitleBarImage) private var displayTitleBarImage
  @State private var images = [ImageCollectionItemImage]()

  let scrollSidebar: Scroll

  func body(content: Content) -> some View {
    content
      .backgroundPreferenceValue(VisiblePreferenceKey<ImageCollectionItemImage>.self) { items in
        GeometryReader { proxy in
          let local = proxy.frame(in: .local)
          let images = items
            .filter { local.intersects(proxy[$0.anchor]) }
            .map(\.item)

          Color.clear.onChange(of: images) {
            // The reason we're factoring the view into an overlay is because this view will be called on *every scroll*
            // the user performs. While most modifiers are cheap, not all are—one being navigationDocument(_:). Just
            // with this, CPU usage decreases from 60-68% to 47-52%, which is a major performance improvement. For
            // reference, before the anchor preferences implementation, CPU usage was often around 42-48%.
            self.images = images
          }
        }
      }.overlay {
        // Does Toggle have better accessibility?
        Button("Live Text Highlight", systemImage: "dot.viewfinder") {
          let highlight = !images.allSatisfy(\.highlighted)

          images.forEach(setter(keyPath: \.highlighted, value: highlight))
        }
        .disabled(images.isEmpty)
        .hidden()
        .keyboardShortcut(.liveTextHighlight)

        if let primary = images.first {
          if displayTitleBarImage {
            let url = primary.url

            Color.clear
              .navigationTitle(Text(url.deletingPathExtension().lastPathComponent))
              .navigationDocument(url)
          }

          Color.clear
            .focusedSceneValue(\.openFinder, .init(enabled: true, menu: .init(identity: [primary.id]) {
              openFinder(selecting: primary.url)
            })).focusedSceneValue(\.jumpToCurrentImage, .init(identity: primary.id) {
              selection = [primary.id]

              scrollSidebar(selection)
            })
        }
      }
  }
}

extension View {
  func visibleImage(scrollSidebar: @escaping ImageCollectionDetailVisibilityViewModifier.Scroll) -> some View {
    self.modifier(ImageCollectionDetailVisibilityViewModifier(scrollSidebar: scrollSidebar))
  }
}

struct ImageCollectionDetailView: View {
  @Environment(\.selection) @Binding private var selection
  @Default(.margins) private var margins
  @Default(.collapseMargins) private var collapseMargins
  @Default(.liveText) private var liveText
  @Default(.liveTextIcon) private var appLiveTextIcon
  @Default(.displayTitleBarImage) private var showTitleBarImage
  @SceneStorage(Defaults.Keys.liveTextIcon.name) private var liveTextIcon: Bool?
  @State private var currentImage: ImageCollectionItemImage?

  let images: [ImageCollectionDetailImage]
  let scrollSidebar: Scroller.Scroll
  var icon: Bool {
    liveTextIcon ?? appLiveTextIcon
  }

  var body: some View {
    let margin = Double(margins)
    let half = margin * 3
    let full = half * 2
    let all = EdgeInsets(full)
    let top = EdgeInsets(horizontal: full, top: full, bottom: half)
    let middle = EdgeInsets(horizontal: full, top: half, bottom: half)
    let bottom = EdgeInsets(horizontal: full, top: half, bottom: full)

    List(images) { image in
      let insets: EdgeInsets = if let edge = image.edge {
        switch edge {
          case .top: top
          case .bottom: bottom
        }
      } else {
        middle
      }

      ImageCollectionDetailItemView(
        image: image.image,
        liveTextIcon: icon,
        scrollSidebar: scrollSidebar
      )
      .shadow(radius: margin / 2)
      .listRowInsets(.listRow + (collapseMargins ? insets : all))
      .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .toolbar(id: "Canvas") {
      ToolbarItem(id: "Visual") {
        PopoverButtonView(edge: .bottom) {
          ImageCollectionDetailVisualView()
        } label: {
          Label("Visual Effects", systemImage: "paintbrush.pointed")
        }.help("Visual Effects")
      }

      ToolbarItem(id: "Live Text Icon") {
        let icons = Binding {
          icon
        } set: {
          liveTextIcon = $0
        }

        Toggle("Live Text Icon", systemImage: "text.viewfinder", isOn: icons)
          .keyboardShortcut(.liveTextIcon)
          .help("\(icon ? "Hide" : "Show") Live Text icon")
      }
    }.visibleImage(scrollSidebar: scrollSidebar)
  }
}
