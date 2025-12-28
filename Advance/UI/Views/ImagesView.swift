//
//  ImagesView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/12/24.
//

import AdvanceCore
import OSLog
import SwiftUI

struct ImagesView: View {
  @Environment(ImagesModel.self) private var images
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen
  @Environment(\.isImageAnalysisEnabled) private var isImageAnalysisEnabled
  @Environment(\.isImageAnalysisSupplementaryInterfaceHidden) private var isImageAnalysisIconHidden
  @SceneStorage(StorageKeys.columnVisibility) private var columnVisibility
  @SceneStorage(StorageKeys.liveTextIconVisibility) private var liveTextIconVisibility

  var body: some View {
    NavigationSplitView/*(columnVisibility: columns)*/ {
      ImagesSidebarView()
        .navigationSplitViewColumnWidth(min: 128, max: 256)
    } detail: {
      ImagesDetailView()
        .frame(minWidth: 256)
        // In macOS 15, using the word "images" seems to create issues with NSToolbar. "i", as an abbreviation, still
        // causes issues, but is preferable to the app crashing.
        .toolbar(id: "\(Bundle.appID).i") {
          ToolbarItem(id: "\(Bundle.appID).i.live-text-icon") {
            let isVisible = Binding {
              isImageAnalysisEnabled && !isImageAnalysisIconHidden
            } set: { isVisible in
              // FIXME: This is slow.
              liveTextIconVisibility = StorageVisibility(Visibility(isVisible))
            }

            Toggle(
              isVisible.wrappedValue ? "Images.Toolbar.LiveTextIcon.Hide" : "Images.Toolbar.LiveTextIcon.Show",
              systemImage: "text.viewfinder",
              isOn: isVisible
            )
            .disabled(!isImageAnalysisEnabled)
          }
        }
    }
    // windowToolbarFullScreenVisibility(_:) exists, but does not restore to a hidden toolbar.
    .toolbar(isWindowFullScreen ? .hidden : .automatic)
    // In macOS 15, toolbar IDs need to be unique across scenes.
    .focusedSceneValue(\.imagesLiveTextIcon, AppMenuToggleItem(
      identity: images.id,
      enabled: isImageAnalysisEnabled,
      state: !isImageAnalysisIconHidden
    ) { isVisible in
      // FIXME: This is slow.
      liveTextIconVisibility = StorageVisibility(Visibility(isVisible))
    })
    .task(id: images) {
      await images.load2()
    }
    .task(id: images) {
      if Task.isCancelled {
        // SwiftUI was pre-rendering.
        return
      }

      do {
        try await images.load()
      } catch {
        Logger.model.error("Could not load image collection \"\(images.id)\": \(error, privacy: .public)")
      }
    }
  }
}
