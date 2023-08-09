//
//  CollectionView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/7/23.
//

import SwiftUI

// TODO: Try playing around with NSTableView

// This implementation is mostly based on this article: https://defagos.github.io/swiftui_collection_part2/

//struct CollectionRow<Item>: Hashable where Item: Hashable {
//  let items: [Item]
//}

extension NSHostingController {
  convenience public init(rootView: Content, ignoreSafeArea: Bool) {
    self.init(rootView: rootView)

    if ignoreSafeArea {
      disableSafeArea()
    }
  }

  func disableSafeArea() {
    guard let viewClass = object_getClass(view) else {
      return
    }

    let viewSubclassName = String(cString: class_getName(viewClass)).appending("_IgnoreSafeArea")

    if let viewSubclass = NSClassFromString(viewSubclassName) {
      object_setClass(view, viewSubclass)
    }

    else {
      guard let viewClassNameUtf8 = (viewSubclassName as NSString).utf8String else {
        return
      }

      guard let viewSubclass = objc_allocateClassPair(viewClass, viewClassNameUtf8, 0) else {
        return
      }

      if let method = class_getInstanceMethod(NSView.self, #selector(getter: NSView.safeAreaInsets)) {
        let safeAreaInsets: @convention(block) (AnyObject) -> NSEdgeInsets = { _ in
          return .init()
        }

        class_addMethod(
          viewSubclass,
          #selector(getter: NSView.safeAreaInsets),
          imp_implementationWithBlock(safeAreaInsets),
          method_getTypeEncoding(method)
        )
      }

      objc_registerClassPair(viewSubclass)
      object_setClass(view, viewSubclass)
    }
  }
}

class RealCollectionView: NSCollectionView {
  override func scrollWheel(with event: NSEvent) {
    return
  }
}

struct CollectionView<Item, Content>: NSViewRepresentable where Item: Hashable, Content: View {
  typealias NSViewType = NSCollectionView
  typealias Section = Int
  typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

  private let id = NSUserInterfaceItemIdentifier(rawValue: "item")

  let rows: [Item]
  let layout: NSCollectionViewCompositionalLayout
  @ViewBuilder let content: (Item) -> Content

  func makeNSView(context: Context) -> NSViewType {
    let collectionView = RealCollectionView(frame: .zero)
    collectionView.backgroundColors = [.clear]
    collectionView.collectionViewLayout = layout
    // "Self.Item.self" lol
    collectionView.register(Self.Item.self, forItemWithIdentifier: id)

    context.coordinator.dataSource = .init(collectionView: collectionView) { collectionView, index, iitem in
      let item = collectionView.makeItem(withIdentifier: self.id, for: index) as! Self.Item
      item.content = content(iitem)

      return item
    }

    return collectionView
  }

  func updateNSView(_ nsView: NSViewType, context: Context) {
    let coordinator = context.coordinator
    coordinator.layout = layout

    let source = coordinator.dataSource!

    // Should we store a prior hash to determine whether or not the views have updated (to improve performance by a bit)?
    source.apply(snapshot())
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func snapshot() -> Snapshot {
    var snapshot = Snapshot()

    snapshot.appendSections([0])
    snapshot.appendItems(rows)

    return snapshot
  }

  class Coordinator {
    var dataSource: NSCollectionViewDiffableDataSource<Section, Item>?
    var layout: NSCollectionViewCompositionalLayout?
  }

  class Item: NSCollectionViewItem {
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
          hostingView.frame = self.view.bounds
//          hostingView.autoresizingMask = [.minXMargin, .minYMargin]
          hostingView.translatesAutoresizingMaskIntoConstraints = false

          self.view.addSubview(hostingView)
        }
      }
    }
  }
}

