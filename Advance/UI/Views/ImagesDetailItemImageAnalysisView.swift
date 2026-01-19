//
//  ImagesDetailItemImageAnalysisView.swift
//  Advance
//
//  Created by Kyle Erhabor on 1/10/26.
//

import SwiftUI
import VisionKit

struct ImagesDetailItemImageAnalysisView: View {
  @Environment(ImagesModel.self) private var images
  @Environment(SearchSettingsModel.self) private var search
  @Environment(\.locale) private var locale
  @Environment(\.openURL) private var openURL
  @AppStorage(StorageKeys.isLiveTextEnabled) private var isLiveTextEnabled
  @AppStorage(StorageKeys.isLiveTextSubjectEnabled) private var isLiveTextSubjectEnabled
  @AppStorage(StorageKeys.isSystemSearchEnabled) private var isSystemSearchEnabled
  @Binding var searchError: ImagesModelEngineURLError?
  @Binding var isSearchErrorPresented: Bool
  let item: ImagesItemModel2
  let isSupplementaryInterfaceVisible: Bool
  private var preferredInteractionTypes: ImageAnalysisOverlayView.InteractionTypes {
    var interactionTypes = ImageAnalysisOverlayView.InteractionTypes()

    if self.isLiveTextEnabled && self.item.detailImage.phase == .success {
      interactionTypes.insert(.automaticTextOnly)

      if self.isLiveTextSubjectEnabled {
        interactionTypes.insert(.automatic)
      }
    }

    return interactionTypes
  }

  var body: some View {
    @Bindable var item = self.item

    ImageAnalysisView(
      isSelectableItemsHighlighted: $item.isImageAnalysisSelectableItemsHighlighted,
      analysis: item.imageAnalysis,
      preferredInteractionTypes: self.preferredInteractionTypes,
      isSupplementaryInterfaceHidden: !self.isSupplementaryInterfaceVisible,
    ) { delegate, menu, overlayView in
      let copyImage = menu.indexOfItem(withTag: ImageAnalysisOverlayView.MenuTag.copyImage)

      if copyImage != -1 {
        menu.removeItem(at: copyImage)
      }

      let shareImage = menu.indexOfItem(withTag: ImageAnalysisOverlayView.MenuTag.shareImage)

      if shareImage != -1 {
        menu.removeItem(at: shareImage)
      }

      if !self.isSystemSearchEnabled {
        let index = menu.items.firstIndex { $0.identifier == NSMenuItem.search }

        if let index {
          if let engine = self.search.engine {
            let item = NSMenuItem()
            item.title = String(localized: "Images.Item.LiveText.Search.\(engine.name)", locale: self.locale)
            item.target = delegate
            item.action = #selector(delegate.action(_:))
            delegate.actions[item] = {
              Task {
                let url: URL?

                do {
                  url = try await self.images.url(
                    engine: engine.id,
                    query: overlayView.selectedText,
                    locale: self.locale,
                  )
                } catch let error as ImagesModelEngineURLError {
                  self.searchError = error
                  self.isSearchErrorPresented = true

                  return
                }

                guard let url else {
                  return
                }

                self.openURL(url)
              }
            }

            menu.items[index] = item
          } else {
            menu.removeItem(at: index)
          }
        }
      }

      return menu
    }
  }
}
