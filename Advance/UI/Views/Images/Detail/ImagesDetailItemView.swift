//
//  ImagesDetailItemView.swift
//  Advance
//
//  Created by Kyle Erhabor on 8/11/24.
//

import AdvanceCore
import Algorithms
import OSLog
import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import VisionKit

struct ImagesDetailItemContentAnalysisView: View {
  let item: ImagesItemModel
  let phase: ImagesItemPhase
  @Binding var selectedText: String
  @Binding var isHighlighted: Bool
  let transformMenu: ImageAnalysisView.TransformMenu

  @Environment(ImagesModel.self) private var images
  @Environment(\.isImageAnalysisEnabled) private var isImageAnalysisEnabled
  @AppStorage(StorageKeys.liveTextSubject) private var liveTextSubject
  @State private var analysis: ImageAnalysis?
  private var interactionTypes: ImageAnalysisOverlayView.InteractionTypes {
    var types = ImageAnalysisOverlayView.InteractionTypes()

    guard isImageAnalysisEnabled else {
      return types
    }

    types.insert(.automaticTextOnly)

    if liveTextSubject {
      types.insert(.automatic)
    }

    return types
  }

  var body: some View {
    // FIXME: ImageAnalysisView does not discover NSMenu for paged style.
    ImageAnalysisView(
      selectedText: $selectedText,
      isHighlighted: $isHighlighted,
      analysis: analysis,
      interactionTypes: interactionTypes,
      transformMenu: transformMenu
    )
    .task(id: phase.resample) {
      analysis = await analyze()
    }
  }

  func analyze() async -> ImageAnalysis? {
    guard !interactionTypes.isEmpty,
          let resample = phase.resample else {
      return nil
    }

    let analyzer = ImageAnalyzer()

    do {
      return try await Self.analyze(
        analyzer,
        in: images.analyzer.continuation,
        source: item.source,
        resample: resample
      )
    } catch {
      Logger.ui.error("Could not analyze image from source \"\(item.source)\": \(error, privacy: .public)")

      return nil
    }
  }

  nonisolated static func analyze(
    _ analyzer: ImageAnalyzer,
    in runGroup: ImagesModel.Analyzer.Continuation,
    source: some ImagesItemModelSource & Sendable,
    resample: ImagesItemResample
  ) async throws -> ImageAnalysis {
    try await run(in: runGroup) {
      let execution = try await ContinuousClock.continuous.time {
        try await analyzer.analyze(
          resample.image,
          orientation: .up,
          configuration: ImageAnalyzer.Configuration(.text)
        )
      }

      Logger.ui.info("Took \(execution.duration) to analyze image from source \"\(source)\"")

      return execution.value
    }
  }
}

struct ImagesDetailItemContentView: View {
  let item: ImagesItemModel
  @Binding var selectedText: String
  let transformMenu: ImageAnalysisView.TransformMenu

  @State private var phase = ImagesItemPhase.empty
  @State private var isHighlighted = false

  var body: some View {
    ImagesItemView(item: item, phase: $phase) {
      ImagesItemPhaseView(phase: phase)
        .aspectRatio(item.properties.aspectRatio, contentMode: .fit)
        .overlay {
          ImagesDetailItemContentAnalysisView(
            item: item,
            phase: phase,
            selectedText: $selectedText,
            isHighlighted: $isHighlighted,
            transformMenu: transformMenu
          )
        }
        .anchorPreference(key: VisiblePreferenceKey<ImagesDetailListVisibleItem>.self, value: .bounds) { anchor in
          let item = ImagesDetailListVisibleItem(item: item, isHighlighted: isHighlighted) { isOn in
            isHighlighted = isOn
          }

          return [VisibleItem(item: item, anchor: anchor)]
        }
    }
  }
}

struct ImagesDetailItemView: View {
  @Environment(ImagesModel.self) private var images
  @Environment(SearchSettingsModel.self) private var search
  @Environment(\.imagesSidebarJump) private var jumpSidebar
  @Environment(\.localize) private var localize
  @Environment(\.openURL) private var openURL
  @AppStorage(StorageKeys.searchUseSystemDefault) private var searchUseSystemDefault
  @AppStorage(StorageKeys.foldersResolveConflicts) private var copyingResolveConflicts
  @AppStorage(StorageKeys.foldersConflictFormat) private var copyingConflictFormat
  @AppStorage(StorageKeys.foldersConflictSeparator) private var copyingConflictSeparator
  @AppStorage(StorageKeys.foldersConflictDirection) private var copyingConflictDirection
  @State private var selectedText = ""
  @State private var isCopyingFileImporterPresented = false
  @State private var isCopyingErrorAlertPresented = false
  @State private var copyingError: CocoaError?
  // TODO: Replace.
  private var isBookmarked: Binding<Bool> {
    Binding {
      item.isBookmarked
    } set: { isBookmarked in
      item.isBookmarked = isBookmarked

      Task {
        do {
          try await images.submitItemBookmark(item: item, isBookmarked: isBookmarked)
        } catch {
          Logger.model.error("\(error)")
        }
      }
    }
  }

