public struct InputTextContent {
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

public struct InputImageContent {
  public enum Detail {
    case low
    case high
    case auto

    public func toOpenAPI() -> Components.Schemas.InputImageContent.DetailPayload {
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
      imageUrl: imageUrl.map { Components.Schemas.InputImageContent.ImageUrlPayload(value1: $0) },
      fileId: fileId.map { Components.Schemas.InputImageContent.FileIdPayload(value1: $0) },
      detail: detail.toOpenAPI()
    )
  }
}

public struct InputFileContent {
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
      fileId: fileId.map { Components.Schemas.InputFileContent.FileIdPayload(value1: $0) },
      filename: filename,
      fileData: fileData
    )
  }
}

public enum InputContent {
  case text(InputTextContent)
  case image(InputImageContent)
  case file(InputFileContent)

  public init(_ content: Components.Schemas.InputContent) {
    switch content {
    case .InputTextContent(let textContent):
      self = .text(InputTextContent(text: textContent.text))
    case .InputImageContent(let imageContent):
      let detail: InputImageContent.Detail
      switch imageContent.detail {
      case .low: detail = .low
      case .high: detail = .high
      case .auto: detail = .auto
      }
      self = .image(
        InputImageContent(
          imageUrl: imageContent.imageUrl?.value1,
          fileId: imageContent.fileId?.value1,
          detail: detail
        )
      )
    case .InputFileContent(let fileContent):
      self = .file(
        InputFileContent(
          fileId: fileContent.fileId?.value1,
          filename: fileContent.filename,
          fileData: fileContent.fileData
        )
      )
    }
  }

  public func toOpenAPI() -> Components.Schemas.InputContent {
    switch self {
    case .text(let textContent):
      return .InputTextContent(textContent.toOpenAPI())
    case .image(let imageContent):
      return .InputImageContent(imageContent.toOpenAPI())
    case .file(let fileContent):
      return .InputFileContent(fileContent.toOpenAPI())
    }
  }
}

public struct InputMessage {
  public enum Role: String {
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

  public enum Status: String {
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
