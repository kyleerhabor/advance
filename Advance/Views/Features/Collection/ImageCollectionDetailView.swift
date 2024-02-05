//
//  ImageCollectionDetailView.swift
//  Advance
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
    Button("Sidebar.Item.Show") {
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
  @Default(.liveTextSubject) private var liveTextSubject
  @Default(.liveTextSearchWith) private var liveTextSearchWith
  @Default(.liveTextDownsample) private var liveTextDownsample
  @Default(.resolveCopyingConflicts) private var resolveCopyingConflicts
  @State private var isCopyingFileImporterPresented = false
  @State private var error: String?
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
        var isSuccess: Bool {
          phase.success != nil
        }

        ImageCollectionItemPhaseView(phase: phase)
          .aspectRatio(image.properties.sized.aspectRatio, contentMode: .fit)
          .overlay {
            let none = 0
            var length: Int {
              phase.success.map { Int($0.size.length.rounded(.up)) } ?? none
            }

            var interactions: ImageAnalysisOverlayView.InteractionTypes {
              var interactions = ImageAnalysisOverlayView.InteractionTypes()

              guard liveText && isSuccess else {
                return interactions
              }

              interactions.insert([.textSelection, .dataDetectors])

              if liveTextSubject {
                // In my experience, .visualLookUp does nothing. But maybe it's supposed to do something?
                interactions.insert([.imageSubject, .visualLookUp])
              }

              return interactions
            }
            var input: ImageCollectionItemImageAnalysisInput {
              .init(
                url: image.url,
                interactions: interactions,
                downsample: liveTextDownsample && length != none,
                isSuccessPhase: isSuccess
              )
            }

            LiveTextView(
              interactions: interactions,
              result: image.analysis?.output,
              highlight: $image.highlighted
            ) { handler in
              await image.withSecurityScope(handler)
            }
            .supplementaryInterfaceHidden(!liveTextIcon)
            .searchEngineHidden(!liveTextSearchWith)
            .task(id: Pair(left: liveText, right: input)) {
              guard liveText else {
                return
              }

              let input = input

              guard image.analysis?.input != input && input.isSuccessPhase else {
                return
              }

              let analysis = await image.withSecurityScope {
                await Self.analyze(
                  url: image.url,
                  orientation: image.properties.orientation,
                  interactions: input.interactions,
                  resample: input.downsample,
                  resampleSize: min(length, ImageAnalyzer.maxSize)
                )
              }

              guard let analysis else {
                return
              }

              image.analysis = .init(
                input: input,
                output: .init(id: .init(), analysis: analysis)
              )
            }
          }
      }
    }.contextMenu {
      Section {
        Button("Finder.Show") {
          openFinder(selecting: image.url)
        }

        ImageCollectionDetailItemSidebarView(id: image.id)
      }

      Section {
        Button("Copy") {
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
    // TODO: Create a view modifier to automatically specify an empty actions
    .alert(error ?? "", isPresented: isErrorPresented) {}
  }

  nonisolated func copy(image: ImageCollectionItemImage, to destination: URL) async throws {
    try await Self.copy(image: image, to: destination, resolvingConflicts: resolveCopyingConflicts)
  }

  static nonisolated func copy(
    image: ImageCollectionItemImage,
    to destination: URL,
    resolvingConflicts resolveConflicts: Bool
  ) async throws {
    try ImageCollectionCopyingView.saving {
      try destination.withSecurityScope {
        try ImageCollectionCopyingView.saving(url: image, to: destination) { url in
          try image.withSecurityScope {
            try ImageCollectionCopyingView.save(url: url, to: destination, resolvingConflicts: resolveConflicts)
          }
        }
      }
    }
  }

  static func analyze(
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
      return try await Self.analyze(analyzer: analyzer, imageAt: url, orientation: orientation, configuration: configuration)
    } catch let err as NSError where err.domain == ImageAnalyzer.errorDomain && err.code == ImageAnalyzer.errorMaxSizeCode {
      guard resample else {
        Logger.ui.error("Could not analyze image at URL \"\(url.string)\" as its size is too large: \(err)")

        return nil
      }

      let size = min(resampleSize, maxSize.decremented())

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
        return try await Self.analyze(analyzer: analyzer, imageAt: url, orientation: orientation, configuration: configuration)
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
  static func analyze(
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
        let primary = images.first
        let highlights = images.filter { $0.analysis?.hasResults ?? false }
        let hasHighlights = !highlights.isEmpty
        let highlighted = highlights.allSatisfy(\.highlighted)
        let finderShowIdent: Set<ImageCollectionItemImage.ID> = if let primary {
          [primary.id]
        } else {
          []
        }

        Color.clear
          .focusedSceneValue(\.liveTextHighlight, .init(
            identity: highlights.map(\.id),
            enabled: hasHighlights,
            state: hasHighlights && highlighted
          ) { highlight in
            images.forEach(setter(value: highlight, on: \.highlighted))
          })
          .focusedSceneValue(\.finderShow, .init(identity: finderShowIdent, enabled: primary != nil) {
            guard let primary else {
              return
            }

            openFinder(selecting: primary.url)
          })
          .focusedSceneValue(\.currentImageShow, .init(identity: primary?.id, enabled: primary != nil) {
            guard let primary else {
              return
            }

            sidebarScroller.scroll(.init(id: primary.id) {
              sidebar.selection = [primary.id]
              path.item = primary.id
            })
          })
          .focusedSceneValue(\.bookmark, .init(
            identity: primary?.id,
            enabled: primary != nil,
            state: primary?.bookmarked ?? false
          ) { bookmark in
            guard let primary else {
              return
            }

            primary.bookmarked = bookmark

            Task {
              do {
                try await collection.persist(id: id)
              } catch {
                Logger.model.error("Could not persist image collection \"\(id)\" via bookmark focus: \(error)")
              }
            }
          })

        if let primary {
          if displayTitleBarImage {
            let url = primary.url

            Color.clear
              .navigationTitle(Text(url.lastPath))
              .navigationDocument(url)
          }

          Color.clear.onChange(of: Pair(left: collection.sidebarPage, right: sidebar.selection)) { prior, pair in
            // If the page changed, ignore.
            guard pair.left == prior.left else {
              return
            }

            path.items.insert(primary.id)
            path.update(images: collection.images)

            Task {
              do {
                try await collection.persist(id: id)
              } catch {
                Logger.model.error("Could not persist image collection \"\(id)\" (via navigation): \(error)")
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
  @Environment(\.id) private var id
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
      let image = item.image
      let insets: EdgeInsets = if let edge = item.edge {
        switch edge {
          case .top: top
          case .bottom: bottom
        }
      } else {
        middle
      }

      ImageCollectionDetailItemView(
        image: image,
        liveTextIcon: showLiveTextIcon
      )
      .listRowInsets(.listRow + (collapseMargins ? insets : all))
      .listRowSeparator(.hidden)
      .shadow(radius: margin / 2)
      .anchorPreference(key: VisiblePreferenceKey.self, value: .bounds) { [.init(item: image, anchor: $0)] }
    }
    .listStyle(.plain)
    .backgroundPreferenceValue(VisiblePreferenceKey<ImageCollectionItemImage>.self) { images in
      Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: images.last?.anchor)
    }
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
    .focusedSceneValue(\.liveTextIcon, .init(identity: id, enabled: true, state: showLiveTextIcon) { icon in
      liveTextIcon = icon
    })
  }
}
