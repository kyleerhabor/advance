//
//  Seq.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/24/23.
//

import SwiftUI
import UniformTypeIdentifiers

// For some reason, conforming to Transferable and declaring the support for UTType.image is not enough to support .dropDestination(...)
struct SeqImage: Identifiable {
  let id: UUID
  var url: URL
  let size: Size
  var type: UTType?
  var fileSize: Int?
}
