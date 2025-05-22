import Foundation
import OpenAPIRuntime

public struct CreateImageEditRequest: Sendable {
  public enum Model: String, Sendable {
    case dallE2 = "dall-e-2"
    case gptImage1 = "gpt-image-1"

    public func toOpenAPI()
      -> Operations.CreateImageEdit.Input.Body.MultipartFormPayload.ModelPayload
    {
      return .init(body: .init(rawValue))
    }
  }

  public enum Size: String, Sendable {
    // Dall-E 2
    case size256x256 = "256x256"
    case size512x512 = "512x512"

    // Both
    case size1024x1024 = "1024x1024"

    // GPT Image 1
    case size1536x1024 = "1536x1024"
    case size1024x1536 = "1024x1536"
    case auto = "auto"

    public func toOpenAPI()
      -> Operations.CreateImageEdit.Input.Body.MultipartFormPayload.SizePayload
    {
      .init(body: .init(rawValue))
    }
  }

  public enum ResponseFormat: String, Sendable {
    case url
    case b64Json = "b64_json"

    public func toOpenAPI()
      -> Operations.CreateImageEdit.Input.Body.MultipartFormPayload.ResponseFormatPayload
    {
      .init(body: .init(rawValue))
    }
  }

  public enum Quality: String, Sendable {
    // Dall-E 2
    case standard

    // GPT Image 1
    case low
    case medium
    case high
    case auto

    public func toOpenAPI()
      -> Operations.CreateImageEdit.Input.Body.MultipartFormPayload.QualityPayload
    {
      .init(body: .init(rawValue))
    }
  }

  public enum ImageData: Sendable {
    case single(File)  // Base64 encoded
    case multiple([File])  // Base64 encoded
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

  public func toOpenAPI()
    -> OpenAPIRuntime.MultipartBody<Operations.CreateImageEdit.Input.Body.MultipartFormPayload>
  {
    var parts: [Operations.CreateImageEdit.Input.Body.MultipartFormPayload] = []

    parts.append(.prompt(.init(payload: .init(body: .init(prompt)))))

    if let model {
      parts.append(
        .model(.init(payload: model.toOpenAPI()))
      )
    }

    if let n {
      parts.append(.n(.init(payload: .init(body: .init("\(n)")))))
    }

    if let size = size {
      parts.append(.size(.init(payload: size.toOpenAPI())))
    }

    if let responseFormat = responseFormat {
      parts.append(.responseFormat(.init(payload: responseFormat.toOpenAPI())))
    }

    if let user = user {
      parts.append(.user(.init(payload: .init(body: .init(user)))))
    }

    if let quality = quality {
      parts.append(.quality(.init(payload: quality.toOpenAPI())))
    }

    switch image {
    case .single(let file):
      parts.append(
        .image(
          .init(
            payload: .init(body: file.toHTTPBody()),
            filename: file.filename
          )
        )
      )
    case .multiple(let files):
      for file in files {
        parts.append(
          .image(
            .init(payload: .init(body: file.toHTTPBody()), filename: file.filename)))
      }
    }
    return .init(parts)
  }
}

public struct File: Sendable {
  public let filename: String
  public let content: Data

  public init(filename: String, content: Data) {
    self.filename = filename
    self.content = content
  }

  func toHTTPBody() -> OpenAPIRuntime.HTTPBody {
    return .init(content)
  }
}

extension CreateImageEditRequest.ImageData: ExpressibleByArrayLiteral {
  public init(arrayLiteral elements: File...) {
    self = .multiple(elements)
  }
}
