import ArgumentParser
import Foundation
import OpenAICore
import OpenAIKit

struct ResponsesImageStreamingCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "image-streaming",
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

    guard let prompt else {
      throw ValidationError("Prompt is required")
    }

    let imagesDirectory = try ImagesDirectory.create()
    let client = try OpenAIFactory.create()
    let session = ResponseSession(client: client, model: .standard(.gpt4o))

    let imageGenTool = ImageGenTool(
      model: .gptImage1,
      quality: .medium,
      moderation: .low,
      partialImages: 3
    )

    await session.register(openAITool: .imageGen(imageGenTool))

    let stream = try await session.stream(prompt)

    for try await event in stream {
      switch event {
      case .output(let text, let isFinal):
        if isFinal {
          print(text)
        } else {
          print(text, terminator: "")
        }
      case .toolCalled(let name, let arguments):
        print("Tool called: \(name) with arguments: \(arguments)")
      case .completed(let responseID):
        print("Response completed: \(responseID)")
      case .others(
        .imageGenCall(.partialImage(let itemId, _, let base64, let partialImageIndex, _))):
        do {

          let savedImage = try ImageUtils.savePartialImage(
            base64Data: base64,
            imageId: itemId,
            partialIndex: partialImageIndex,
            imagesDirectory: imagesDirectory
          )
          print("Partial image saved to: \(savedImage.url)")
        } catch {
          print("Error saving partial image: \(error)")
        }
      case .others(.outputItem(.done(.imageGenToolCall(let item), _))):
        let savedImages = try ImageUtils.saveBase64Images(
          images: [item.result],
          imageId: item.id,
          imagesDirectory: imagesDirectory
        )
        print("Images saved to: \(savedImages.map { $0.url }.joined(separator: "\n"))")
      case .others:
        break
      }
    }
  }
}
