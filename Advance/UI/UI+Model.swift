//
//  UI+Model.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/11/24.
//

import AppKit
import Observation

@Observable @MainActor
class Windowed {
  weak var window: NSWindow?
}

extension FileManager.DirectoryEnumerationOptions {
  init(excludeHiddenFiles: Bool, excludeSubdirectoryFiles: Bool) {
    self.init()

    if excludeHiddenFiles {
      self.insert(.skipsHiddenFiles)
    }

    if excludeSubdirectoryFiles {
      self.insert(.skipsSubdirectoryDescendants)
    }
  }
}
