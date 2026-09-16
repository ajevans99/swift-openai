// swift-tools-version: 6.1

import Foundation
import PackageDescription

let responsesRuntime: Package.Dependency
if let path = ProcessInfo.processInfo.environment["OPENAI_RESPONSES_RUNTIME_PATH"] {
  precondition(!path.isEmpty, "OPENAI_RESPONSES_RUNTIME_PATH must name a runtime package checkout.")
  responsesRuntime = .package(name: "swift-openapi-schema-codegen", path: path)
} else {
  responsesRuntime = .package(
    url: "https://github.com/ajevans99/swift-openapi-schema-codegen",
    revision: "1418f16c89d9a8d41193b21455c5339ec1e22aba"
  )
}

let jsonSchemaRuntime: Package.Dependency
if let path = ProcessInfo.processInfo.environment["JSON_SCHEMA_RUNTIME_PATH"] {
  precondition(!path.isEmpty, "JSON_SCHEMA_RUNTIME_PATH must name a JSON Schema package checkout.")
  jsonSchemaRuntime = .package(name: "swift-json-schema", path: path)
} else {
  jsonSchemaRuntime = .package(
    url: "https://github.com/ajevans99/swift-json-schema.git", from: "0.14.1"
  )
}

let package = Package(
  name: "swift-openai",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "OpenAI",
      targets: ["OpenAIKit", "OpenAICore", "OpenAIFoundation"]
    ),
    .library(
      name: "OpenAIKit",
      targets: ["OpenAIKit"]
    ),
    .library(
      name: "OpenAICore",
      targets: ["OpenAICore"]
    ),
    .library(
      name: "OpenAIFoundation",
      targets: ["OpenAIFoundation"]
    ),
    .library(
      name: "OpenAIResponses",
      targets: ["OpenAIResponses"]
    ),
  ],
  dependencies: [
    // 📡 Swift OpenAPI Generator
    .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.7.2"),
    // 🔄 Swift OpenAPI Runtime
    .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.8.2"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.5.1"),
    responsesRuntime,
    // 📦 JSON Schema Builder for tools
    jsonSchemaRuntime,
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.0"),
    // 🪵 Logging
    .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    // 🧾 Better diffs in tests
    .package(url: "https://github.com/pointfreeco/swift-custom-dump", from: "1.3.3"),
  ],
  targets: [
    .target(
      name: "OpenAIKit",
      dependencies: [
        "OpenAICore",
        "OpenAIFoundation",
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "JSONSchema", package: "swift-json-schema"),
        .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
        .product(name: "OrderedCollections", package: "swift-collections"),
      ],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),
    .testTarget(
      name: "OpenAIKitTests",
      dependencies: [
        "OpenAIKit",
        "OpenAICore",
        .product(name: "CustomDump", package: "swift-custom-dump"),
        .product(name: "Logging", package: "swift-log"),
      ],
      resources: [
        .copy("Fixtures")
      ],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),

    .target(
      name: "OpenAICore",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        "OpenAIFoundation",
        .product(name: "Logging", package: "swift-log"),
      ],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),

    .target(
      name: "OpenAIFoundation",
      dependencies: [
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")
      ],
      exclude: [
        "openapi-generator-config.yaml",
        "openapi.yaml",
        "openapi.commit",
      ],
      swiftSettings: [.swiftLanguageMode(.v5)]
    ),

    .target(
      name: "OpenAIResponses",
      dependencies: [
        .product(name: "OpenAPIJSONRuntime", package: "swift-openapi-schema-codegen"),
        .product(name: "JSONSchema", package: "swift-json-schema"),
        .product(name: "JSONSchemaBuilder", package: "swift-json-schema"),
        .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        .product(name: "HTTPTypes", package: "swift-http-types"),
      ]
    ),
    .testTarget(
      name: "OpenAIResponsesTests",
      dependencies: [
        "OpenAIResponses",
        .product(name: "CustomDump", package: "swift-custom-dump"),
      ],
      resources: [.copy("Fixtures")]
    ),
  ]
)
