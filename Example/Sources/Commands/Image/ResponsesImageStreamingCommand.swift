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
  var partialImages: Int = 3

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

    let handle = try await session.stream(
      prompt,
      plugins: TextPlugin(), ImagePlugin()
    )
    let (textChannel, imageChannel) = handle.pluginEvents

    try await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        for try await event in textChannel.events {
          switch event {
          case .delta(let text):
            print(text, terminator: "")
          case .completed(let text):
            print(text)
          }
        }
      }

      group.addTask {
        var finalizedImageCallIDs = Set<String>()
        for try await event in imageChannel.events {
          switch event {
          case .partial(let itemID, _, let base64, let partialIndex, _):
            do {
              let savedImage = try ImageUtils.savePartialImage(
                base64Data: base64,
                imageId: itemID,
                partialIndex: partialIndex,
                imagesDirectory: imagesDirectory
              )
              print("Partial image saved to: \(savedImage.url)")
            } catch {
              print("Error saving partial image: \(error)")
            }

          case .completed(let itemID, let status, let resultBase64):
            print("Image generation call completed: \(itemID) (\(status))")
            do {
              try Self.persistFinalImageIfPresent(
                itemID: itemID,
                resultBase64: resultBase64,
                imagesDirectory: imagesDirectory,
                finalizedImageCallIDs: &finalizedImageCallIDs
              )
            } catch {
              print("Error saving final image: \(error)")
            }
          }
        }
      }
      group.addTask {
        for try await rawEvent in handle.raw {
          if case .completed(let response) = rawEvent {
            print("Response completed: \(response.id)")
          }
        }
      }

      try await group.waitForAll()
    }
  }

  private static func persistFinalImageIfPresent(
    itemID: String,
    resultBase64: String?,
    imagesDirectory: URL,
    finalizedImageCallIDs: inout Set<String>
  ) throws {
    guard let resultBase64, !resultBase64.isEmpty else { return }
    guard finalizedImageCallIDs.insert(itemID).inserted else { return }

    let savedImages = try ImageUtils.saveBase64Images(
      images: [resultBase64],
      imageId: itemID,
      imagesDirectory: imagesDirectory
    )

    for image in savedImages {
      print("Final image saved to: \(image.url)")
    }
  }
}
