import ArgumentParser
import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit
import SwiftDotenv

struct ImageAssistantCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "image",
    abstract: "Demonstrate image assistant tool calling with swift-openai"
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

    await session.register(tool: ImageGenerationTool(client: client))
    let response = try await session.send(prompt)
    print(response)
  }
}

struct ImageGenerationTool: Tool {
  let client: OpenAI
  let imagesDirectory: URL

  init(client: OpenAI) {
    self.client = client
    // Create images directory in the repository
    let repoDirectory = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()  // Sources
      .deletingLastPathComponent()  // Example
    self.imagesDirectory = repoDirectory.appendingPathComponent(
      "generated-images", isDirectory: true)

    // Create the directory if it doesn't exist
    try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
  }

  let name = "generate_image"
  let description: String? = "An AI image generation tool"
  let strict: Bool = false

  @Schemable
  struct Parameters {
    @SchemaOptions(
      .description(
        "The text prompt the tool will use to generate the image."
      ))
    @StringOptions(.maxLength(32000))
    let prompt: String
  }

  var parameters: some JSONSchemaComponent<Parameters> {
    Parameters.schema
  }

  func call(parameters: Parameters) async throws -> String {
    let imageId = UUID().uuidString
    do {
      let response = try await client.createImage(
        prompt: parameters.prompt,
        model: .gptImage1,
        n: 4,
        moderation: .low
      )

      client.logger.debug("Create image response: \(response)")

      var savedImages: [(id: String, url: String)] = []

      for (index, image) in response.data.enumerated() {
        if let imageData = image.b64Json,
          let data = Data(base64Encoded: imageData)
        {
          let imageId = "\(imageId)-\(index + 1)"
          let imageURL = imagesDirectory.appendingPathComponent("\(imageId).png")
          try data.write(to: imageURL)
          print("Image saved to: \(imageURL.path)")
          savedImages.append((id: imageId, url: imageURL.path))
        }
      }

      if !savedImages.isEmpty {
        let imageUrls = savedImages.map {
          """
          {
            "id": "\($0.id)",
            "url": "\($0.url)"
          }
          """
        }.joined(separator: ",")

        return """
          {
            "success": true,
            "images": [\(imageUrls)]
          }
          """
      }

      return """
        {
          "success": false,
          "error": "Could not get data from any images"
        }
        """

    } catch {
      print("Error generating image: \(error)")
      return """
        {
          "success": false,
          "error": \(error)
        }
        """
    }
  }
}
