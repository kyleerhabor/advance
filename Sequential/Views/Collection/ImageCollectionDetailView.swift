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
    ImageCollectionBookmarkView(showing: bookmark)
  }
}

struct ImageCollectionDetailItemSidebarView: View {
  @Environment(ImageCollectionSidebar.self) private var sidebar
  @Environment(ImageCollectionPath.self) private var path
  @Environment(\.sidebarScroller) private var sidebarScroller

  let id: ImageCollectionItemImage.ID

  var body: some View {
    Button("Show in Sidebar") {
      sidebarScroller.scroll(.init(id: id) {
        Task {
          sidebar.selection = [id]
          path.item = id
        }
      })
    }
  }
}

struct ImageCollectionDetailItemView: View {
  @Default(.liveText) private var liveText
  @Default(.liveTextSearchWith) private var liveTextSearchWith
  @Default(.liveTextDownsample) private var liveTextDownsample
  @Default(.resolveCopyingConflicts) private var resolveCopyingConflicts
  @State private var isCopyingFileImporterPresented = false
  @State private var error: String?
  private var liveTextInteractions: ImageAnalysisOverlayView.InteractionTypes {
    liveText ? .automaticTextOnly : .init()
  }
  private var isErrorPresented: Binding<Bool> {
    .init {
      self.error != nil
    } set: { present in
      if !present {
        self.error = nil
      }
    }
  }

  @Bindable var image: ImageCollectionItemImage
  let liveTextIcon: Bool

  var body: some View {
    let bookmarked = $image.bookmarked

    // For some reason, ImageCollectionItemView needs to be wrapped in a VStack for animations to apply.
    VStack {
      ImageCollectionItemView(image: image) { phase in
        ImageCollectionItemPhaseView(phase: phase)
          .aspectRatio(image.properties.sized.aspectRatio, contentMode: .fit)
          .overlay {
            var length: Int {
              phase.success.map { Int($0.size.length.rounded(.up)) } ?? 0
            }
            
            var factors: ImageCollectionItemImageAnalysis {
              .init(
                url: image.url,
                phase: .init(phase),
                downsample: liveTextDownsample && length != 0
              )
            }

            LiveTextView(
              interactions: liveTextInteractions,
              analysis: image.analysis,
              highlight: $image.highlighted
            )
            .supplementaryInterfaceHidden(!liveTextIcon)
            .searchEngineHidden(!liveTextSearchWith)
            .task(id: Pair(left: liveText, right: factors)) {
              guard liveText else {
                return
              }

              let factors = factors

              guard image.analysisFactors != factors && factors.phase == .success else {
                return
              }

              let analysis = await image.withSecurityScope {
                await analyze(
                  url: image.url,
                  orientation: image.properties.orientation,
                  interactions: liveTextInteractions,
                  resample: factors.downsample,
                  resampleSize: min(length, ImageAnalyzer.maxSize)
                )
              }

              if let analysis {
                image.analysis = analysis
                image.analysisHasResults = analysis.hasOutput
                image.analysisFactors = factors
              }
            }
          }
      }
      .anchorPreference(key: VisiblePreferenceKey.self, value: .bounds) { [.init(item: image, anchor: $0)] }
      .anchorPreference(key: ScrollOffsetPreferenceKey.self, value: .bounds) { $0 }
    }.contextMenu {
      Section {
        Button("Finder.Show") {
          openFinder(selecting: image.url)
        }

        ImageCollectionDetailItemSidebarView(id: image.id)
      }

      Section {
        Button("Copy", systemImage: "doc.on.doc") {
          if !NSPasteboard.general.write(items: [image.url as NSURL]) {
            Logger.ui.error("Failed to write URL \"\(image.url.string)\" to pasteboard")
          }
        }

        ImageCollectionCopyingView(isPresented: $isCopyingFileImporterPresented) { destination in
          Task(priority: .medium) {
            do {
              try await copy(image: image, to: destination)
            } catch {
              self.error = error.localizedDescription
            }
          }
        }
      }

      Section {
        ImageCollectionDetailItemBookmarkView(bookmarked: bookmarked)
      }
    }.fileImporter(isPresented: $isCopyingFileImporterPresented, allowedContentTypes: [.folder]) { result in
      switch result {
        case .success(let url):
          Task(priority: .medium) {
            do {
              try await copy(image: image, to: url)
            } catch {
              self.error = error.localizedDescription
            }
          }
        case .failure(let err):
          Logger.ui.info("Could not import copy destination from file picker: \(err)")
      }
    }
    .fileDialogCopy()
    .alert(error ?? "", isPresented: isErrorPresented) {}
  }

