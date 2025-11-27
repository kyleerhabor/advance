//
//  ImagesSceneView2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/23/25.
//

import SwiftUI

struct ImagesSceneView2: View {
  @Environment(ImagesModel.self) private var images
  @Environment(Windowed.self) private var windowed

  var body: some View {
    ImagesView2()
      .focusedSceneValue(images)
      .focusedSceneValue(windowed)
  }
}
