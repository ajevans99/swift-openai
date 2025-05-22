import ArgumentParser
import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit
import SwiftDotenv

struct ImageGenerationCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "image",
    abstract: "Demonstrate image generation tool calling with swift-openai"
  )

  @Argument(help: "The prompt to send to the assistant (or pipe input via stdin)")
  var prompt: String?

  mutating func run() async throws {
    let prompt =
      self.prompt
      ?? {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        return String(data: input, encoding: .utf8)
      }()

    guard let prompt = prompt else {
      throw ValidationError("Prompt is required")
    }

    let client = try OpenAIFactory.create()
    let session = ResponseSession(client: client, model: .standard(.gpt4o))

    await session.register(tool: try ImageGenerationTool(client: client))
    let response = try await session.send(prompt, additionalItems: [])  // TODO: Remove additional items here when Sendable is implemented on all models
    print(response)
  }
}
