// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import Foundation
import OpenAICore
import OpenAPIAsyncHTTPClient
import SwiftDotenv

@main
struct OpenAIExample: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "OpenAI CLI example",
    subcommands: [
      WeatherCommand.self, WeatherV2Command.self, WeatherV3Command.self, WeatherV4Command.self,
      ImageGenerationCommand.self, ImageEditCommand.self, ChatCommand.self,
    ]
  )

  mutating func run() async throws {
    try Dotenv.configure()

    guard let apiKey = Dotenv["OPENAI_API_KEY"]?.stringValue else {
      throw ValidationError("OPENAI_API_KEY is not set")
    }

    let openAI = try OpenAI(
      transport: AsyncHTTPClientTransport(),
      apiKey: apiKey
    )

    let response = try await openAI.createResponse(
      input: "Hello, world!",
      model: .standard(.gpt4o)
    )

    dump(response)
    print("Output text: \(response.outputText)")
  }
}
