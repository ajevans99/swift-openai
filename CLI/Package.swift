// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-openai-cli",
  platforms: [
    .macOS(.v14)
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    .package(
      url: "https://github.com/swift-server/swift-openapi-async-http-client.git", from: "1.1.0"),
    .package(url: "https://github.com/thebarndog/swift-dotenv.git", from: "2.1.0"),
    .package(name: "swift-openai", path: "../"),
  ],
  targets: [
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "OpenAICLI",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "OpenAI", package: "swift-openai"),
        .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
        .product(name: "SwiftDotenv", package: "swift-dotenv"),
      ]
    )
  ]
)
