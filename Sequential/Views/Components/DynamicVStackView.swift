//
//  DynamicVStackView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/8/23.
//

import SwiftUI

struct DynamicVStackView<Data, Content>: NSViewRepresentable where Data: Hashable, Content: View {
  typealias Section = Int
  typealias Snapshot = NSDiffableDataSourceSnapshot<DynamicVStackView.Section, Data>
  typealias ContentBuilder = (Data) -> Content

  private let id = NSUserInterfaceItemIdentifier(rawValue: "item")
  private let columnId = NSUserInterfaceItemIdentifier(rawValue: "column")

  let data: [Data]
  var content: ContentBuilder

  init(_ data: [Data], @ViewBuilder content: @escaping ContentBuilder) {
    self.data = data
    self.content = content
  }

  func makeNSView(context: Context) -> NSTableView {
    let tableView = NSTableView(frame: .zero)
    tableView.style = .plain
    tableView.addTableColumn(.init(identifier: columnId))
//    tableView.backgroundColor = .clear

    context.coordinator.data = .init(tableView: tableView) { tableView, tableColumn, row, data in
      let cellView = tableView.makeView(withIdentifier: columnId, owner: nil) ?? NSView()

      print(cellView)

      return cellView
    }

    update(tableView: tableView, context: context, animated: false)

    return tableView
  }

  func updateNSView(_ nsView: NSTableView, context: Context) {
    update(tableView: nsView, context: context, animated: true)
  }

  func makeCoordinator() -> Coordinator { .init() }

  func snapshot() -> Snapshot {
    var snapshot = Snapshot()
    snapshot.appendSections([0])
    snapshot.appendItems(data, toSection: 0)

    return snapshot
  }

  func update(tableView: NSTableView, context: Context, animated: Bool = false) {
    let coord = context.coordinator
    let hash = data.hashValue

    guard coord.hash != hash,
          let source = coord.data else {
      return
    }

    source.apply(snapshot(), animatingDifferences: animated)

    coord.hash = hash

    tableView.reloadData()
  }

  class Coordinator {
    var data: NSTableViewDiffableDataSource<DynamicVStackView.Section, Data>?
    var hash: Int?
  }

//  class Delegate: NSObject, NSTableViewDelegate {
//
//  }

  class CellView: NSTableCellView {
    private var controller: NSHostingController<Content>?

    override func prepareForReuse() {
      if let view = controller?.view {
        view.removeFromSuperview()
      }

      controller = nil
    }

    var content: Content? {
      willSet {
        guard let view = newValue else {
          return
        }

        controller = NSHostingController(rootView: view, ignoreSafeArea: true)

        if let hostingView = controller?.view {
          hostingView.frame = self.bounds
          hostingView.autoresizingMask = [.width, .height]

          self.addSubview(hostingView)
        }
      }
    }
  }
}

#Preview {
  // Interestingly, the dynamic VStack is being rendered, but the contents are not (even though they clearly should be,
  // given they exist in the space on the preview canvas). What's interesting, however, is the content builder is not
  // being called.
  DynamicVStackView([1, 2, 3, 4, 5, 6, 7, 8]) { number in
    Text("\(number)...")
  }
}
