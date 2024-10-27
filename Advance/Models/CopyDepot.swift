//
//  CopyDepot.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/27/23.
//

import AdvanceCore
import Algorithms
import OSLog
import SwiftUI

struct CopyDepotItemDestination {
  let id: BookmarkStoreItem.ID
  let url: URL
  let path: URL
  let icon: Image

  var string: AttributedString {
    Self.format(components: path.pathComponents.dropFirst())
  }

  static func normalize(url: URL) -> URL {
    url
  }

  static func format(components: some Sequence<String>) -> AttributedString {
    var separator = AttributedString(" 􀰇 ")

    return components
      .map { AttributedString($0) }
      .interspersed(with: separator)
      .reduce(into: .init(), +=)
  }

  static func format(url: URL) -> AttributedString {
    format(components: normalize(url: url).pathComponents.dropFirst())
  }
}

extension CopyDepotItemDestination: Identifiable {}

extension CopyDepotItemDestination: Equatable {
  static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}

struct CopyDepotItemResolution {
  let resolved: Bool
  let destination: CopyDepotItemDestination
}

extension CopyDepotItemResolution: Equatable {}

extension CopyDepotItemResolution: Identifiable {
  var id: BookmarkStoreItem.ID { destination.id }
}

struct CopyDepotItem {
  let url: URL
  let bookmark: BookmarkStoreItem.ID
  let resolved: Bool
}

extension CopyDepotItem: Codable {
  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let url = try container.decode(URL.self, forKey: .url)
    let bookmark = try container.decode(BookmarkStoreItem.ID.self, forKey: .bookmark)

    self.url = url
    self.bookmark = bookmark
    self.resolved = false
  }

  enum CodingKeys: CodingKey {
    // We're coding in the URL so we can still display it if it can't be resolved.
    case url
    case bookmark
  }
}

extension URL {
  static let copyDepotFile = URL.dataDirectory
    .appending(component: "CopyDepot")
    .appendingPathExtension(for: .binaryPropertyList)
}

@Observable
class CopyDepot: Codable {
  static let encoder = PropertyListEncoder()
  static let decoder = PropertyListDecoder()

  @ObservationIgnored var store = BookmarkStore()
  @ObservationIgnored var items = [BookmarkStoreItem.ID: CopyDepotItem]()

  var main = [CopyDepotItemDestination]()
  var settings = [CopyDepotItemResolution]()

  init() {
    Task {
      let url = URL.copyDepotFile
      let depot: CopyDepot

      do {
        depot = try await fetch(from: url)
      } catch let err as CocoaError where err.code == .fileReadNoSuchFile {
        Logger.model.info("Could not fetch copy depot from URL \"\(url.pathString)\" as the file does not exist yet.")

        return
      } catch {
        Logger.model.error("Could not fetch copy depot from URL \"\(url.pathString)\": \(error)")

        return
      }

      self.store = depot.store
      self.items = depot.items

      let state = await resolve(in: store)

      self.store = state.store
      apply(ids: state.value)
      update()

      Task(priority: .medium) {
        await self.persist()
      }
    }
  }

  func fetch(from url: URL) async throws -> Self {
    let data = try Data(contentsOf: url)
    let decoded = try Self.decoder.decode(Self.self, from: data)

    return decoded
  }

  typealias IDs = Set<BookmarkStoreItem.ID>

  func resolve(in store: BookmarkStore) async -> BookmarkStoreState<IDs> {
    await withThrowingTaskGroup(of: Pair<BookmarkStoreItem.ID, URLBookmark>.self) { group in
      let bookmarks = items.values.compactMap { item in
        store.bookmarks[item.bookmark]
      }

      bookmarks.forEach { bookmark in
        group.addTask {
          let data = bookmark.bookmark
          let resolved = try BookmarkStoreItem.resolve(data: data.data, options: data.options, relativeTo: nil)

          return .init(
            left: bookmark.id,
            right: .init(
              url: resolved.url,
              bookmark: .init(data: resolved.data, options: data.options)
            )
          )
        }
      }

      var store = store
      var ids = IDs(minimumCapacity: bookmarks.count)

      while let result = await group.nextResult() {
        switch result {
          case .success(let pair):
            let id = pair.left
            let union = pair.right

            ids.insert(id)

            let bookmark = union.bookmark
            let item = BookmarkStoreItem(id: id, bookmark: bookmark, relative: nil)

            store.register(item: item)
            store.urls[item.hash] = union.url
          case .failure(let err as CocoaError) where err.code == .fileNoSuchFile:
            Logger.model.info("Could not resolve copy depot item as its file does not exist. Is it temporarily unavailable?")
          case .failure(let err):
            Logger.model.error("Could not resolve copy depot item: \(err)")
        }
      }

      return .init(store: store, value: ids)
    }
  }

  func apply(ids: IDs) {
    items = items.mapValues { item in
      guard ids.contains(item.bookmark),
            let bookmark = store.bookmarks[item.bookmark],
            let url = store.urls[bookmark.hash] else {
        return .init(url: item.url, bookmark: item.bookmark, resolved: false)
      }

      return .init(url: url, bookmark: item.bookmark, resolved: true)
    }
  }

  func update() {
    self.main = items.values
      .filter(\.resolved)
      .map { item in
        CopyDepotItemDestination(
          id: item.bookmark,
          url: item.url,
          path: CopyDepotItemDestination.normalize(url: item.url),
          icon: .init(nsImage: NSWorkspace.shared.icon(forFileAt: item.url))
        )
      }.sorted(using: KeyPathComparator(\.path.path))

    self.settings = items.values
      .map { item in
        CopyDepotItemResolution(
          resolved: item.resolved,
          destination: .init(
            id: item.bookmark,
            url: item.url,
            path: CopyDepotItemDestination.normalize(url: item.url),
            icon: item.resolved
            ? .init(nsImage: NSWorkspace.shared.icon(forFileAt: item.url))
            : .init(systemName: "questionmark.circle.fill")
          )
        )
      }.sorted(using: KeyPathComparator(\.destination.path.path))
  }

  func persist(to url: URL) throws {
    let encoded = try CopyDepot.encoder.encode(self)
    let url = URL.copyDepotFile

    try FileManager.default.creatingDirectories(at: url.deletingLastPathComponent(), code: .fileNoSuchFile) {
      try encoded.write(to: url)
    }
  }

  func persist() async {
    do {
      try persist(to: .copyDepotFile)
    } catch {
      Logger.model.error("Could not persist copy depot: \(error)")
    }
  }

  // MARK: - Codable conformance

  required init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let items = try container.decode([CopyDepotItem].self, forKey: .items)

    self.store = try container.decode(BookmarkStore.self, forKey: .store)
    self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.bookmark, $0) })
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(store, forKey: .store)
    try container.encode(Array(items.values), forKey: .items)
  }

  enum CodingKeys: CodingKey {
    case store, items
  }
}