  func copy(image: ImageCollectionItemImage, to destination: URL) async throws {
    try ImageCollectionCopyingView.saving {
      try destination.withSecurityScope {
        try ImageCollectionCopyingView.saving(url: image, to: destination) { url in
          try image.withSecurityScope {
            try ImageCollectionCopyingView.save(url: url, to: destination, resolvingConflicts: resolveCopyingConflicts)
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
    resampleSize: Int
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

      let size = min(resampleSize, maxSize.dec())

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

struct VisibleImagesPreferenceKey: PreferenceKey {
  typealias Value = [ImageCollectionItemImage]

  static var defaultValue = Value()

  static func reduce(value: inout Value, nextValue: () -> Value) {
    value = nextValue()
  }
}

struct ImageCollectionDetailVisibilityViewModifier: ViewModifier {
  @Environment(ImageCollection.self) private var collection
  @Environment(ImageCollectionPath.self) private var path
  @Environment(ImageCollectionSidebar.self) private var sidebar
  @Environment(\.id) private var id
  @Environment(\.navigationColumns) @Binding private var columns
  @Environment(\.sidebarScroller) private var sidebarScroller
  @Default(.displayTitleBarImage) private var displayTitleBarImage

  func body(content: Content) -> some View {
    content
      .overlayPreferenceValue(VisiblePreferenceKey<ImageCollectionItemImage>.self) { items in
        GeometryReader { proxy in
          let local = proxy.frame(in: .local)
          let images = items
            .filter { local.intersects(proxy[$0.anchor]) }
            .map(\.item)

          // The reason we're factoring the view into its own preference value is because the current one will be called
          // on *every scroll* event the user performs. While views are cheap, there is a cost to always recreating
          // them—and some are slower than others (navigationDocument(_:), for example). In my experience, this split
          // causes CPU usage to decrease from 60-68% to 47-52%, which is a major performance improvement (before anchor
          // preferences, CPU usage was often 42-48%).
          //
          // Now, the reason we're using preferences to report the filtered images (instead of, say, a @State variable),
          // is because of SwiftUI's ability to track changes. @State, just from observing its effects, has no way of
          // distinguishing itself from other observables besides reporting the change and letting SwiftUI diff them.
          // As a result, users may experience slight hangs when the set of visible images changes (~55ms). A preference
          // key, meanwhile, just floats up the view hierarchy and dispenses its value to an attached view. The result
          // is that using preference values here results in no hangs, making it suitable for this case.
          Color.clear.preference(key: VisibleImagesPreferenceKey.self, value: images)
        }
      }.backgroundPreferenceValue(VisibleImagesPreferenceKey.self) { images in
        let highlights = images.filter(\.analysisHasResults)
        let hasHighlights = !highlights.isEmpty
        var highlighted: Bool {
          highlights.allSatisfy(\.highlighted)
        }

        Color.clear.focusedSceneValue(\.liveTextHighlight, .init(
          identity: images,
          enabled: hasHighlights,
          state: hasHighlights && highlighted
        ) {
          images.forEach(setter(value: !highlighted, on: \.highlighted))
        })

        if let primary = images.first {
          var id: ImageCollectionItemImage.ID { primary.id }

          if displayTitleBarImage {
            let url = primary.url

            Color.clear
              .navigationTitle(Text(url.lastPath))
              .navigationDocument(url)
          }

          Color.clear
            .focusedSceneValue(\.showFinder, .init(identity: [primary.id], enabled: true) {
              openFinder(selecting: primary.url)
            })
            .focusedSceneValue(\.jumpToCurrentImage, .init(identity: id) {
              sidebarScroller.scroll(.init(id: id) {
                sidebar.selection = [id]
                path.item = id
              })
            })
            .onChange(of: Pair(left: collection.sidebarPage, right: sidebar.selection)) { prior, pair in
              // If the page changed, ignore.
              guard pair.left == prior.left else {
                return
              }

              path.items.insert(primary.id)
              path.update(images: collection.images)

              Task {
                do {
                  try await collection.persist(id: self.id)
                } catch {
                  Logger.model.error("Could not persist image collection \"\(self.id)\" (via navigation): \(error)")
                }
              }
            }
        }
      }
  }
}

extension View {
  func visibleImages() -> some View {
    self.modifier(ImageCollectionDetailVisibilityViewModifier())
  }
}

struct ImageCollectionDetailView: View {
  @Default(.margins) private var margins
  @Default(.collapseMargins) private var collapseMargins
  @Default(.liveText) private var liveText
  @Default(.liveTextIcon) private var appLiveTextIcon
  @Default(.displayTitleBarImage) private var showTitleBarImage
  @SceneStorage(Defaults.Keys.liveTextIcon.name) private var liveTextIcon: Bool?

  let items: [ImageCollectionDetailItem]
  private var showLiveTextIcon: Bool {
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

    List(items) { item in
      let insets: EdgeInsets = if let edge = item.edge {
        switch edge {
          case .top: top
          case .bottom: bottom
        }
      } else {
        middle
      }

      ImageCollectionDetailItemView(
        image: item.image,
        liveTextIcon: showLiveTextIcon
      )
      .listRowInsets(.listRow + (collapseMargins ? insets : all))
      .listRowSeparator(.hidden)
      .shadow(radius: margin / 2)
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
          showLiveTextIcon
        } set: {
          liveTextIcon = $0
        }

        Toggle("Live Text Icon", systemImage: "text.viewfinder", isOn: icons)
          .help("\(showLiveTextIcon ? "Hide" : "Show") Live Text icon")
      }
    }
    .visibleImages()
    .focusedSceneValue(\.liveTextIcon, .init(enabled: true, state: showLiveTextIcon, menu: .init(identity: true) {
      liveTextIcon = !showLiveTextIcon
    }))
  }
}
