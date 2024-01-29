//
//  Collection.swift
//  Sequential
//
//  Created by Kyle Erhabor on 1/29/24.
//

import OrderedCollections

extension OrderedSet {
  /// Append a member to the end of the set, moving its existing entry if the set already contains it.
  mutating func appended(_ item: Element) {
    if self.append(item).inserted {
      return
    }

    self.remove(item)
    self.append(item)
  }

  mutating func appended(_ items: some Sequence<Element>) {
    self.subtract(items)
    self.append(contentsOf: items)
  }
}
