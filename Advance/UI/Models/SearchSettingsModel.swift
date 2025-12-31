//
//  SearchSettingsModel.swift
//  Advance
//
//  Created by Kyle Erhabor on 12/23/25.
//

import AdvanceCore
import CoreTransferable
import GRDB
import IdentifiedCollections
import Observation
import OSLog
import UniformTypeIdentifiers

extension UTType {
  static let settingsAccessorySearchItem = Self(exportedAs: "com.kyleerhabor.AdvanceSettingsAccessorySearchItem")
}

struct SearchSettingsItemModelID {
  let id: UUID
}

extension SearchSettingsItemModelID: Codable {}

extension SearchSettingsItemModelID: Transferable {
  static var transferRepresentation: some TransferRepresentation {
    CodableRepresentation(contentType: .settingsAccessorySearchItem)
  }
}

@Observable
@MainActor
final class SearchSettingsItemModel {
  nonisolated static let enclosing: Character = "%"
  nonisolated static let queryToken = "\(enclosing)query\(enclosing)"
  let id: UUID
  var rowID: RowID?
  var name: String
  var location: [String]

  init(id: UUID, rowID: RowID?, name: String, location: [String]) {
    self.id = id
    self.rowID = rowID
    self.name = name
    self.location = location
  }

  nonisolated static func tokenize(_ s: String, enclosing: Character = enclosing) -> [String] {
    var iterator = s.makeIterator()
    var tokens = [String]()
    var token = ""

    loop:
    while true {
      while true {
        guard let character = iterator.next() else {
          break loop
        }

        guard character == enclosing else {
          token.append(character)

          continue
        }

        tokens.append(token)

        token = String(character)

        break
      }

      while true {
        guard let character = iterator.next() else {
          break loop
        }

        token.append(character)

        if character == enclosing {
          tokens.append(token)

          break
        }
      }

      token = ""
    }

    tokens.append(token)

    return tokens
  }

  nonisolated static func detokenize(_ tokens: [String]) -> String {
    tokens.joined()
  }
}

extension SearchSettingsItemModel: Identifiable {}

extension SearchSettingsItemModel: @MainActor Equatable {
  static func ==(lhs: SearchSettingsItemModel, rhs: SearchSettingsItemModel) -> Bool {
    lhs.id == rhs.id
  }
}

@Observable
@MainActor
class SearchSettingsEngineModel {
  let id: RowID
  var name: String

  init(id: RowID, name: String) {
    self.id = id
    self.name = name
  }
}

extension SearchSettingsEngineModel: Identifiable {}

struct SearchSettingsModelLoadState {
  let configuration: SearchSettingsModelLoadConfigurationInfo?
  let searchEngines: [SearchSettingsModelLoadSearchEngineInfo]
}

struct SearchSettingsModelMoveLoadState {
  let lower: SearchSettingsModelMoveSearchEngineInfo?
  let upper: SearchSettingsModelMoveSearchEngineInfo?
}

struct SearchSettingsModelMoveStoreState {
  let lower: BigFraction
  let upper: BigFraction
}

@Observable
@MainActor
final class SearchSettingsModel {
  var items: IdentifiedArrayOf<SearchSettingsItemModel>
  var engines: IdentifiedArrayOf<SearchSettingsEngineModel>
  var engine: SearchSettingsEngineModel?
  var selection: SearchSettingsEngineModel.ID?

  init() {
    self.items = []
    self.engines = []
  }

  func load() async {
    await _load()
  }

  func move(items: [SearchSettingsItemModelID], toOffset offset: Int) async {
    // TODO: Make offset respect exists status.
    let item = self.items.indices.contains(offset) ? self.items[offset].id   : nil
    self.items.move(
      fromOffsets: IndexSet(items.map { self.items.index(id: $0.id)! }),
      toOffset: offset,
    )

    await self.move(items: items.compactMap { self.items[id: $0.id]!.rowID }, toOffset: item)
  }

