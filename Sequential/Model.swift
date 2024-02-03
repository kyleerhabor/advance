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
  
  private static var unknownRaw: Int { -1 }
  private static var allRaw: Int { 1 }
  private static var detailOnlyRaw: Int { 3 }

  public init?(rawValue: RawValue) {
    switch rawValue {
      case Self.allRaw: self = .all
      case Self.detailOnlyRaw: self = .detailOnly
      default: return nil
    }
  }

  public var rawValue: RawValue {
    switch self {
      case .all: Self.allRaw
      case .detailOnly: Self.detailOnlyRaw
      default: Self.unknownRaw
    }
  }
}

struct Keys {
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

enum ResultPhase<Success, Failure> where Failure: Error {
  case empty
  case result(Result<Success, Failure>)

  var success: Success? {
    guard case let .result(result) = self,
          case let .success(success) = result else {
      return nil
    }

    return success
  }

  var failure: Failure? {
    guard case let .result(result) = self,
          case let .failure(failure) = result else {
      return nil
    }

    return failure
  }

  init(success: Success) {
    self = .result(.success(success))
  }
}

extension ResultPhase: Equatable where Success: Equatable, Failure: Equatable {}

enum ResultPhaseItem: Equatable {
  case empty, success, failure

  init(_ phase: ImageResamplePhase) {
    switch phase {
      case .empty: self = .empty
      case .result(let result):
        switch result {
          case .success: self = .success
          case .failure: self = .failure
        }
    }
  }
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
  static let margins = Key("margins", default: 1)
  static let collapseMargins = Key("collapseMargins", default: true)

  // Live Text
  static let liveText = Key("liveText", default: true)
  static let liveTextIcon = Key("liveTextIcon", default: false)
  static let liveTextSearchWith = Key("liveTextSearchWith", default: false)
  static let liveTextDownsample = Key("liveTextDownsample", default: false)

  // Visibility
  static let displayTitleBarImage = Key("displayTitleBarImage", default: true)
  static let hideToolbarScrolling = Key("hideToolbarScrolling", default: false)
  static let hideCursorScrolling = Key("hideCursorScrolling", default: false)
  static let hideScrollIndicator = Key("hideScrollIndicator", default: false)

  // Copying
  static let resolveCopyingConflicts = Key("resolveCopyingConflicts", default: true)

  // Importing
  static let importHiddenFiles = Key("importHiddenFiles", default: false)
  static let importSubdirectories = Key("importSubdirectories", default: true)
}
