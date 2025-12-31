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
    CGImageSourceCopyPropertiesAtIndex(self, CGImageSourceGetPrimaryImageIndex(self), options)
  }

  func resample(to size: some Numeric) -> CGImage? {
    let options: [CFString: Any] = [
      kCGImageSourceThumbnailMaxPixelSize: size,
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true
    ]

    return CGImageSourceCreateThumbnailAtIndex(self, CGImageSourceGetPrimaryImageIndex(self), options as CFDictionary)
  }
}
