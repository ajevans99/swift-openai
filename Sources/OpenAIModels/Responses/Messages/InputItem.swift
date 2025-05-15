public enum Item {
  case inputMessage(InputMessage)
  case outputMessage(OutputMessage)

  case fileSearchToolCall(Components.Schemas.FileSearchToolCall)
  case computerToolCall(Components.Schemas.ComputerToolCall)
  case computerCallOutputItemParam(Components.Schemas.ComputerCallOutputItemParam)
  case webSearchToolCall(Components.Schemas.WebSearchToolCall)
  case functionToolCall(Components.Schemas.FunctionToolCall)
  case functionCallOutputItemParam(Components.Schemas.FunctionCallOutputItemParam)
  case reasoningItem(Components.Schemas.ReasoningItem)

  public init(_ item: Components.Schemas.Item) {
    switch item {
    case .inputMessage(let inputMessage):
      self = .inputMessage(InputMessage(inputMessage))
    case .outputMessage(let outputMessage):
      self = .outputMessage(OutputMessage(outputMessage))
    case .fileSearchToolCall(let fileSearchToolCall):
      self = .fileSearchToolCall(fileSearchToolCall)
    case .computerToolCall(let computerToolCall):
      self = .computerToolCall(computerToolCall)
    case .computerCallOutputItemParam(let computerCallOutputItemParam):
      self = .computerCallOutputItemParam(computerCallOutputItemParam)
    case .webSearchToolCall(let webSearchToolCall):
      self = .webSearchToolCall(webSearchToolCall)
    case .functionToolCall(let functionToolCall):
      self = .functionToolCall(functionToolCall)
    case .functionCallOutputItemParam(let functionCallOutputItemParam):
      self = .functionCallOutputItemParam(functionCallOutputItemParam)
    case .reasoningItem(let reasoningItem):
      self = .reasoningItem(reasoningItem)
    }
  }

  public func toOpenAPI() -> Components.Schemas.Item {
    switch self {
    case .inputMessage(let inputMessage):
      return .inputMessage(inputMessage.toOpenAPI())
    case .outputMessage(let outputMessage):
      return .outputMessage(outputMessage.toOpenAPI())
    case .fileSearchToolCall(let fileSearchToolCall):
      return .fileSearchToolCall(fileSearchToolCall)
    case .computerToolCall(let computerToolCall):
      return .computerToolCall(computerToolCall)
    case .computerCallOutputItemParam(let computerCallOutputItemParam):
      return .computerCallOutputItemParam(computerCallOutputItemParam)
    case .webSearchToolCall(let webSearchToolCall):
      return .webSearchToolCall(webSearchToolCall)
    case .functionToolCall(let functionToolCall):
      return .functionToolCall(functionToolCall)
    case .functionCallOutputItemParam(let functionCallOutputItemParam):
      return .functionCallOutputItemParam(functionCallOutputItemParam)
    case .reasoningItem(let reasoningItem):
      return .reasoningItem(reasoningItem)
    }
  }
}

public struct EasyInputMessage {
  public enum Role {
    case user
    case assistant
    case system
    case developer

    public func toOpenAPI() -> Components.Schemas.EasyInputMessage.RolePayload {
      switch self {
      case .user: return .user
      case .assistant: return .assistant
      case .system: return .system
      case .developer: return .developer
      }
    }
  }

  public enum Content {
    case text(String)
    case contentList([InputContent])

    public func toOpenAPI() -> Components.Schemas.EasyInputMessage.ContentPayload {
      switch self {
      case .text(let text):
        return .case1(text)
      case .contentList(let content):
        return .InputMessageContentList(content.map { $0.toOpenAPI() })
      }
    }
  }

  public let role: Role
  public let content: Content

  public init(
    role: Role,
    content: Content
  ) {
    self.role = role
    self.content = content
  }

  public init(_ message: Components.Schemas.EasyInputMessage) {
    self.role =
      switch message.role {
      case .user: .user
      case .assistant: .assistant
      case .system: .system
      case .developer: .developer
      }

    self.content =
      switch message.content {
      case .case1(let text):
        .text(text)
      case .InputMessageContentList(let content):
        .contentList(content.map { InputContent($0) })
      }
  }

  public func toOpenAPI() -> Components.Schemas.EasyInputMessage {
    Components.Schemas.EasyInputMessage(
      role: role.toOpenAPI(),
      content: content.toOpenAPI(),
      _type: .message
    )
  }
}

public enum InputItem {
  case easyInputMessage(EasyInputMessage)
  case item(Item)
  case itemReferenceParam(Components.Schemas.ItemReferenceParam)

  public init(_ item: Components.Schemas.InputItem) {
    switch item {
    case .easyInputMessage(let easyInputMessage):
      self = .easyInputMessage(EasyInputMessage(easyInputMessage))
    case .item(let item):
      self = .item(Item(item))
    case .itemReferenceParam(let itemReferenceParam):
      self = .itemReferenceParam(itemReferenceParam)
    }
  }

  public func toOpenAPI() -> Components.Schemas.InputItem {
    switch self {
    case .easyInputMessage(let easyInputMessage):
      return .easyInputMessage(easyInputMessage.toOpenAPI())
    case .item(let item):
      return .item(item.toOpenAPI())
    case .itemReferenceParam(let itemReferenceParam):
      return .itemReferenceParam(itemReferenceParam)
    }
  }
}
