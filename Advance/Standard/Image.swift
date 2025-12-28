//
//  Image.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/20/23.
//

import AdvanceCore
import ImageIO
import OSLog

typealias MapCF = [CFString : Any]

extension CGImageSource {
  func properties(options: CFDictionary? = nil) -> CFDictionary? {
    properties(at: CGImageSourceGetPrimaryImageIndex(self), options: options)
  }

  func properties(at index: Int, options: CFDictionary? = nil) -> CFDictionary? {
    CGImageSourceCopyPropertiesAtIndex(self, index, options)
  }

  func resample(to size: some Numeric) -> CGImage? {
    resample(to: size, index: CGImageSourceGetPrimaryImageIndex(self))
  }

  func resample(to size: some Numeric, index: Int) -> CGImage? {
    let options: [CFString: Any] = [
      kCGImageSourceThumbnailMaxPixelSize: size,
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true
    ]

    return CGImageSourceCreateThumbnailAtIndex(self, index, options as CFDictionary)
  }
}
