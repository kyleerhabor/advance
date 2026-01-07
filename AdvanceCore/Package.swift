// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "AdvanceCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(
      name: "AdvanceCore",
      targets: ["AdvanceCore"],
    ),
  ],
  targets: [
    .target(
      name: "AdvanceCore",
    ),
  ],
  swiftLanguageModes: [.v6],
)
