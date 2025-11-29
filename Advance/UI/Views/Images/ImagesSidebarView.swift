//
//  ImagesSidebarView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import AdvanceCore
import Combine
import OSLog
import SwiftUI

struct ImagesSidebarImportLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(spacing: 4) {
      configuration.icon
        .font(.title)
        .imageScale(.large)
        .symbolRenderingMode(.hierarchical)

      configuration.title
        .font(.callout)
    }
    .fontWeight(.medium)
  }
}

//struct ImagesItemEphemeralTransfer {
//  let source: URL
//  let destination: URL
//}
//
//enum ImagesItemTransfer {
//  case source(URL), ephemeral(ImagesItemEphemeralTransfer)
//}
//
//extension ImagesItemTransfer: Transferable {
//  static var transferRepresentation: some TransferRepresentation {
//    FileRepresentation(importedContentType: .image, shouldAttemptToOpenInPlace: true) { received in
//      try Self(received, directoryHint: .notDirectory)
//    }
//
//    FileRepresentation(importedContentType: .folder, shouldAttemptToOpenInPlace: true) { received in
//      try Self(received, directoryHint: .isDirectory)
//    }
//  }
//
//  init(_ received: ReceivedTransferredFile, directoryHint: URL.DirectoryHint) throws {
//    let url = received.file
//
//    // The file may be:
//    // - An original
//    // - A copy
//    // - A promise
//    //
//    // The first case is most common, corresponding to a local URL. The second case is likely to come from a source
//    // where copying is the only option. The third case is a specialization of the second case where the file is
//    // ephemeral. A file of the last case is valid for the lifetime of the drop operation (that is, for the synchronous
//    // execution of several method calls).
//
//    // Should this codepath even exist? Since its local to images, we implicitly know the accepted URLs.
//    if received.isOriginalFile && !URL.cachesDirectory.contains(url: url) {
//      self = .source(url)
//
//      return
//    }
//
//    let destination = URL.temporaryDataDirectory.appending(component: UUID().uuidString, directoryHint: directoryHint)
//    // I don't believe we need to wrap this as a security-scoped resource given cases two and three imply the file has
//    // been transferred to the App Sandbox directory.
//    try FileManager.default.moveItem(at: url, to: destination)
//
//    self = .ephemeral(ImagesItemEphemeralTransfer(source: url, destination: destination))
//  }
//}

struct ImagesSidebarImportView: View {
  @Environment(ImagesModel.self) private var images
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @State private var isFileImporterPresented = false

  var body: some View {
    ContentUnavailableView {
      Button {
        isFileImporterPresented = true
      } label: {
        Label("Images.Sidebar.Import", systemImage: "square.and.arrow.down")
          .labelStyle(ImagesSidebarImportLabelStyle())
      }
      .buttonStyle(.plain)
//      .frame(maxWidth: .infinity, maxHeight: .infinity)
//      .fileImporter(isPresented: $isFileImporterPresented, allowedContentTypes: imagesContentTypes, allowsMultipleSelection: true) { result in
//        let urls: [URL]
//
//        switch result {
//          case .success(let value):
//            urls = value
//          case .failure(let error):
//            Logger.ui.error("\(error)")
//
//            return
//        }
//
//        Task {
//          do {
//            try await images.submit(
//              items: await Self.source(
//                urls: urls,
//                options: StorageKeys.directoryEnumerationOptions(
//                  importHiddenFiles: importHiddenFiles,
//                  importSubdirectories: importSubdirectories,
//                ),
//              ),
//            )
//          } catch {
//            Logger.model.error("\(error)")
//          }
//        }
//      }
      .fileDialogCustomizationID(NSUserInterfaceItemIdentifier.imagesWindowOpen.rawValue)
//      .dropDestination(for: ImagesItemTransfer.self) { items, _ in
//        Logger.ui.info("\(items)")
//
//        return true
//      }
    }
  }
}

struct ImagesSidebarContentItemTitleView: NSViewControllerRepresentable {
  let label: String

  func makeNSViewController(context: Context) -> TextFieldViewController {
    let textField = NSTextField(labelWithString: label)
    textField.font = .preferredFont(forTextStyle: .subheadline)
    textField.alignment = .center
    textField.lineBreakMode = .byTruncatingTail
    textField.allowsExpansionToolTips = true

    let textFieldViewController = TextFieldViewController()
    textFieldViewController.view = textField

    return textFieldViewController
  }

