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
      ImagesItemContentView()
    }
    // TODO: Document behavior.
    .id(item.id)
  }
}

struct ImagesSidebarContentView: View {
  static let defaultScrollAnchor = UnitPoint.center

  @Environment(ImagesModel.self) private var images
  @State private var selection = Set<ImagesItemModel.ID>()

  var body: some View {
    ScrollViewReader { proxy in
      List(images.items2, selection: $selection) { item in
        ImagesSidebarContentItemView(item: item)
          .visible(images.isReady)
      }
      .fileDialogCustomizationID(FoldersSettingsScene.id)
      .fileDialogConfirmationLabel(Text("Copy"))
    }
  }
}

struct ImagesSidebarView: View {
  @Environment(ImagesModel.self) private var images
  var isEmpty: Bool {
    images.isReady && images.items2.isEmpty
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
