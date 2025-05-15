import Foundation
import OpenAPIRuntime

public struct OutputTextContent {
  public let text: String
  public let annotations: [Components.Schemas.Annotation]

  public init(
    text: String,
    annotations: [Components.Schemas.Annotation] = []
  ) {
    self.text = text
    self.annotations = annotations
  }

  public func toOpenAPI() -> Components.Schemas.OutputTextContent {
    Components.Schemas.OutputTextContent(
      _type: .outputText,
      text: text,
      annotations: annotations
    )
  }
}

public struct RefusalContent {
  public let refusal: String

  public init(refusal: String) {
    self.refusal = refusal
  }

  public func toOpenAPI() -> Components.Schemas.RefusalContent {
    Components.Schemas.RefusalContent(
      _type: .refusal,
      refusal: refusal
    )
  }
}

public enum OutputContent {
  case text(OutputTextContent)
  case refusal(RefusalContent)

  public init(_ content: Components.Schemas.OutputContent) {
    switch content {
    case .OutputTextContent(let textContent):
      self = .text(
        OutputTextContent(
          text: textContent.text,
          annotations: textContent.annotations
        )
      )
    case .RefusalContent(let refusalContent):
      self = .refusal(RefusalContent(refusal: refusalContent.refusal))
    }
  }

  public func toOpenAPI() -> Components.Schemas.OutputContent {
    switch self {
    case .text(let textContent):
      return .OutputTextContent(textContent.toOpenAPI())
    case .refusal(let refusalContent):
      return .RefusalContent(refusalContent.toOpenAPI())
    }
  }
}

public struct OutputMessage {
  public enum Status {
    case inProgress
    case completed
    case incomplete

    public func toOpenAPI() -> Components.Schemas.OutputMessage.StatusPayload {
      switch self {
      case .inProgress: return .inProgress
      case .completed: return .completed
      case .incomplete: return .incomplete
      }
    }
  }

  public let id: String
  public let content: [OutputContent]
  public let status: Status

  public init(
    id: String,
    content: [OutputContent],
    status: Status
  ) {
    self.id = id
    self.content = content
    self.status = status
  }

  public init(_ message: Components.Schemas.OutputMessage) {
    self.id = message.id
    self.content = message.content.map { OutputContent($0) }
    self.status =
      switch message.status {
      case .inProgress: .inProgress
      case .completed: .completed
      case .incomplete: .incomplete
      }
  }

  public func toOpenAPI() -> Components.Schemas.OutputMessage {
    Components.Schemas.OutputMessage(
      id: id,
      _type: .message,
      role: .assistant,
      content: content.map { $0.toOpenAPI() },
      status: status.toOpenAPI()
    )
  }
}
