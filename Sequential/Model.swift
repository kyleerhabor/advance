//
//  Model.swift
//  Sequential
//
//  Created by Kyle Erhabor on 7/28/23.
//

import SwiftUI

enum ImageError: Error {
  case undecodable
  case thumbnail
}

func reversedImage(properties: Dictionary<CFString, Any>) -> Bool? {
  guard let raw = properties[kCGImagePropertyOrientation] as? UInt32,
        let orientation = CGImagePropertyOrientation(rawValue: raw) else {
    return nil
  }

  // TODO: Cover other orientations.
  return orientation == .right
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

enum ExecutionError: Error {
  case interrupt
}

struct Keys {
  static let appearance = Item("appearance", nil as SettingsView.Scheme)
  static let margin = Item("margin", 1)
  static let collapseMargins = Item("collapseMargins", true)
  static let windowless = Item("windowless", false)
  static let displayTitleBarImage = Item("displayTitleBarImage", true)
  // I think enabling Live Text by default but disabling the icons strikes a nice compromise between convenience (e.g.
  // being able to select text) and UI simplicity (i.e. not having the buttons get in the way).
  static let liveText = Item("liveText", true)
  static let liveTextIcon = Item("liveTextIcon", false)

  struct Item<Key, Value> {
    let key: Key
    let value: Value

    init(_ key: Key, _ value: Value) {
      self.key = key
      self.value = value
    }
  }
}
