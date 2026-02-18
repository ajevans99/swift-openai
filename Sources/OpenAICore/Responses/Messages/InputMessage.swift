public struct InputTextContent: Sendable {
  public let text: String

  public init(text: String) {
    self.text = text
  }

  public func toOpenAPI() -> Components.Schemas.InputTextContent {
    Components.Schemas.InputTextContent(
      _type: .inputText,
      text: text
    )
  }
}

public struct InputImageContent: Sendable {
  public enum Detail: Sendable {
    case low
    case high
    case auto

    public func toOpenAPI() -> Components.Schemas.ImageDetail {
      switch self {
      case .low: return .low
      case .high: return .high
      case .auto: return .auto
      }
    }
  }

  public let imageUrl: String?
  public let fileId: String?
  public let detail: Detail

  public init(
    imageUrl: String? = nil,
    fileId: String? = nil,
    detail: Detail = .auto
  ) {
    self.imageUrl = imageUrl
    self.fileId = fileId
    self.detail = detail
  }

  public func toOpenAPI() -> Components.Schemas.InputImageContent {
    Components.Schemas.InputImageContent(
      _type: .inputImage,
      detail: detail.toOpenAPI()
    )
  }
}

public struct InputFileContent: Sendable {
  public let fileId: String?
  public let filename: String?
  public let fileData: String?

  public init(
    fileId: String? = nil,
    filename: String? = nil,
    fileData: String? = nil
  ) {
    self.fileId = fileId
    self.filename = filename
    self.fileData = fileData
  }

  public func toOpenAPI() -> Components.Schemas.InputFileContent {
    Components.Schemas.InputFileContent(
      _type: .inputFile,
      filename: filename,
      fileUrl: nil,
      fileData: fileData
    )
  }
}

public enum InputContent: Sendable {
  case text(InputTextContent)
  case image(InputImageContent)
  case file(InputFileContent)

  public init(_ content: Components.Schemas.InputContent) {
    switch content {
    case .inputTextContent(let textContent):
      self = .text(InputTextContent(text: textContent.text))
    case .inputImageContent(let imageContent):
      let detail: InputImageContent.Detail
      switch imageContent.detail {
      case .auto: detail = .auto
      case .low: detail = .low
      case .high: detail = .high
      }
      self = .image(
        InputImageContent(
          imageUrl: nil,
          fileId: nil,
          detail: detail
        )
      )
    case .inputFileContent(let fileContent):
      self = .file(
        InputFileContent(
          fileId: nil,
          filename: fileContent.filename,
          fileData: fileContent.fileData
        )
      )
    }
  }

  public func toOpenAPI() -> Components.Schemas.InputContent {
    switch self {
    case .text(let textContent):
      return .inputTextContent(textContent.toOpenAPI())
    case .image(let imageContent):
      return .inputImageContent(imageContent.toOpenAPI())
    case .file(let fileContent):
      return .inputFileContent(fileContent.toOpenAPI())
    }
  }
}

public struct InputMessage: Sendable {
  public enum Role: String, Sendable {
    case user
    case system
    case developer

    public func toOpenAPI() -> Components.Schemas.InputMessage.RolePayload {
      switch self {
      case .user: return .user
      case .system: return .system
      case .developer: return .developer
      }
    }
  }

  public enum Status: String, Sendable {
    case inProgress
    case completed
    case incomplete

    public func toOpenAPI() -> Components.Schemas.InputMessage.StatusPayload {
      switch self {
      case .inProgress: return .inProgress
      case .completed: return .completed
      case .incomplete: return .incomplete
      }
    }
  }

  public let role: Role
  public let status: Status?
  public let content: [InputContent]

  public init(
    role: Role,
    status: Status? = nil,
    content: [InputContent]
  ) {
    self.role = role
    self.status = status
    self.content = content
  }

  /// Convenience initializer for a message with text content.
  public init(
    role: Role,
    text: String
  ) {
    self.init(role: role, content: [.text(.init(text: text))])
  }

  public init(_ message: Components.Schemas.InputMessage) {
    self.role =
      switch message.role {
      case .user: .user
      case .system: .system
      case .developer: .developer
      }
    self.status = message.status.map {
      switch $0 {
      case .inProgress: .inProgress
      case .completed: .completed
      case .incomplete: .incomplete
      }
    }
    self.content = message.content.map { InputContent($0) }
  }

  public func toOpenAPI() -> Components.Schemas.InputMessage {
    Components.Schemas.InputMessage(
      _type: .message,
      role: role.toOpenAPI(),
      status: status?.toOpenAPI(),
      content: content.map { $0.toOpenAPI() }
    )
  }
}
