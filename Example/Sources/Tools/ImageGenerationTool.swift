import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit

struct ExampleImageGenerationTool: Toolable {
  let client: OpenAI
  let imagesDirectory: URL

  init(client: OpenAI) throws {
    self.client = client
    self.imagesDirectory = try ImagesDirectory.create()
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

      let savedImages = try ImageUtils.saveBase64Images(
        images: response.data.map { $0.b64Json },
        imageId: imageId,
        imagesDirectory: imagesDirectory
      )

      for (_, path) in savedImages {
        print("Image saved to: \(path)")
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
