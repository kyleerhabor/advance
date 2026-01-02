//
//  ImageCollectionCommands.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/18/23.
//

import SwiftUI

struct ImageCollectionCommands: Commands {
  var body: some Commands {
    ImageCollectionEditCommands()
    ImageCollectionNavigatorCommands()
  }
}
