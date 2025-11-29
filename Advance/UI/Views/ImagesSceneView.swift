//
//  ImagesSceneView.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/20/25.
//

import AdvanceCore
import SwiftUI
import OSLog

// This view exists to update the environment.
struct ImagesSceneView: View {
  @EnvironmentObject private var delegate: AppDelegate2
  @Environment(ImagesModel.self) private var images
  @Environment(Windowed.self) private var windowed
  @Environment(\.isWindowFullScreen) private var isWindowFullScreen
  @Environment(\.openWindow) private var openWindow
  @AppStorage(StorageKeys.liveTextEnabled) private var liveTextEnabled
  @AppStorage(StorageKeys.liveTextIcon) private var liveTextIcon
  @AppStorage(StorageKeys.importHiddenFiles) private var importHiddenFiles
  @AppStorage(StorageKeys.importSubdirectories) private var importSubdirectories
  @SceneStorage(StorageKeys.liveTextIconVisibility) private var liveTextIconVisibility
  @State private var openURL: URL?

  var body: some View {
//    let isSupplementaryInterfaceHidden = switch liveTextIconVisibility.visibility {
//      case .automatic: !liveTextIcon
//      case .visible: false
//      case .hidden: true
//    }

    ImagesView()
      .environment(\.isImageAnalysisEnabled, images.isReady && liveTextEnabled)
//      .environment(\.isImageAnalysisSupplementaryInterfaceHidden, isSupplementaryInterfaceHidden)
//      .focusedSceneValue(\.imagesWindowResetSize, AppMenuActionItem(identity: images.id, enabled: !isWindowFullScreen) {
//        windowed.window?.setContentSize(ImagesScene.defaultSize)
//      })
      .onOpenURL { url in
        openURL = url
      }
      .onReceive(delegate.open) { urls in
        guard let url = openURL else {
          return
        }

        // SwiftUI implements onOpenURL(perform:) in a weird way. For a collection of [A, B, C, D, E],
        // onOpenURL(perform:) receives B while NSApplicationDelegate.application(_:open:) receives [C, D, E, A]. This
        // code simply restores the order. The implementation is unstable since SwiftUI could change the order at any
        // time; but we could remedy this with conditional compilation for the platform version.
        var items = urls.last.map { [$0] } ?? []
        items.append(url)
        items.append(contentsOf: urls.dropLast())

        Task {
//          do {
//            try await images.submit(
//              items: await Self.source(
//                urls: items,
//                options: StorageKeys.directoryEnumerationOptions(
//                  importHiddenFiles: importHiddenFiles,
//                  importSubdirectories: importSubdirectories,
//                ),
//              ),
//            )
//          } catch {
//            Logger.model.error("\(error)")
//
//            return
//          }
        }
      }
  }
}
