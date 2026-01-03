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
  }
}
