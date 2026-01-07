//
//  ImagesSidebarView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/30/24.
//

import Combine
import OSLog
import SwiftUI

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
//      .overlay {
//        let isEmpty = isEmpty
//
//        ImagesSidebarImportView()
//          .visible(isEmpty)
//          .animation(.default, value: isEmpty)
//          .transaction(value: isEmpty, setter(on: \.disablesAnimations, value: !isEmpty))
//      }
  }
}