  let item: ImagesItemModel

  var body: some View {
    VStack {
      ImagesDetailItemContentView(
        item: item,
        selectedText: $selectedText,
        transformMenu: transform
      )
    }
    .id(item.id)
    .fileImporter(isPresented: $isCopyingFileImporterPresented, allowedContentTypes: foldersContentTypes) { result in
      let url: URL

      switch result {
        case let .success(item):
          url = item
        case let .failure(error):
          Logger.ui.error("\(error)")

          return
      }

      Task {
        do {
          try await copy(to: URLSource(url: url, options: .withSecurityScope))
        } catch let error as CocoaError where error.code == .fileWriteFileExists {
          copyingError = error
          isCopyingErrorAlertPresented = true
        } catch {
          Logger.ui.error("\(error)")
        }
      }
    }
    .fileDialogCustomizationID(FoldersSettingsScene.id)
    .fileDialogConfirmationLabel(Text("Copy"))
    .contextMenu {
      Section {
        Button("Finder.Item.Show", action: item.source.showFinder)
          .disabled(item.source.url == nil)

        Button("Sidebar.Item.Show") {
          jumpSidebar?.action(item)
        }
      }

      Section {
        Button("Copy") {
          // TODO: Abstract.
          //
          // TODO: Use source to produce pasteboard item.
          //
          // The URL is not required to reference an existing item.
          guard let url = item.source.url else {
            return
          }

          let pasteboard = NSPasteboard.general
          pasteboard.prepareForNewContents()

          if !pasteboard.writeObjects([url as NSURL]) {
            Logger.ui.error("Could not write URL \"\(url.pathString)\" to the general pasteboard")
          }
        }

        CopyingSettingsMenuView { source in
          Task {
            do {
              try await copy(to: source)
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
              copyingError = error
              isCopyingErrorAlertPresented = true
            } catch {
              Logger.ui.error("\(error)")
            }
          }
        } primaryAction: {
          isCopyingFileImporterPresented.toggle()
        }
      }

      Section {
        ImagesBookmarkView(isBookmarked: isBookmarked)
      }
    }
    .alert(Text(copyingError?.localizedDescription ?? ""), isPresented: $isCopyingErrorAlertPresented) {
      // Empty
    }
  }

  private nonisolated static func copy(
    source itemSource: some ImagesItemModelSource & Sendable,
    to source: URLSource,
    resolveConflicts: Bool,
    format: String,
    separator: Character,
    direction: StorageDirection
  ) async throws {
    try await source.accessingSecurityScopedResource {
      try await CopyingSettingsMenuView.copy(
        itemSource: itemSource,
        to: source,
        resolveConflicts: resolveConflicts,
        format: format,
        separator: separator,
        direction: direction
      )
    }
  }

  private func copy(to source: URLSource) async throws {
    try await Self.copy(
      source: item.source,
      to: source,
      resolveConflicts: copyingResolveConflicts,
      format: copyingConflictFormat,
      separator: copyingConflictSeparator.separator.separator(direction: copyingConflictDirection),
      direction: copyingConflictDirection
    )
  }

  private func performSearch() {
    guard let engine = search.engine,
          let url = engine.url(text: selectedText) else {
      return
    }

    openURL(url)
  }

  private func transform(
    menu: NSMenu,
    bind: (NSMenuItem, @escaping ImageAnalysisView.BindMenuItemAction) -> Void
  ) -> NSMenu {
    if let item = menu.item(withTag: ImageAnalysisOverlayView.MenuTag.copyImage) {
      menu.removeItem(item)
    }

    if let item = menu.item(withTag: ImageAnalysisOverlayView.MenuTag.shareImage) {
      menu.removeItem(item)
    }

    let searchItem = menu.items.first { item in
      item.tag == NSMenuItem.unknownTag
      && item.isStandard
      // We're checking for a represented object to distinguish exceptional items (such as "Create Reminder"). We could
      // match the prefix of the action selector, but that could easily break with an OS update.
      && item.representedObject == nil
      && !item.isHidden
    }

    guard let searchItem else {
      // The image analysis view did not create a "Search With ..." menu item. This means selectedText is
      // irrelevant to this context and should not be visible.

      return menu
    }

    if searchUseSystemDefault {
      // The user prefers to use the default search experience.

      return menu
    }

    guard let engine = search.engine else {
      // The user hasn't set a search engine: display nothing.
      menu.removeItem(searchItem)

      return menu
    }

    let item = NSMenuItem()
    item.title = localize("Images.Detail.Search.\(engine.name)")

    bind(item, performSearch)

    // index(of:) returns -1 on not found, but should not be a concern, given the objects exist.
    menu.items[menu.index(of: searchItem)] = item

    return menu
  }
}
