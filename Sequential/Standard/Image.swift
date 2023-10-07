//
//  Image.swift
//  Sequential
//
//  Created by Kyle Erhabor on 9/20/23.
//

import ImageIO
import OSLog

extension CGImageSource {
  func resample(to size: some Numeric) throws -> CGImage {
    try resample(to: size, index: CGImageSourceGetPrimaryImageIndex(self))
  }

  func resample(to size: some Numeric, index: Int) throws -> CGImage {
    let options: [CFString : Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceThumbnailMaxPixelSize: size,
      kCGImageSourceCreateThumbnailWithTransform: true
    ]

    guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(self, index, options as CFDictionary) else {
      throw ImageError.thumbnail
    }

    return thumbnail
  }
}

func pixelSizeOfImageProperties(_ properties: Dictionary<CFString, Any>) -> CGSize? {
  guard let width = properties[kCGImagePropertyPixelWidth] as? Int,
        let height = properties[kCGImagePropertyPixelHeight] as? Int else {
    return nil
  }

  return .init(width: width, height: height)
}