  func updateNSViewController(_ textFieldViewController: TextFieldViewController, context: Context) {
    textFieldViewController.textField.stringValue = label
  }

  class TextFieldViewController: NSViewController {
    var textField: NSTextField {
      self.view as! NSTextField
    }

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
      super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewWillLayout() {
      super.viewWillLayout()

      let textField = self.textField
      textField.preferredMaxLayoutWidth = 1
    }
  }
}

struct ImagesSidebarContentItemView: View {
  let item: ImagesItemModel

  var body: some View {
    VStack {
      ImagesItemContentView(item: item)
        .overlay(alignment: .topTrailing) {
          Image(systemName: "bookmark.fill")
            .font(.title)
            .imageScale(.small)
            .symbolRenderingMode(.multicolor)
            .opacity(0.85)
            .shadow(radius: 0.5)
            .padding(4)
            .visible(item.isBookmarked)
        }

//      ImagesSidebarContentItemTitleView(label: item.url?.lastPathComponent ?? "")
      let title = item.source.url?.lastPathComponent ?? ""

      Text(title)
        .font(.subheadline)
        .padding(EdgeInsets(vertical: 4, horizontal: 8))
        .background(.fill.tertiary, in: .rect(cornerRadius: 4))
        .help(title)
    }
    // TODO: Document behavior.
    .id(item.id)
//    .draggable(item) {
//      ImagesItemContentView(item: item)
//    }
  }
}

struct ImagesSidebarContentView: View {
  static let defaultScrollAnchor = UnitPoint.center

  @Environment(ImagesModel.self) private var images
  @Environment(\.imagesDetailJump) private var jumpDetail
  @AppStorage(StorageKeys.restoreLastImage) private var restoreLastImage
  @AppStorage(StorageKeys.foldersResolveConflicts) private var copyingResolveConflicts
  @AppStorage(StorageKeys.foldersConflictFormat) private var copyingConflictFormat
  @AppStorage(StorageKeys.foldersConflictSeparator) private var copyingConflictSeparator
  @AppStorage(StorageKeys.foldersConflictDirection) private var copyingConflictDirection
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibility
  @FocusState private var isFocused: Bool
  @State private var selection = Set<ImagesItemModel.ID>()
  @State private var copyingSelection = Set<ImagesItemModel.ID>()
  @State private var isCopyingFileImporterPresented = false
  @State private var isCopyingErrorAlertPresented = false
  @State private var copyingError: CocoaError?
  // TODO: Replace.
  private var selected: Binding<Set<ImagesItemModel.ID>> {
    Binding {
      selection
    } set: { selection in
      defer {
        self.selection = selection
      }

      guard let jump = jumpDetail else {
        return
      }

      let difference = selection.subtracting(self.selection)

      // TODO: Document.
      guard let item = images.items.last(where: { difference.contains($0.id) }) else {
        return
      }

      jump.action(item)
    }
  }
  private var incomingItemID: some Publisher<ImagesItemModel.ID, Never> {
    images.incomingItemID
  }

