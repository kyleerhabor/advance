//
//  Data+Schema.swift
//  Advance
//
//  Created by Kyle Erhabor on 11/20/25.
//

import CryptoKit
import Foundation

func hash(data: Data) -> Data {
  Data(SHA256.hash(data: data))
}
