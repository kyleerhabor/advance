//
//  ImageCollection.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/17/23.
//

import Foundation
import Observation

extension URL {
  static let collectionDirectory = Self.dataDirectory.appending(component: "Collections")
}

@Observable
class ImageCollectionItemImage {}

@Observable
class ImageCollection {
  // The materialized state for the UI.
  var images = [ImageCollectionItemImage]()
}
