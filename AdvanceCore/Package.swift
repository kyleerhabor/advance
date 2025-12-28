// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "AdvanceCore",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "AdvanceCore", targets: ["AdvanceCore"]),
  ],
  dependencies: [
    .package(url: "https://github.com/leif-ibsen/BigInt.git", revision: "8c6f93aa37504b7b1ba3954335b5548a19fbbd82"),
  ],
  targets: [
    .target(
      name: "AdvanceCore",
      dependencies: [
        .product(name: "BigInt", package: "BigInt"),
      ],
    ),
  ],
  swiftLanguageModes: [.v6],
)