  func add(item: SearchSettingsItemModel) {
    self.items.append(item)
  }

  func remove(items: Set<SearchSettingsItemModel.ID>) async {
    let keys = self.items
      .filter { items.contains($0.id) }
      .compactMap(\.rowID)

    self.items.removeAll { items.contains($0.id) }
    await self.remove(keys: keys)
  }

  func store(item: SearchSettingsItemModel.ID) async {
    let index = self.items.index(id: item)!
    let item = self.items[index]
    let location = SearchSettingsItemModel.detokenize(item.location)

    if let rowID = item.rowID {
      await store(key: rowID, name: item.name, location: location)

      return
    }

    let before = self.items[self.items.startIndex..<index].last { $0.rowID != nil }
    // Yes, the first element is item, which doesn't have a rowID. However, we'd need to use index(after:), which
    // requires that we check that we aren't at the end of the collection.
    let after = self.items[index..<self.items.endIndex].first { $0.rowID != nil }

    guard let rowID = await store(
      name: item.name,
      location: location,
      before: before?.rowID,
      after: after?.rowID,
    ) else {
      return
    }

    item.rowID = rowID
  }

  func storeSelection() async {
    await store(selection: selection)
  }

  private func load(state: SearchSettingsModelLoadState) {
    state.searchEngines.forEach { searchEngine in
      let id = searchEngine.searchEngine.rowID!
      let name = searchEngine.searchEngine.name!
      let location = SearchSettingsItemModel.tokenize(searchEngine.searchEngine.location!)
      // This results in O(n^2), but I don't expect the user to set that many search engines.
      let item = self.items.first { $0.rowID == id }

      guard let item else {
        let item = SearchSettingsItemModel(
          id: UUID(),
          rowID: id,
          name: name,
          location: location,
        )

        self.items.append(item)

        return
      }

      item.name = name
      item.location = location
    }

    let engines = state.searchEngines.map { searchEngine in
      let id = searchEngine.searchEngine.rowID!
      let name = searchEngine.searchEngine.name!

      guard let engine = self.engines[id: id] else {
        let engine = SearchSettingsEngineModel(id: id, name: name)

        return engine
      }

      engine.name = name

      return engine
    }

    self.engines = IdentifiedArray(uniqueElements: engines)
    self.selection = state.configuration?.searchEngine?.searchEngine.rowID
    self.engine = self.selection.flatMap { self.engines[id: $0] }
  }

