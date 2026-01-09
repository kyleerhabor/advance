//
//  ImageCollectionSidebarContentView.swift
//  Advance
//
//  Created by Kyle Erhabor on 10/11/23.
//

import OSLog
import SwiftUI

struct ImageCollectionSidebarContentView: View {
  @Environment(ImageCollection.self) private var collection

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(collection.images) { image in
          Color.clear
        }
//        .onMove { from, to in
//          collection.order.elements.move(fromOffsets: from, toOffset: to)
//          collection.update()
//
//          Task(priority: .medium) {
//            do {
//              try await collection.persist(id: id)
//            } catch {
//              Logger.model.error("Could not persist image collection \"\(id)\" (via sidebar image move): \(error)")
//            }
//          }
//        }
//        // This adds a "Delete" menu item under Edit.
//        .onDelete { offsets in
//          collection.order.elements.remove(atOffsets: offsets)
//          collection.update()
//
//          Task(priority: .medium) {
//            do {
//              try await collection.persist(id: id)
//            } catch {
//              Logger.model.error("Could not persist image collection \"\(id)\" (via menu bar delete): \(error)")
//            }
//          }
//        }
      }
//      .onDeleteCommand {
//        collection.order.subtract(selection)
//        collection.update()
//
//        Task(priority: .medium) {
//          do {
//            try await collection.persist(id: id)
//          } catch {
//            Logger.model.error("Could not persist image collection \"\(id)\" (via delete key): \(error)")
//          }
//        }
//      }
    }
  }
}
