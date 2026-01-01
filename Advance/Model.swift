//
//  Model.swift
//  Advance
//
//  Created by Kyle Erhabor on 7/28/23.
//

import Defaults
import SwiftUI

enum ImageError: Error {
  case undecodable
  case thumbnail
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

enum ResultPhaseItem {
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

extension ResultPhaseItem: Equatable {}

extension Defaults.Keys {
  // Live Text
  static let liveTextDownsample = Key("liveTextDownsample", default: false)
}
