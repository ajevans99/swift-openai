import Foundation
import OpenAPIRuntime

public struct CreateImageRequest: Sendable {
  public enum Model: Sendable, Hashable, RawRepresentable {
    public typealias RawValue = String

    case dallE2
    case dallE3
    case gptImage1
    case gptImage1Mini
    case gptImage1_5
    case custom(String)

    public var rawValue: String {
      switch self {
      case .dallE2:
        "dall-e-2"
      case .dallE3:
        "dall-e-3"
      case .gptImage1:
        "gpt-image-1"
      case .gptImage1Mini:
        "gpt-image-1-mini"
      case .gptImage1_5:
        "gpt-image-1.5"
      case .custom(let value):
        value
      }
    }

    public init?(rawValue: String) {
      switch rawValue {
      case "dall-e-2":
        self = .dallE2
      case "dall-e-3":
        self = .dallE3
      case "gpt-image-1":
        self = .gptImage1
      case "gpt-image-1-mini":
        self = .gptImage1Mini
      case "gpt-image-1.5":
        self = .gptImage1_5
      default:
        self = .custom(rawValue)
      }
    }

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.ModelPayload {
      switch self {
      case .dallE2:
        .init(value2: .dallE2)
      case .dallE3:
        .init(value2: .dallE3)
      case .gptImage1:
        .init(value2: .gptImage1)
      case .gptImage1Mini:
        .init(value2: .gptImage1Mini)
      case .gptImage1_5:
        .init(value2: .gptImage1_5)
      case .custom(let value):
        .init(value1: value)
      }
    }
  }

  public enum Quality: Sendable {
    // Dall-E 2/3
    case standard

    // Dall-E 3
    case hd

    // GPT Image 1
    case low
    case medium
    case high

    // Default value
    case auto

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.QualityPayload {
      switch self {
      case .standard: .standard
      case .hd: .hd
      case .low: .low
      case .medium: .medium
      case .high: .high
      case .auto: .auto
      }
    }
  }

  public enum ResponseFormat: Sendable {
    case url
    case b64Json

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.ResponseFormatPayload {
      switch self {
      case .url: .url
      case .b64Json: .b64Json
      }
    }
  }

  public enum OutputFormat: Sendable {
    case png
    case jpeg
    case webp

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.OutputFormatPayload {
      switch self {
      case .png: .png
      case .jpeg: .jpeg
      case .webp: .webp
      }
    }
  }

  public enum Size: Sendable {
    case auto
    case size1024x1024
    case size1536x1024
    case size1024x1536
    case size256x256
    case size512x512
    case size1792x1024
    case size1024x1792

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.SizePayload {
      switch self {
      case .auto: .auto
      case .size1024x1024: ._1024x1024
      case .size1536x1024: ._1536x1024
      case .size1024x1536: ._1024x1536
      case .size256x256: ._256x256
      case .size512x512: ._512x512
      case .size1792x1024: ._1792x1024
      case .size1024x1792: ._1024x1792
      }
    }
  }

  public enum Moderation: Sendable {
    case low
    case auto

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.ModerationPayload {
      switch self {
      case .low: .low
      case .auto: .auto
      }
    }
  }

  public enum Background: Sendable {
    case transparent
    case opaque
    case auto

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.BackgroundPayload {
      switch self {
      case .transparent: .transparent
      case .opaque: .opaque
      case .auto: .auto
      }
    }
  }

  public enum Style: Sendable {
    case vivid
    case natural

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.StylePayload {
      switch self {
      case .vivid: .vivid
      case .natural: .natural
      }
    }
  }

  public let prompt: String
  public let model: Model?
  public let n: Int?
  public let quality: Quality?
  public let responseFormat: ResponseFormat?
  public let outputFormat: OutputFormat?
  public let outputCompression: Int?
  public let size: Size?
  public let moderation: Moderation?
  public let background: Background?
  public let style: Style?
  public let user: String?

  public init(
    prompt: String,
    model: Model? = nil,
    n: Int? = nil,
    quality: Quality? = nil,
    responseFormat: ResponseFormat? = nil,
    outputFormat: OutputFormat? = nil,
    outputCompression: Int? = nil,
    size: Size? = nil,
    moderation: Moderation? = nil,
    background: Background? = nil,
    style: Style? = nil,
    user: String? = nil
  ) {
    self.prompt = prompt
    self.model = model
    self.n = n
    self.quality = quality
    self.responseFormat = responseFormat
    self.outputFormat = outputFormat
    self.outputCompression = outputCompression
    self.size = size
    self.moderation = moderation
    self.background = background
    self.style = style
    self.user = user
  }

  public func toOpenAPI() -> Components.Schemas.CreateImageRequest {
    .init(
      prompt: self.prompt,
      model: self.model?.toOpenAPI(),
      n: self.n,
      quality: self.quality?.toOpenAPI(),
      responseFormat: self.responseFormat?.toOpenAPI(),
      outputFormat: self.outputFormat?.toOpenAPI(),
      outputCompression: self.outputCompression,
      size: self.size?.toOpenAPI(),
      moderation: self.moderation?.toOpenAPI(),
      background: self.background?.toOpenAPI(),
      style: self.style?.toOpenAPI(),
      user: self.user
    )
  }
}

extension CreateImageRequest.Model: ExpressibleByStringInterpolation {
  public init(stringLiteral value: String) {
    self = Self(rawValue: value) ?? .custom(value)
  }
}
