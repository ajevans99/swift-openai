import ArgumentParser
import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit
import SwiftDotenv

struct ImageEditCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "image-edit",
    abstract: "Demonstrate image edit tool calling with swift-openai"
  )

  @Argument(help: "The path to the image to edit", completion: .file(extensions: ["png"]))
  var imagePath: String

  @Argument(help: "The prompt describing the edits to make to the image (or pipe input via stdin)")
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

    await session.register(tool: try ImageEditTool(client: client))
    let response = try await session.send(
      prompt,
      additionalItems: [
        .inputMessage(
          .init(
            role: .system,
            text: """
              You are an image editor. You will be given an image and a prompt. You will ask the tool to edit the image based on the prompt.

              The image is at: \(imagePath).
              This CLI is running in the directory: \(FileManager.default.currentDirectoryPath).
              If the path looks like a relative path, make it absolute by prefacing it with "\(FileManager.default.currentDirectoryPath)/".
              """
          )
        )
      ]
    )
    print(response)
  }
}
