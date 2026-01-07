//
//  View.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/31/23.
//

import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct FileDialogCopyViewModifier: ViewModifier {
  static let id = "copy"

  func body(content: Content) -> some View {
    content
      .fileDialogCustomizationID(Self.id)
      .fileDialogConfirmationLabel("Copy")
  }
}

extension View {
  func fileDialogCopy() -> some View {
    self.modifier(FileDialogCopyViewModifier())
  }
}

enum Navigator {
  case images
  case bookmarks
}

extension Navigator: Equatable {}
