// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser
import SwiftDotenv
import OpenAI

@main
struct OpenAIExample: ParsableCommand {
  mutating func run() throws {
    try Dotenv.configure()

    let openAI = OpenAIClient(
      apiKey: Dotenv["OPENAI_API_KEY"]
    )

  }
}
