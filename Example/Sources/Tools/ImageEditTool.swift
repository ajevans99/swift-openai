import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAICore
import OpenAIKit

struct ImageEditTool: Tool {
  private let client: OpenAI
  private let imagesDirectory: URL

  init(client: OpenAI) throws {
    self.client = client
    self.imagesDirectory = try ImagesDirectory.create()
  }

  let name = "edit_image"
  let description: String? = "An AI image editing tool"
  let strict: Bool = false

  @Schemable
  struct Parameters {
    @SchemaOptions(
      .description(
        "The text prompt the tool will use to edit the image."
      ))
    @StringOptions(.maxLength(32000))
    let prompt: String

    @SchemaOptions(
      .description(
        "The path to the image to edit."
      ))
    @StringOptions(.maxLength(32000))
    let imagePath: String
  }

  var parameters: some JSONSchemaComponent<Parameters> {
    Parameters.schema
  }

  func call(parameters: Parameters) async throws -> String {
    let imageId = UUID().uuidString
    do {
      let imageURL = URL(fileURLWithPath: parameters.imagePath)
      let imageData = try Data(contentsOf: imageURL)

      let response = try await client.editImage(
        image: .single(
          File(filename: imageURL.lastPathComponent, content: imageData)),
        prompt: parameters.prompt,
        model: .gptImage1
      )

      client.logger.debug("Edit image response: \(response)")

      var savedImages: [(id: String, url: String)] = []

      for (index, image) in response.data.enumerated() {
        if let imageData = image.b64Json,
          let data = Data(base64Encoded: imageData)
        {
          let imageId = "\(imageId)-\(index + 1)"
          let imageURL = imagesDirectory.appendingPathComponent("\(imageId).png")
          try data.write(to: imageURL)
          client.logger.debug("Edited image saved to: \(imageURL.path)")
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
      client.logger.error("Error editing image: \(error)")
      return """
        {
          "success": false,
          "error": "\(error)"
        }
        """
    }
  }
}
