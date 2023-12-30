//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import Defaults
import SwiftUI

enum ImageError: Error {
  case undecodable
  case thumbnail
}

extension NavigationSplitViewVisibility: RawRepresentable {
  public typealias RawValue = Int

  public init?(rawValue: RawValue) {
    switch rawValue {
      case 0: self = .all
      case 1: self = .detailOnly
      default: return nil
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .all: 0
      case .detailOnly: 1
      default: -1
    }
  }
}

struct Keys {
  static let margin = Item("margin", 1)
  static let displayTitleBarImage = Item("displayTitleBarImage", true)
  
  static let brightness = Item("brightness", 0.0)
  static let grayscale = Item("grayscale", 0.0)

  struct Item<Key, Value> {
    let key: Key
    let value: Value

    init(_ key: Key, _ value: Value) {
      self.key = key
      self.value = value
    }
  }
}

extension URL {
  static let dataDirectory = Self.applicationSupportDirectory.appending(component: Bundle.identifier)
}

enum ColorScheme: Int {
  case system, light, dark

  var appearance: NSAppearance? {
    switch self {
      case .light: .init(named: .aqua)
      case .dark: .init(named: .darkAqua)
      default: nil
    }
  }
}

extension ColorScheme: Defaults.Serializable {}

extension Defaults.Keys {
  // Appearance
  static let colorScheme = Key("colorscheme", default: ColorScheme.system)
  static let collapseMargins = Key("collapseMargins", default: true)

  // Live Text
  static let liveText = Key("liveText", default: true)
  static let liveTextIcon = Key("liveTextIcon", default: false)
  static let liveTextSearchWith = Key("liveTextSearchWith", default: false)

  // Visibility
  static let hideToolbarScrolling = Key("hideToolbarScrolling", default: false)
  static let hideCursorScrolling = Key("hideCursorScrolling", default: false)
  static let hideScrollIndicator = Key("hideScrollIndicator", default: false)

  // Copying
  static let resolveCopyingConflicts = Key("resolveCopyingConflicts", default: true)

  // Importing
  static let importHiddenFiles = Key("importHiddenFiles", default: false)
  static let importSubdirectories = Key("importSubdirectories", default: true)
}
