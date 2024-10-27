//
//  Image.swift
//  Advance
//
//  Created by Kyle Erhabor on 9/20/23.
//

import AdvanceCore
import ImageIO
import OSLog

typealias MapCF = [CFString: Any]

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

struct ImageSize {
  let width: Int
  let height: Int

  var length: Int {
    max(width, height)
  }

  var aspectRatio: Double {
    Double(width) / Double(height)
  }
}

extension ImageSize {
  init?(from props: MapCF) {
    guard let width = props[kCGImagePropertyPixelWidth] as? Int,
          let height = props[kCGImagePropertyPixelHeight] as? Int else {
      return nil
    }

    self.init(width: width, height: height)
  }
}

struct ImageProperties {
  let size: ImageSize
  let orientation: CGImagePropertyOrientation

  var sized: ImageSize {
    guard orientation.isReflected else {
      return size
    }

    return .init(width: size.height, height: size.width)
  }
}

extension ImageProperties {
  init?(from props: MapCF) {
    guard let size = ImageSize(from: props) else {
      return nil
    }

    let orientation = (props[kCGImagePropertyOrientation] as? UInt32).flatMap { raw in
      CGImagePropertyOrientation(rawValue: raw)
    } ?? .up

    self.init(size: size, orientation: orientation)
  }
}
