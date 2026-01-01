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

extension FileManager {
  func contents(at url: URL, options: DirectoryEnumerationOptions) -> [URL] {
    self
      .enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: options)?
      .contents() ?? []
  }
}

extension FileManager.DirectoryEnumerationOptions {
  init(includingHiddenFiles hidden: Bool, includingSubdirectories subdirectories: Bool) {
    // Packages are directories presented as files in Finder (e.g. an app). Generally, there is no reason to descend
    // into them, as their structures are usually distinct.
    self = .skipsPackageDescendants

    if !hidden {
      self.insert(.skipsHiddenFiles)
    }

    if !subdirectories {
      self.insert(.skipsSubdirectoryDescendants)
    }
  }
}

enum Navigator {
  case images
  case bookmarks
}

extension Navigator: Equatable {}
