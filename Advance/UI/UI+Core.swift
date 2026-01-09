//
//  UI+Core.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/29/24.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import VisionKit

let imagesContentTypes: [UTType] = [.image, .folder]
let foldersContentTypes: [UTType] = [.folder]

// MARK: - Storage

enum StorageAppearance: Int {
  case automatic, light, dark

  var appearance: NSAppearance? {
    switch self {
      case .light: NSAppearance(named: .aqua)
      case .dark: NSAppearance(named: .darkAqua)
      default: nil
    }
  }
}

enum StorageVisibility: Int {
  case automatic, visible, hidden
}

enum StorageColumnVisibility: Int {
  case automatic, all, doubleColumn, detailOnly

  init?(_ columnVisibility: NavigationSplitViewVisibility) {
    switch columnVisibility {
      case .automatic:
        self = .automatic
      case .all:
        self = .all
      case .doubleColumn:
        self = .doubleColumn
      case .detailOnly:
        self = .detailOnly
      default:
        return nil
    }
  }

  var columnVisibility: NavigationSplitViewVisibility {
    switch self {
      case .automatic: .automatic
      case .all: .all
      case .doubleColumn: .doubleColumn
      case .detailOnly: .detailOnly
    }
  }
}

extension SetAlgebra {
  func value(_ value: Bool, for set: Self) -> Self {
    value ? self.union(set) : self.subtracting(set)
  }
}

struct StorageHiddenLayout: OptionSet {
  let rawValue: Int

  static let toolbar = Self(rawValue: 1 << 0)
  static let cursor = Self(rawValue: 1 << 1)
  static let scroll = Self(rawValue: 1 << 2)

  var toolbar: Bool {
    get { self.contains(.toolbar) }
    set { self = value(newValue, for: .toolbar) }
  }

  var cursor: Bool {
    get { self.contains(.cursor) }
    set { self = value(newValue, for: .cursor) }
  }

  var scroll: Bool {
    get { self.contains(.scroll) }
    set { self = value(newValue, for: .scroll) }
  }
}

enum StorageFoldersPathSeparator: Int {
  case inequalitySign, singlePointingAngleQuotationMark, blackPointingTriangle, blackPointingSmallTriangle
}

enum StorageFoldersPathDirection: Int {
  case leading, trailing
}

struct StorageKey<Value> {
  let name: String
  let defaultValue: Value
}

extension StorageKey {
  init(_ name: String, defaultValue: Value) {
    self.init(name: name, defaultValue: defaultValue)
  }
}

extension StorageKey: Sendable where Value: Sendable {}

extension AppStorage {
  init(_ key: StorageKey<Value>) where Value == Bool {
    self.init(wrappedValue: key.defaultValue, key.name)
  }

  init(_ key: StorageKey<Value>) where Value == Double {
    self.init(wrappedValue: key.defaultValue, key.name)
  }

  init(_ key: StorageKey<Value>) where Value == String {
    self.init(wrappedValue: key.defaultValue, key.name)
  }

  init(_ key: StorageKey<Value>) where Value: RawRepresentable,
                                       Value.RawValue == Int {
    self.init(wrappedValue: key.defaultValue, key.name)
  }
}

extension SceneStorage {
  init(_ key: StorageKey<Value>) where Value: RawRepresentable,
                                       Value.RawValue == Int {
    self.init(wrappedValue: key.defaultValue, key.name)
  }
}

enum StorageKeys {
  // MARK: - App
  static let appearance = StorageKey("\(Bundle.appID).appearance", defaultValue: StorageAppearance.automatic)
  static let restoreLastImage = StorageKey("\(Bundle.appID).restore-last-image", defaultValue: true)
  static let margins = StorageKey("\(Bundle.appID).margins", defaultValue: 1.0)
  static let collapseMargins = StorageKey("\(Bundle.appID).collapse-margins", defaultValue: true)
  static let hiddenLayout = StorageKey(
    "\(Bundle.appID).hidden-layout",
    defaultValue: StorageHiddenLayout.cursor,
  )

  static let importHiddenFiles = StorageKey("\(Bundle.appID).import-hidden-files", defaultValue: false)
  static let importSubdirectories = StorageKey("\(Bundle.appID).import-subdirectories", defaultValue: true)
  static let isLiveTextEnabled = StorageKey("\(Bundle.appID).live-text-is-enabled", defaultValue: true)
  static let isLiveTextIconEnabled = StorageKey("\(Bundle.appID).live-text-icon-is-enabled", defaultValue: false)
  static let isLiveTextSubjectEnabled = StorageKey("\(Bundle.appID).live-text-subject-is-enabled", defaultValue: false)
  static let isSystemSearchEnabled = StorageKey(
    "\(Bundle.appID).search-system-is-enabled",
    defaultValue: false,
  )

  static let resolveConflicts = StorageKey("\(Bundle.appID).resolve-conflicts", defaultValue: false)
  static let foldersPathSeparator = StorageKey(
    "\(Bundle.appID).folders-path-separator",
    defaultValue: StorageFoldersPathSeparator.singlePointingAngleQuotationMark
  )

  static let foldersPathDirection = StorageKey(
    "\(Bundle.appID).folders-path-direction",
    defaultValue: StorageFoldersPathDirection.trailing,
  )

  // MARK: - Scene

  static let columnVisibility = StorageKey(
    "\(Bundle.appID).column-visibility",
    defaultValue: StorageColumnVisibility.automatic,
  )

  static let imageAnalysisSupplementaryInterfaceVisibility = StorageKey(
    "\(Bundle.appID).image-analysis-supplementary-interface-visibility",
    defaultValue: StorageVisibility.automatic,
  )

  // MARK: - Support

  static func directoryEnumerationOptions(
    importHiddenFiles: Bool,
    importSubdirectories: Bool,
  ) -> FileManager.DirectoryEnumerationOptions {
    var options = FileManager.DirectoryEnumerationOptions()

    if !importHiddenFiles {
      options.insert(.skipsHiddenFiles)
    }

    if !importSubdirectories {
      options.insert(.skipsSubdirectoryDescendants)
    }

    return options
  }
}

// MARK: - VisionKit

struct ImageAnalysisTypes {
  let rawValue: UInt
}

extension ImageAnalysisTypes: OptionSet {
  static let text = Self(rawValue: ImageAnalyzer.AnalysisTypes.text.rawValue)
  static let visualLookUp = Self(rawValue: ImageAnalyzer.AnalysisTypes.visualLookUp.rawValue)

  var analyzerAnalysisTypes: ImageAnalyzer.AnalysisTypes {
    ImageAnalyzer.AnalysisTypes(rawValue: self.rawValue)
  }
}

extension SchedulerTimeIntervalConvertible {
  static var imagesScrollInteraction: Self {
    .milliseconds(50)
  }

  static var imagesResizeInteraction: Self {
    .milliseconds(200)
  }

  static var imagesHoverInteraction: Self {
    .milliseconds(500)
  }
}
