//
//  UI+Core.swift
//  Advance
//
//  Created by Kyle Erhabor on 6/29/24.
//

import AdvanceCore
import SwiftUI
import Combine
import Defaults
import UniformTypeIdentifiers

let imagesContentTypes: [UTType] = [.image, .folder]
let foldersContentTypes: [UTType] = [.folder]

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

// MARK: - Defaults

enum DefaultColorScheme: Int {
  case system, light, dark

  var appearance: NSAppearance? {
    switch self {
      case .light: NSAppearance(named: .aqua)
      case .dark: NSAppearance(named: .darkAqua)
      default: nil
    }
  }
}

extension DefaultColorScheme: Defaults.Serializable {}

struct DefaultSearchEngine {
  typealias ID = UUID

  let id: UUID
  let name: String
  let string: String
}

extension DefaultSearchEngine: Codable, Defaults.Serializable {}

extension Defaults.Keys {
  static let colorScheme = Key("color-scheme", default: DefaultColorScheme.system)

  static let searchEngine = Key("search-engine", default: nil as DefaultSearchEngine.ID?)
  static let searchEngines = Key("search-engines", default: [DefaultSearchEngine]())
}

// MARK: - Storage

extension Visibility {
  init(_ value: Bool) {
    switch value {
      case true: self = .visible
      case false: self = .hidden
    }
  }
}

struct StorageVisibility {
  let visibility: Visibility
}

extension StorageVisibility {
  init(_ visibility: Visibility) {
    self.init(visibility: visibility)
  }
}

extension StorageVisibility: RawRepresentable {
  private static let automatic = 0
  private static let visible = 1
  private static let hidden = 2

  var rawValue: Int {
    switch visibility {
      case .automatic: Self.automatic
      case .visible: Self.visible
      case .hidden: Self.hidden
    }
  }

  init(rawValue: Int) {
    let visibility: Visibility = switch rawValue {
      case Self.automatic: .automatic
      case Self.visible: .visible
      case Self.hidden: .hidden
      default: fatalError()
    }

    self.init(visibility: visibility)
  }
}

struct StorageColumnVisibility {
  let columnVisibility: NavigationSplitViewVisibility
}

extension StorageColumnVisibility {
  init(_ columnVisibility: NavigationSplitViewVisibility) {
    self.init(columnVisibility: columnVisibility)
  }
}

extension StorageColumnVisibility: RawRepresentable {
  private static let unknown = -1
  private static let automatic = 0
  private static let all = 1
  private static let detailOnly = 2
  private static let doubleColumn = 3

  var rawValue: Int {
    switch columnVisibility {
      case .automatic: Self.automatic
      case .all: Self.all
      case .detailOnly: Self.detailOnly
      case .doubleColumn: Self.doubleColumn
      default: Self.unknown
    }
  }

  init?(rawValue: Int) {
    let columnVisibility: NavigationSplitViewVisibility

    switch rawValue {
      case Self.unknown:
        return nil
      case Self.automatic:
        columnVisibility = .automatic
      case Self.all:
        columnVisibility = .all
      case Self.detailOnly:
        columnVisibility = .detailOnly
      case Self.doubleColumn:
        columnVisibility = .doubleColumn
      default:
        unreachable()
    }

    self.init(columnVisibility: columnVisibility)
  }
}

enum StorageDirection: Int {
  case leftToRight, rightToLeft
}

extension SetAlgebra {
  func value(_ value: Bool, for set: Self) -> Self {
    value ? self.union(set) : self.subtracting(set)
  }
}

struct StorageHiddenLayoutStyles: OptionSet {
  let rawValue: Int

  static let toolbar = Self(rawValue: 1 << 0)
  static let cursor = Self(rawValue: 1 << 1)
  static let scroll = Self(rawValue: 1 << 2)

  // Is there a better way to represent this?

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

struct StorageFoldersSeparatorItem {
  let forward: Character
  let back: Character

  func separator(direction: StorageDirection) -> Character {
    switch direction {
      case .leftToRight: forward
      case .rightToLeft: back
    }
  }
}

enum StorageFoldersSeparator: Int {
  case inequalitySign,
       singlePointingAngleQuotationMark,
       blackPointingTriangle,
       blackPointingSmallTriangle

  var separator: StorageFoldersSeparatorItem {
    switch self {
      case .inequalitySign: StorageFoldersSeparatorItem(forward: ">", back: "<")
      case .singlePointingAngleQuotationMark: StorageFoldersSeparatorItem(
        forward: "\u{203A}", // ›
        back: "\u{2039}" // ‹
      )
      case .blackPointingTriangle: StorageFoldersSeparatorItem(
        forward: "\u{25B6}", // ▶
        back: "\u{25C0}" // ◀
      )
      case .blackPointingSmallTriangle: StorageFoldersSeparatorItem(
        forward: "\u{25B8}", // ▸
        back: "\u{25C2}" // ◂
      )
    }
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

enum StorageKeys {
  static let columnVisibility = StorageKey(
    "\(Bundle.appID).column-visibility",
    defaultValue: StorageColumnVisibility(.all),
  )

  static let importHiddenFiles = StorageKey("\(Bundle.appID).import-hidden-files", defaultValue: false)
  static let importSubdirectories = StorageKey("\(Bundle.appID).import-subdirectories", defaultValue: true)
  static let hiddenLayoutStyles = StorageKey(
    "\(Bundle.appID).hidden-layout-styles",
    defaultValue: StorageHiddenLayoutStyles.cursor,
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

  static let restoreLastImage = StorageKey("restore-last-image", defaultValue: true)
  static let liveTextEnabled = StorageKey("live-text-is-enabled", defaultValue: true)
  static let liveTextIcon = StorageKey("live-text-is-icon-visible", defaultValue: false)
  static let liveTextIconVisibility = StorageKey("live-text-icon-visibility", defaultValue: StorageVisibility(.automatic))
  static let liveTextSubject = StorageKey("live-text-is-subject-highlighted", defaultValue: false)
  static let searchUseSystemDefault = StorageKey("search-use-system-default", defaultValue: false)

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

extension AppStorage {
  init(_ key: StorageKey<Value>) where Value == Bool {
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
