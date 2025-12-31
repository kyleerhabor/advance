//
//  ImagesView.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/12/24.
//

import OSLog
import SwiftUI

struct ImagesView: View {
  @Environment(ImagesModel.self) private var images

  var body: some View {
    NavigationSplitView {
      ImagesSidebarView()
    } detail: {
      ImagesDetailView()
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
