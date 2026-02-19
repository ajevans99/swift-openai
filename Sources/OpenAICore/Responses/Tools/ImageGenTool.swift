import Foundation
import OpenAPIRuntime

public struct ImageGenTool: Sendable {
  public enum Model: Sendable, Hashable, RawRepresentable {
    public typealias RawValue = String

    case gptImage1
    case gptImage1Mini
    case gptImage1_5
    case custom(String)

    public var rawValue: String {
      switch self {
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

    public init(_ payload: Components.Schemas.ImageGenTool.ModelPayload) {
      if let value2 = payload.value2 {
        switch value2 {
        case .gptImage1:
          self = .gptImage1
        case .gptImage1Mini:
          self = .gptImage1Mini
        case .gptImage1_5:
          self = .gptImage1_5
        }
        return
      }

      if let value1 = payload.value1 {
        self = .custom(value1)
        return
      }

      self = .gptImage1
    }

    public func toOpenAPI() -> Components.Schemas.ImageGenTool.ModelPayload {
      switch self {
      case .gptImage1:
        Components.Schemas.ImageGenTool.ModelPayload(value2: .gptImage1)
      case .gptImage1Mini:
        Components.Schemas.ImageGenTool.ModelPayload(value2: .gptImage1Mini)
      case .gptImage1_5:
        Components.Schemas.ImageGenTool.ModelPayload(value2: .gptImage1_5)
      case .custom(let value):
        Components.Schemas.ImageGenTool.ModelPayload(value1: value)
      }
    }
  }

  public enum Quality: String, Sendable {
    case low
    case medium
    case high
    case auto
  }

  public enum Size: String, Sendable {
    case _1024x1024 = "1024x1024"
    case _1024x1536 = "1024x1536"
    case _1536x1024 = "1536x1024"
    case auto
  }

  public enum OutputFormat: String, Sendable {
    case png
    case webp
    case jpeg
  }

  public enum Moderation: String, Sendable {
    case auto
    case low
  }

  public enum Background: String, Sendable {
    case transparent
    case opaque
    case auto
  }

  public struct InputImageMask: Sendable {
    public let imageUrl: String?
    public let fileId: String?

    public init(
      imageUrl: String? = nil,
      fileId: String? = nil
    ) {
      self.imageUrl = imageUrl
      self.fileId = fileId
    }

    public func toOpenAPI() -> Components.Schemas.ImageGenTool.InputImageMaskPayload {
      Components.Schemas.ImageGenTool.InputImageMaskPayload(
        imageUrl: imageUrl,
        fileId: fileId
      )
    }
  }

  public let model: Model?
  public let quality: Quality?
  public let size: Size?
  public let outputFormat: OutputFormat?
  public let outputCompression: Int?
  public let moderation: Moderation?
  public let background: Background?
  public let inputImageMask: InputImageMask?
  public let partialImages: Int?

  public init(
    model: Model? = nil,
    quality: Quality? = nil,
    size: Size? = nil,
    outputFormat: OutputFormat? = nil,
    outputCompression: Int? = nil,
    moderation: Moderation? = nil,
    background: Background? = nil,
    inputImageMask: InputImageMask? = nil,
    partialImages: Int? = nil
  ) {
    self.model = model
    self.quality = quality
    self.size = size
    self.outputFormat = outputFormat
    self.outputCompression = outputCompression
    self.moderation = moderation
    self.background = background
    self.inputImageMask = inputImageMask
    self.partialImages = partialImages
  }

  public init(_ tool: Components.Schemas.ImageGenTool) {
    self.model = tool.model.map(Model.init)
    self.quality = tool.quality.map { Quality(rawValue: $0.rawValue)! }
    self.size = tool.size.map { Size(rawValue: $0.rawValue)! }
    self.outputFormat = tool.outputFormat.map { OutputFormat(rawValue: $0.rawValue)! }
    self.outputCompression = tool.outputCompression
    self.moderation = tool.moderation.map { Moderation(rawValue: $0.rawValue)! }
    self.background = tool.background.map { Background(rawValue: $0.rawValue)! }
    self.inputImageMask = tool.inputImageMask.map { mask in
      InputImageMask(
        imageUrl: mask.imageUrl,
        fileId: mask.fileId
      )
    }
    self.partialImages = tool.partialImages
  }

  public func toOpenAPI() -> Components.Schemas.ImageGenTool {
    Components.Schemas.ImageGenTool(
      _type: .imageGeneration,
      model: model?.toOpenAPI(),
      quality: quality.map {
        Components.Schemas.ImageGenTool.QualityPayload(rawValue: $0.rawValue)!
      },
      size: size.map { Components.Schemas.ImageGenTool.SizePayload(rawValue: $0.rawValue)! },
      outputFormat: outputFormat.map {
        Components.Schemas.ImageGenTool.OutputFormatPayload(rawValue: $0.rawValue)!
      },
      outputCompression: outputCompression,
      moderation: moderation.map {
        Components.Schemas.ImageGenTool.ModerationPayload(rawValue: $0.rawValue)!
      },
      background: background.map {
        Components.Schemas.ImageGenTool.BackgroundPayload(rawValue: $0.rawValue)!
      },
      inputImageMask: inputImageMask?.toOpenAPI(),
      partialImages: partialImages
    )
  }
}

extension ImageGenTool.Model: ExpressibleByStringInterpolation {
  public init(stringLiteral value: String) {
    self = Self(rawValue: value) ?? .custom(value)
  }
}
