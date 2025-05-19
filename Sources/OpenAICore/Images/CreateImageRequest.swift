import Foundation
import OpenAPIRuntime

public struct CreateImageRequest {
  public enum Model {
    case dallE2
    case dallE3
    case gptImage1

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.ModelPayload {
      let value2: Components.Schemas.CreateImageRequest.ModelPayload.Value2Payload =
        switch self {
        case .dallE2: .dallE2
        case .dallE3: .dallE3
        case .gptImage1: .gptImage1
        }
      return .init(value2: value2)
    }
  }

  public enum Quality {
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

  public enum ResponseFormat {
    case url
    case b64Json

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.ResponseFormatPayload {
      switch self {
      case .url: .url
      case .b64Json: .b64Json
      }
    }
  }

  public enum OutputFormat {
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

  public enum Size {
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

  public enum Moderation {
    case low
    case auto

    public func toOpenAPI() -> Components.Schemas.CreateImageRequest.ModerationPayload {
      switch self {
      case .low: .low
      case .auto: .auto
      }
    }
  }

  public enum Background {
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

  public enum Style {
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
