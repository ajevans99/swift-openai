public enum Item: Sendable {
  case inputMessage(InputMessage)
  case outputMessage(OutputMessage)
  case functionToolCall(FunctionToolCall)
  case functionCallOutputItemParam(FunctionToolCallOutputItemParam)
  case fileSearchToolCall(Components.Schemas.FileSearchToolCall)
  case computerToolCall(Components.Schemas.ComputerToolCall)
  case computerCallOutputItemParam(Components.Schemas.ComputerCallOutputItemParam)
  case webSearchToolCall(Components.Schemas.WebSearchToolCall)
  case reasoningItem(Components.Schemas.ReasoningItem)
  case imageGenToolCall(Components.Schemas.ImageGenToolCall)
  case codeInterpreterToolCall(Components.Schemas.CodeInterpreterToolCall)
  case localShellToolCall(Components.Schemas.LocalShellToolCall)
  case localShellToolCallOutput(Components.Schemas.LocalShellToolCallOutput)
  case mcpListTools(Components.Schemas.MCPListTools)
  case mcpApprovalRequest(Components.Schemas.MCPApprovalRequest)
  case mcpApprovalResponse(Components.Schemas.MCPApprovalResponse)
  case mcpToolCall(Components.Schemas.MCPToolCall)

  public init(_ item: Components.Schemas.Item) {
    switch item {
    case .inputMessage(let value):
      self = .inputMessage(InputMessage(value))
    case .outputMessage(let value):
      self = .outputMessage(OutputMessage(value))
    case .fileSearchToolCall(let value):
      self = .fileSearchToolCall(value)
    case .computerToolCall(let value):
      self = .computerToolCall(value)
    case .computerCallOutputItemParam(let value):
      self = .computerCallOutputItemParam(value)
    case .webSearchToolCall(let value):
      self = .webSearchToolCall(value)
    case .functionToolCall(let value):
      self = .functionToolCall(FunctionToolCall(value))
    case .functionCallOutputItemParam(let value):
      self = .functionCallOutputItemParam(FunctionToolCallOutputItemParam(value))
    case .reasoningItem(let value):
      self = .reasoningItem(value)
    case .imageGenToolCall(let value):
      self = .imageGenToolCall(value)
    case .codeInterpreterToolCall(let value):
      self = .codeInterpreterToolCall(value)
    case .localShellToolCall(let value):
      self = .localShellToolCall(value)
    case .localShellToolCallOutput(let value):
      self = .localShellToolCallOutput(value)
    case .mcpListTools(let value):
      self = .mcpListTools(value)
    case .mcpApprovalRequest(let value):
      self = .mcpApprovalRequest(value)
    case .mcpApprovalResponse(let value):
      self = .mcpApprovalResponse(value)
    case .mcpToolCall(let value):
      self = .mcpToolCall(value)
    default:
      fatalError("Unsupported Item case for OpenAICore wrapper")
    }
  }

  public func toOpenAPI() -> Components.Schemas.Item {
    switch self {
    case .inputMessage(let value):
      return .inputMessage(value.toOpenAPI())
    case .outputMessage(let value):
      return .outputMessage(value.toOpenAPI())
    case .fileSearchToolCall(let value):
      return .fileSearchToolCall(value)
    case .computerToolCall(let value):
      return .computerToolCall(value)
    case .computerCallOutputItemParam(let value):
      return .computerCallOutputItemParam(value)
    case .webSearchToolCall(let value):
      return .webSearchToolCall(value)
    case .functionToolCall(let value):
      return .functionToolCall(value.toOpenAPI())
    case .functionCallOutputItemParam(let value):
      return .functionCallOutputItemParam(value.toOpenAPI())
    case .reasoningItem(let value):
      return .reasoningItem(value)
    case .imageGenToolCall(let value):
      return .imageGenToolCall(value)
    case .codeInterpreterToolCall(let value):
      return .codeInterpreterToolCall(value)
    case .localShellToolCall(let value):
      return .localShellToolCall(value)
    case .localShellToolCallOutput(let value):
      return .localShellToolCallOutput(value)
    case .mcpListTools(let value):
      return .mcpListTools(value)
    case .mcpApprovalRequest(let value):
      return .mcpApprovalRequest(value)
    case .mcpApprovalResponse(let value):
      return .mcpApprovalResponse(value)
    case .mcpToolCall(let value):
      return .mcpToolCall(value)
    }
  }
}

public struct EasyInputMessage: Sendable {
  public enum Role: Sendable {
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

  public enum Content: Sendable {
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
      case .case1(let text): .text(text)
      case .InputMessageContentList(let contentList): .contentList(contentList.map { InputContent($0) })
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

public enum InputItem: Sendable {
  case easyInputMessage(EasyInputMessage)
  case item(Item)
  case itemReferenceParam(Components.Schemas.ItemReferenceParam)

  public init(_ item: Components.Schemas.InputItem) {
    switch item {
    case .easyInputMessage(let message):
      self = .easyInputMessage(EasyInputMessage(message))
    case .item(let item):
      self = .item(Item(item))
    case .itemReferenceParam(let reference):
      self = .itemReferenceParam(reference)
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
