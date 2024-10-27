//
//  ImageCollectionManager.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/20/23.
//

import SwiftUI

@MainActor @Observable
class ImageCollectionManager {
  var collections = [UUID: ImageCollection]()
  var ids = Set<UUID>()
}
