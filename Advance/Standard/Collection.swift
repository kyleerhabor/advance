//
//  Collection.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/29/24.
//

import OrderedCollections

extension OrderedSet {
  mutating func appended(_ items: some Sequence<Element>) {
    self.subtract(items)
    self.append(contentsOf: items)
  }
}
