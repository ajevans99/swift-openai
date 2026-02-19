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

  @Option(name: .long, help: "Responses model to orchestrate tool calling.")
  var model: String = "gpt-5.2"

  @Option(name: .long, help: "Number of partial images to request (0-3).")
  var partialImages: Int = 0

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
    let session = ResponseSession(client: client, model: .custom(model))

    let imageGenTool = ImageGenTool(
      model: .gptImage1_5,
      quality: .medium,
      moderation: .low,
      partialImages: max(0, min(3, partialImages))
    )

    await session.register(openAITool: .imageGen(imageGenTool))

    let stream = try await session.stream(prompt)
    var finalizedImageCallIDs = Set<String>()

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
        print("Image generation call completed: \(item.id) (\(item.status.rawValue))")
        do {
          try Self.persistFinalImageIfPresent(
            item: item,
            imagesDirectory: imagesDirectory,
            finalizedImageCallIDs: &finalizedImageCallIDs
          )
        } catch {
          print("Error saving final image: \(error)")
        }
      case .others:
        break
      }
    }
  }

  private static func persistFinalImageIfPresent(
    item: Components.Schemas.ImageGenToolCall,
    imagesDirectory: URL,
    finalizedImageCallIDs: inout Set<String>
  ) throws {
    guard let result = item.result, !result.isEmpty else { return }
    guard finalizedImageCallIDs.insert(item.id).inserted else { return }

    let savedImages = try ImageUtils.saveBase64Images(
      images: [result],
      imageId: item.id,
      imagesDirectory: imagesDirectory
    )

    for image in savedImages {
      print("Final image saved to: \(image.url)")
    }
  }
}
