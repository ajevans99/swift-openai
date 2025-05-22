import Foundation
import OpenAPIRuntime

public struct CreateImageEditRequest {
  public enum Model {
    case dallE2
    case gptImage1

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.ModelPayload {
      let value2: Components.Schemas.CreateImageEditRequest.ModelPayload.Value2Payload =
        switch self {
        case .dallE2: .dallE2
        case .gptImage1: .gptImage1
        }
      return .init(value2: .init(stringLiteral: String))
    }
  }

  public enum Size {
    // Dall-E 2
    case size256x256
    case size512x512

    // Both
    case size1024x1024

    // GPT Image 1
    case size1536x1024
    case size1024x1536
    case auto

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.SizePayload {
      switch self {
      case .size256x256: ._256x256
      case .size512x512: ._512x512
      case .size1024x1024: ._1024x1024
      case .size1536x1024: ._1536x1024
      case .size1024x1536: ._1024x1536
      case .auto: .auto
      }
    }
  }

  public enum ResponseFormat {
    case url
    case b64Json

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.ResponseFormatPayload {
      switch self {
      case .url: .url
      case .b64Json: .b64Json
      }
    }
  }

  public enum Quality {
    // Dall-E 2
    case standard

    // GPT Image 1
    case low
    case medium
    case high
    case auto

    public func toOpenAPI() -> Components.Schemas.CreateImageEditRequest.QualityPayload {
      switch self {
      case .standard: .standard
      case .low: .low
      case .medium: .medium
      case .high: .high
      case .auto: .auto
      }
    }
  }

  public enum ImageData {
    case single(Data)
    case multiple([Data])
  }

  public let image: ImageData
  public let prompt: String
  public let mask: Data?
  public let model: Model?
  public let n: Int?
  public let size: Size?
  public let responseFormat: ResponseFormat?
  public let user: String?
  public let quality: Quality?

  public init(
    image: ImageData,
    prompt: String,
    mask: Data? = nil,
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
    var parts: [Components.Schemas.CreateImageEditRequest] = [
      .image(
        .init(
          filename: "image.png",
          payload: .init(body: .init(image))
        )),
      .prompt(
        .init(
          filename: "prompt.txt",
          payload: .init(body: .init(prompt.data(using: .utf8)!))
        )),
    ]

    if let mask = mask {
      parts.append(
        .mask(
          .init(
            filename: "mask.png",
            payload: .init(body: .init(mask))
          )))
    }

    if let model = model {
      parts.append(
        .model(
          .init(
            filename: "model.txt",
            payload: .init(body: .init(model.toOpenAPI().value2.rawValue.data(using: .utf8)!))
          )))
    }

    if let n = n {
      parts.append(
        .n(
          .init(
            filename: "n.txt",
            payload: .init(body: .init(String(n).data(using: .utf8)!))
          )))
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
