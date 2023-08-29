//
//  SequenceCopyDestinationView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/28/23.
//

import OSLog
import SwiftUI

struct SequenceCopyDestinationView: View {
  let destinations: [URL]
  let action: (URL) -> Void

  var body: some View {
    // TODO: Support the primaryAction parameter.
    //
    // I haven't been able to get permission to write to the folder, for some reason.
    Menu("Copy to Folder") {
      ForEach(destinations, id: \.self) { destination in
        Button(destination.lastPathComponent) {
          // TODO: Support replacing.
          //
          // See the above TODO.
          //
          // TODO: Extract the duplicated alert.
          action(destination)
        }
      }
    }
  }
}