  nonisolated private func _load() async {
    let observation = ValueObservation
      .trackingConstantRegion { db in
        let configuration = try ConfigurationRecord
          .select(.rowID)
          .including(
            optional: ConfigurationRecord.searchEngine
              .forKey(SearchSettingsModelLoadConfigurationInfo.CodingKeys.searchEngine)
              .select(.rowID),
          )
          .asRequest(of: SearchSettingsModelLoadConfigurationInfo.self)
          .fetchOne(db)

        let searchEngines = try SearchEngineRecord
          .select(.rowID, SearchEngineRecord.Columns.name, SearchEngineRecord.Columns.location)
          .order(SearchEngineRecord.Columns.position)
          .asRequest(of: SearchSettingsModelLoadSearchEngineInfo.self)
          .fetchAll(db)

        return SearchSettingsModelLoadState(configuration: configuration, searchEngines: searchEngines)
      }

    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      for try await state in observation.values(in: connection, bufferingPolicy: .bufferingNewest(1)) {
        await load(state: state)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func move(items: [RowID], toOffset offset: SearchSettingsItemModel.ID?) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    let load: SearchSettingsModelMoveLoadState

    // We could merge these into one write, but if we ever needed to perform work outside the transaction (e.g., resolve
    // bookmarks), we'd need to refactor it.

    if let offset {
      do {
        load = try await connection.read { db in
          let upper = try SearchEngineRecord
            .select(.rowID, SearchEngineRecord.Columns.position)
            .filter(key: offset)
            .asRequest(of: SearchSettingsModelMoveSearchEngineInfo.self)
            .fetchOne(db)

          let lower = try SearchEngineRecord
            .select(.rowID, SearchEngineRecord.Columns.position)
            .filter(SearchEngineRecord.Columns.position < upper?.searchEngine.position)
            .order(SearchEngineRecord.Columns.position.desc)
            .asRequest(of: SearchSettingsModelMoveSearchEngineInfo.self)
            .fetchOne(db)

          let state = SearchSettingsModelMoveLoadState(lower: lower, upper: upper)

          return state
        }
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }
    } else {
      do {
        load = try await connection.read { db in
          let lower = try SearchEngineRecord
            .select(.rowID, SearchEngineRecord.Columns.position)
            .order(SearchEngineRecord.Columns.position.desc)
            .asRequest(of: SearchSettingsModelMoveSearchEngineInfo.self)
            .fetchOne(db)

          let state = SearchSettingsModelMoveLoadState(lower: lower, upper: nil)

          return state
        }
      } catch {
        // TODO: Elaborate.
        Logger.model.error("\(error)")

        return
      }
    }

    let store = SearchSettingsModelMoveStoreState(
      lower: load.lower?.searchEngine.position.flatMap { BigFraction($0) } ?? .zero,
      upper: load.upper?.searchEngine.position.flatMap { BigFraction($0) } ?? .one,
    )

    do {
      try await connection.write { db in
        _ = try items.reduce(store) { store, item in
          let position = store.lower + delta(lowerBound: store.lower, upperBound: store.upper, base: .TEN)
          let item = SearchEngineRecord(
            rowID: item,
            name: nil,
            location: nil,
            position: position.asDecimalString(precision: position.denominator.digitCount(base: .TEN).decremented()),
          )

          try item.update(db, columns: [SearchEngineRecord.Columns.position])

          return SearchSettingsModelMoveStoreState(
            lower: position,
            upper: store.upper,
          )
        }
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func remove(keys: [RowID]) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      try await connection.write { db in
        _ = try SearchEngineRecord.deleteAll(db, keys: keys)
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func store(name: String, location: String, before: RowID?, after: RowID?) async -> RowID? {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }

    do {
      return try await connection.write { db in
        let before = try SearchEngineRecord
          .select(.rowID, SearchEngineRecord.Columns.position)
          .filter(key: before)
          .fetchOne(db)

        let after = try SearchEngineRecord
          .select(.rowID, SearchEngineRecord.Columns.position)
          .filter(key: after)
          .fetchOne(db)

        let beforePosition = before?.position.flatMap { BigFraction($0) } ?? .zero
        let afterPosition = after?.position.flatMap { BigFraction($0) } ?? .one
        let position = beforePosition + delta(lowerBound: beforePosition, upperBound: afterPosition, base: .TEN)
        var item = SearchEngineRecord(
          name: name,
          location: location,
          position: position.asDecimalString(precision: position.denominator.digitCount(base: .TEN).decremented()),
        )

        try item.insert(db)

        return item.rowID
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return nil
    }
  }

  nonisolated private func store(key: RowID, name: String, location: String) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }

    do {
      try await connection.write { db in
        let item = SearchEngineRecord(rowID: key, name: name, location: location, position: nil)
        try item.update(db, columns: [SearchEngineRecord.Columns.name, SearchEngineRecord.Columns.location])
      }
    } catch {
      // TODO: Elaborate.
      Logger.model.error("\(error)")

      return
    }
  }

  nonisolated private func store(selection: SearchSettingsEngineModel.ID?) async {
    let connection: DatabasePool

    do {
      connection = try await databaseConnection()
    } catch {
      Logger.model.error("Could not create database connection for search engine configuration: \(error)")

      return
    }

    do {
      try await connection.write { db in
        var configuration = try ConfigurationRecord.find(db)
        configuration.searchEngine = selection
        try configuration.upsert(db)
      }
    } catch {
      Logger.model.error("Could not write search engine configuration to database: \(error)")

      return
    }
  }
}
