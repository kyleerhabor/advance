//
//  FoldersSettingsModel2.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/26/25.
//

import AdvanceData
import Foundation
import GRDB
import IdentifiedCollections
import Observation
import OSLog

struct FoldersSettingsModelLoadFolderInfo {
  let folder: FolderRecord
}

extension FoldersSettingsModelLoadFolderInfo: Decodable {
  enum CodingKeys: CodingKey {
    case folder
  }
}

extension FoldersSettingsModelLoadFolderInfo: Equatable, FetchableRecord {}

@Observable
@MainActor
final class FoldersSettingsItemModel {
  let id: RowID

  init(id: RowID) {
    self.id = id
  }
}

extension FoldersSettingsItemModel: Identifiable {}

@Observable
@MainActor
final class FoldersSettingsModel2 {
  var items: IdentifiedArrayOf<FoldersSettingsItemModel>
  var isFileImporterPresented = false

  init() {
    self.items = []
  }

  func load() async {
    await _load()
  }

  func store(urls: [URL]) async {
    await _store(urls: urls)
  }

  nonisolated private func load(folder: FoldersSettingsModelLoadFolderInfo?) async {
    guard let folder else {
      return
    }

    Logger.model.debug("Done.")
  }

  nonisolated private func _load() async {
    let observation = ValueObservation
      .trackingConstantRegion { db in
        try FolderRecord
          .select(.rowID)
          .asRequest(of: FoldersSettingsModelLoadFolderInfo.self)
          .fetchOne(db)
      }
      .removeDuplicates()

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      for try await folder in observation.values(in: connection, bufferingPolicy: .bufferingNewest(1)) {
        await load(folder: folder)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func _store(urls: [URL]) async {
    Logger.model.debug("\(urls)")
  }
}
