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
  @Environment(FoldersSettingsModel.self) private var folders
  @State private var selection = Set<FoldersSettingsItemModel.ID>()
  @State private var isFileImporterPresented = false

  var body: some View {
    let isInvalidSelection = self.folders.isInvalidSelection(of: self.selection)

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
      showFinder: AppModelActionCommand(isDisabled: isInvalidSelection),
      openFinder: AppModelActionCommand(isDisabled: isInvalidSelection),
      showSidebar: AppModelActionCommand(isDisabled: true),
      sidebarBookmarks: AppModelToggleCommand(isDisabled: true, isOn: false),
      bookmark: AppModelToggleCommand(isDisabled: true, isOn: false),
      liveTextIcon: AppModelToggleCommand(isDisabled: true, isOn: false),
      liveTextHighlight: AppModelToggleCommand(isDisabled: true, isOn: false),
      resetWindowSize: AppModelActionCommand(isDisabled: true),
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
      onCommand(command)
    }
  }

  func onCommand(_ command: AppModelCommand) {
    guard command.sceneID == .folders else {
      return
    }

    switch command.action {
      case .open:
        self.isFileImporterPresented = true
      case .showFinder:
        Task {
          await self.folders.showFinder(items: self.selection)
        }
      case .openFinder:
        Task {
          await self.folders.openFinder(items: self.selection)
        }
      case .showSidebar, .toggleSidebarBookmarks, .bookmark, .toggleLiveTextIcon, .toggleLiveTextHighlight,
           .resetWindowSize:
        unreachable()
    }
  }
}