  var body: some View {
    ScrollViewReader { proxy in
      List(images.items, selection: selected) { item in
        ImagesSidebarContentItemView(item: item)
          .visible(images.isReady)
      }
      .focused($isFocused)
      .contextMenu { ids in
        var isBookmarked: Binding<Bool> {
          Binding {
            !ids.isEmpty && ids.isSubset(of: images.bookmarkedItems)
          } set: { isBookmarked in
            ids
              .compactMap { images.items[id: $0] }
              .forEach { item in
                item.isBookmarked = isBookmarked
              }

            // TODO: Implement persistence.
          }
        }

        Section {
          Button("Finder.Item.Show") {
            showFinder(forSelection: ids)
          }
        }

        Section {
          Button("Copy") {
            // TODO: Use source to produce pasteboard item.
            //
            // The URL is not required to reference an existing item.
            let urls = images.items
              .filter(in: ids, by: \.id)
              .compactMap(\.source.url)

            let pasteboard = NSPasteboard.general
            pasteboard.prepareForNewContents()

            if !pasteboard.writeObjects(urls as [NSURL]) {
              let s = urls
                .map(\.pathString)
                .joined(separator: "\n")

              Logger.ui.error("Could not write the following URLs to the general pasteboard:\n\(s)")
            }
          }

          CopyingSettingsMenuView { source in
            let sources = images.items
              .filter(in: ids, by: \.id)
              .map(\.source)

            Task {
              do {
                try await copy(sources: sources, to: source)
              } catch let error as CocoaError where error.code == .fileWriteFileExists {
                copyingError = error
                isCopyingErrorAlertPresented = true
              } catch {
                Logger.ui.error("\(error)")
              }
            }
          } primaryAction: {
            copyingSelection = ids
            isCopyingFileImporterPresented = true
          }
        }

        Section {
          ImagesBookmarkView(isBookmarked: isBookmarked)
        }
      }
      .fileImporter(isPresented: $isCopyingFileImporterPresented, allowedContentTypes: foldersContentTypes) { result in
        let url: URL

        switch result {
          case let .success(item):
            url = item
          case let .failure(error):
            Logger.ui.error("\(error)")

            return
        }

        let sources = images.items
          .filter(in: copyingSelection, by: \.id)
          .map(\.source)

        Task {
          do {
            try await copy(sources: sources, to: URLSource(url: url, options: .withSecurityScope))
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
      .alert(Text(copyingError?.localizedDescription ?? ""), isPresented: $isCopyingErrorAlertPresented) {
        // Empty
      }
      .focusedSceneValue(\.imagesSidebarJump, ImagesNavigationJumpAction(identity: ImagesNavigationJumpIdentity(id: images.id, isReady: images.isReady)) { item in
        showSidebar(proxy, at: item)
      })
      .focusedSceneValue(\.imagesSidebarShow, AppMenuActionItem(identity: images.id, enabled: images.item != nil) {
        guard let item = images.item else {
          return
        }

        showSidebar(proxy, at: item)
      })
      .onReceive(incomingItemID) { id in
        guard restoreLastImage else {
          return
        }

        proxy.scrollTo(id, anchor: Self.defaultScrollAnchor)
      }
    }
  }

  private func showFinder(forSelection selection: Set<ImagesItemModel.ID>) {
    let urls = images.items
      .filter(in: selection, by: \.id)
      .compactMap(\.source.url)

    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }

  private func showSidebar(_ proxy: ScrollViewProxy, at item: ImagesItemModel) {
    proxy.scrollTo(item.id, anchor: Self.defaultScrollAnchor)

    selection = [item.id]

    // TODO: Document async behavior.
    Task {
      withAnimation {
        // FIXME: Column visibility does not always animate.
        columnVisibility = StorageColumnVisibility(.automatic)
      } completion: {
        isFocused = true
      }
    }
  }

  private nonisolated static func copy(
    sources: some Sequence<some ImagesItemModelSource & Sendable> & Sendable,
    to source: URLSource,
    resolveConflicts: Bool,
    format: String,
    separator: Character,
    direction: StorageDirection
  ) async throws {
    try await source.accessingSecurityScopedResource {
      for src in sources {
        try await CopyingSettingsMenuView.copy(
          itemSource: src,
          to: source,
          resolveConflicts: resolveConflicts,
          format: format,
          separator: separator,
          direction: direction
        )
      }
    }
  }
  
  private func copy(
    sources: some Sequence<some ImagesItemModelSource & Sendable> & Sendable,
    to source: URLSource
  ) async throws {
    try await Self.copy(
      sources: sources,
      to: source,
      resolveConflicts: copyingResolveConflicts,
      format: copyingConflictFormat,
      separator: copyingConflictSeparator.separator.separator(direction: copyingConflictDirection),
      direction: copyingConflictDirection
    )
  }
}

struct ImagesSidebarView: View {
  @Environment(ImagesModel.self) private var images
  var isEmpty: Bool {
    images.isReady && images.items.isEmpty
  }

  var body: some View {
    ImagesSidebarContentView()
      .overlay {
        let isEmpty = isEmpty

        ImagesSidebarImportView()
          .visible(isEmpty)
          .animation(.default, value: isEmpty)
          .transaction(value: isEmpty, setter(on: \.disablesAnimations, value: !isEmpty))
      }
  }
}