#Preview {
  let itemSize = NSCollectionLayoutSize(
    widthDimension: .fractionalWidth(1),
    heightDimension: .fractionalHeight(1)
  )
  let groupSize = NSCollectionLayoutSize(
    widthDimension: .absolute(300),
    heightDimension: .absolute(180)
  )

  let item = NSCollectionLayoutItem(layoutSize: itemSize)
  let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
  let section = NSCollectionLayoutSection(group: group)
  section.orthogonalScrollingBehavior = .continuous

  let layout = NSCollectionViewCompositionalLayout(section: section)

  return NavigationSplitView {
    
  } detail: {
    ScrollView {
      CollectionView(rows: [1, 2, 3, 4, 5], layout: layout) { item in
        Text("\(item)")
      }
    }
  }
}

//class CollectionViewItem<Content>: NSCollectionViewItem where Content: View {
//  func setView(to contentView: Content) {
//    let layer = CALayer()
//    layer.borderWidth = 1
//    layer.borderColor = NSColor.red.cgColor
//
//    self.view.wantsLayer = true
//    self.view.layer = layer
//
//    let hostingView = NSHostingView(rootView: contentView)
//    hostingView.translatesAutoresizingMaskIntoConstraints = false
//
//    self.view.addSubview(hostingView)
//
//    NSLayoutConstraint.activate([
//      hostingView.widthAnchor.constraint(equalTo: self.view.widthAnchor),
//      hostingView.heightAnchor.constraint(equalTo: self.view.heightAnchor)
//    ])
//  }
//}
//
//struct CollectionView<Data, ID, Content>: NSViewRepresentable where Data: RandomAccessCollection, ID: Hashable, Content: View {
//  typealias NSViewType = NSCollectionView
//  typealias Data = ForEach<Data, ID, Content>
//
//  private let id = NSUserInterfaceItemIdentifier(rawValue: UUID().uuidString)
//
//  @ViewBuilder var content: () -> Self.Data
//
//  func makeNSView(context: Context) -> NSViewType {
//    let collectionView = NSCollectionView(/*frame: .init(origin: .zero, size: size)*/)
//    collectionView.dataSource = context.coordinator
//
//    let layer = CALayer()
//    layer.borderWidth = 1
//    layer.borderColor = NSColor.red.cgColor
//
//    collectionView.wantsLayer = true
//    collectionView.layer = layer
//
//    collectionView.backgroundColors = [.clear]
//
//
//    let itemSize = NSCollectionLayoutSize(
//      widthDimension: .fractionalWidth(100),
//      heightDimension: .fractionalHeight(50)
//    )
//
//    let groupSize = NSCollectionLayoutSize(
//      widthDimension: .fractionalWidth(100),
//      heightDimension: .fractionalHeight(50)
//    )
//    let size = NSCollectionLayoutSize(widthDimension: .absolute(100), heightDimension: .absolute(100))
//
//    let item = NSCollectionLayoutItem(layoutSize: itemSize)
//    let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
//    let section = NSCollectionLayoutSection(group: group)
//    let layout = NSCollectionViewCompositionalLayout(section: section)
//
//    collectionView.collectionViewLayout = layout
//    // Interestingly, it seems like this call has to be last (else an assertion error occurs).
//    collectionView.register(CollectionViewItem<Content>.self, forItemWithIdentifier: id)
//
//    return collectionView
//  }
//
//  func updateNSView(_ nsView: NSViewType, context: Context) {}
//
//  func makeCoordinator() -> Coordinator {
//    Coordinator(id: id, view: content())
//  }
//
//  class Coordinator: NSObject, NSCollectionViewDataSource {
//    private let id: NSUserInterfaceItemIdentifier
//    var view: CollectionView.Data
//
//    init(id: NSUserInterfaceItemIdentifier, view: CollectionView.Data) {
//      self.id = id
//      self.view = view
//    }
//
//    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
//      view.data.count
//    }
//
//    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
//      let item = collectionView.makeItem(withIdentifier: id, for: indexPath) as! CollectionViewItem<Content>
//      let index = indexPath.item as! Data.Index
////      let data = view.data[index]
////      item.setView(to: view.content(data))
//
//      return item
//    }
//  }
//}
