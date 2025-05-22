import Foundation
import JSONSchema
import JSONSchemaBuilder
import OpenAIKit

struct ImageEditTool: Tool {
  let name = "edit_image"
  let description = "Edit an image using OpenAI's image editing capabilities"
  let strict = true

  private let client: OpenAI
  private let imagesDirectory: URL

  init(client: OpenAI, imagesDirectory: URL) {
    self.client = client
    self.imagesDirectory = imagesDirectory
  }

  var parameters: some JSONSchemaComponent<(String, String)> {
    JSONObject {
      JSONProperty(key: "image_path") {
        JSONString()
          .description("Path to the image file to edit")
      }
      .required()
      JSONProperty(key: "prompt") {
        JSONString()
          .description("Description of the desired edit")
      }
      .required()
    }
    .additionalProperties {
      false
    }
    .map { ($0.0, $0.1) }
  }

  func call(parameters: (String, String)) async throws -> String {
    let (imagePath, prompt) = parameters

    guard let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) else {
      return """
        {
          "success": false,
          "error": "Could not read image file at path: \(imagePath)"
        }
        """
    }

    do {
      let response = try await client.editImage(
        image: imageData,
        prompt: prompt,
        model: .gptImage1,
        n: 1,
        responseFormat: .b64Json
      )

      if let imageData = response.data.first?.b64Json,
        let data = Data(base64Encoded: imageData)
      {
        let imageId = UUID().uuidString
        let imageURL = imagesDirectory.appendingPathComponent("\(imageId).png")
        try data.write(to: imageURL)

        return """
          {
            "success": true,
            "image": {
              "id": "\(imageId)",
              "url": "\(imageURL.path)"
            }
          }
          """
      }

      return """
        {
          "success": false,
          "error": "Could not get data from edited image"
        }
        """

    } catch {
      return """
        {
          "success": false,
          "error": "\(error)"
        }
        """
    }
  }
}
