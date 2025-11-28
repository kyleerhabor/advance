//
//  FoldersSettingsView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/26/25.
//

import OSLog
import SwiftUI

struct FoldersSettingsView: View {
  @Environment(AppModel.self) private var app
  @Environment(FoldersSettingsModel2.self) private var folders
  @State private var selection = Set<FoldersSettingsItemModel.ID>()
  @State private var isFileImporterPresented = false
  private var isFinderDisabled: Bool {
    folders.isInvalidSelection(of: selection)
  }

  var body: some View {
    // TODO: Figure out how to get animations working.
    List(selection: $selection) {
      ForEach(folders.items) { item in
        Label {
          Text(item.path)
        } icon: {
          FoldersSettingsItemIconView(item: item)
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .help(item.isResolved ? Text(item.helpPath) : Text("Settings.Accessory.Folders.Item.Unresolved"))
      }
      .onDelete { items in
        Task {
          await folders.remove(items: items)
        }
      }
    }
    .listStyle(.inset)
    .focusedSceneValue(\.commandScene, AppModelCommandScene(
      id: .folders,
      disablesShowFinder: isFinderDisabled,
      disablesOpenFinder: isFinderDisabled,
      disablesResetWindowSize: true,
    ))
    .toolbar {
      Button("Settings.Accessory.Folders.Item.Add", systemImage: "plus") {
        isFileImporterPresented = true
      }
      .fileImporter(
        isPresented: $isFileImporterPresented,
        allowedContentTypes: foldersContentTypes,
        allowsMultipleSelection: true,
      ) { result in
        let urls: [URL]

        switch result {
          case let .success(x):
            urls = x
          case let .failure(error):
            // TODO: Elaborate.
            Logger.ui.error("\(error)")

            return
        }

        Task {
          await folders.store(urls: urls)
        }
      }
      .fileDialogCustomizationID(FoldersSettingsScene.id)
    }
    .dropDestination(for: FoldersSettingsItemTransfer.self) { items, _ in
      Task {
        await folders.store(items: items)
      }

      return true
    }
    .onDeleteCommand {
      Task {
        await folders.remove(items: selection)
      }
    }
    .onReceive(app.commandsPublisher) { command in
      guard command.sceneID == .folders else {
        return
      }

      switch command.action {
        case .open:
          isFileImporterPresented = true
        case .showFinder:
          folders.showFinder(items: selection)
        case .openFinder:
          folders.openFinder(items: selection)
        case .resetWindowSize:
          unreachable()
      }
    }
  }
}
