import Foundation
import OpenAPIRuntime

public struct CreateImageEditRequest {
  public enum Model: String {
    case dallE2 = "dall-e-2"
    case gptImage1 = "gpt-image-1"

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.ModelPayload {
      return .init(body: .init(rawValue))
    }
  }

  public enum Size: String {
    // Dall-E 2
    case size256x256 = "256x256"
    case size512x512 = "512x512"

    // Both
    case size1024x1024 = "1024x1024"

    // GPT Image 1
    case size1536x1024 = "1536x1024"
    case size1024x1536 = "1024x1536"
    case auto = "auto"

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.SizePayload {
      .init(body: .init(rawValue))
    }
  }

  public enum ResponseFormat: String {
    case url
    case b64Json = "b64_json"

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.ResponseFormatPayload {
      .init(body: .init(rawValue))
    }
  }

  public enum Quality: String {
    // Dall-E 2
    case standard

    // GPT Image 1
    case low
    case medium
    case high
    case auto

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.QualityPayload {
      .init(body: .init(rawValue))
    }
  }

  public enum ImageData {
    case single(String)  // Base64 encoded
    case multiple([String])  // Base64 encoded

    public func toOpenAPI() -> [Components.Schemas.CreateImageEditRequest.ImagePayload] {
      switch self {
      case .single(let image):
        return [.init(body: .init(image))]
      case .multiple(let images):
        return images.map { .init(body: .init($0)) }
      }
    }
  }

  public let image: ImageData
  public let prompt: String
  public let mask: String?  // Base64 encoded
  public let model: Model?
  public let n: Int?
  public let size: Size?
  public let responseFormat: ResponseFormat?
  public let user: String?
  public let quality: Quality?

  public init(
    image: ImageData,
    prompt: String,
    mask: String? = nil,
    model: Model? = nil,
    n: Int? = nil,
    size: Size? = nil,
    responseFormat: ResponseFormat? = nil,
    user: String? = nil,
    quality: Quality? = nil
  ) {
    self.image = image
    self.prompt = prompt
    self.mask = mask
    self.model = model
    self.n = n
    self.size = size
    self.responseFormat = responseFormat
    self.user = user
    self.quality = quality
  }

  public func toOpenAPI() -> [Components.Schemas.CreateImageEditRequest] {
    var parts: [Components.Schemas.CreateImageEditRequest] = image.toOpenAPI().map {
      .image(.init(payload: $0))
    }

    parts.append(.prompt(.init(payload: .init(body: .init(prompt)))))

    if let model {
      parts.append(
        .model(.init(payload: model.toOpenAPI()))
      )
    }

    if let n {
      parts.append(.n(.init(payload: .init(Data(n)))))
    }

    if let size = size {
      parts.append(
        .size(
          .init(
            filename: "size.txt",
            payload: .init(body: .init(size.toOpenAPI().rawValue.data(using: .utf8)!))
          )))
    }

    if let responseFormat = responseFormat {
      parts.append(
        .responseFormat(
          .init(
            filename: "response_format.txt",
            payload: .init(body: .init(responseFormat.toOpenAPI().rawValue.data(using: .utf8)!))
          )))
    }

    if let user = user {
      parts.append(
        .user(
          .init(
            filename: "user.txt",
            payload: .init(body: .init(user.data(using: .utf8)!))
          )))
    }

    if let quality = quality {
      parts.append(
        .quality(
          .init(
            filename: "quality.txt",
            payload: .init(body: .init(quality.toOpenAPI().rawValue.data(using: .utf8)!))
          )))
    }

    return parts
  }
}
