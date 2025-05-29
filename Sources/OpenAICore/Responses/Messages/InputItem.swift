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
    if let value = item.value1 {
      self = .inputMessage(InputMessage(value))
    } else if let value = item.value2 {
      self = .outputMessage(OutputMessage(value))
    } else if let value = item.value3 {
      self = .fileSearchToolCall(value)
    } else if let value = item.value4 {
      self = .computerToolCall(value)
    } else if let value = item.value5 {
      self = .computerCallOutputItemParam(value)
    } else if let value = item.value6 {
      self = .webSearchToolCall(value)
    } else if let value = item.value7 {
      self = .functionToolCall(FunctionToolCall(value))
    } else if let value = item.value8 {
      self = .functionCallOutputItemParam(FunctionToolCallOutputItemParam(value))
    } else if let value = item.value9 {
      self = .reasoningItem(value)
    } else if let value = item.value10 {
      self = .imageGenToolCall(value)
    } else if let value = item.value11 {
      self = .codeInterpreterToolCall(value)
    } else if let value = item.value12 {
      self = .localShellToolCall(value)
    } else if let value = item.value13 {
      self = .localShellToolCallOutput(value)
    } else if let value = item.value14 {
      self = .mcpListTools(value)
    } else if let value = item.value15 {
      self = .mcpApprovalRequest(value)
    } else if let value = item.value16 {
      self = .mcpApprovalResponse(value)
    } else if let value = item.value17 {
      self = .mcpToolCall(value)
    } else {
      fatalError("No value found in Item")
    }
  }

  public func toOpenAPI() -> Components.Schemas.Item {
    var item = Components.Schemas.Item()
    switch self {
    case .inputMessage(let value):
      item.value1 = value.toOpenAPI()
    case .outputMessage(let value):
      item.value2 = value.toOpenAPI()
    case .fileSearchToolCall(let value):
      item.value3 = value
    case .computerToolCall(let value):
      item.value4 = value
    case .computerCallOutputItemParam(let value):
      item.value5 = value
    case .webSearchToolCall(let value):
      item.value6 = value
    case .functionToolCall(let value):
      item.value7 = value.toOpenAPI()
    case .functionCallOutputItemParam(let value):
      item.value8 = value.toOpenAPI()
    case .reasoningItem(let value):
      item.value9 = value
    case .imageGenToolCall(let value):
      item.value10 = value
    case .codeInterpreterToolCall(let value):
      item.value11 = value
    case .localShellToolCall(let value):
      item.value12 = value
    case .localShellToolCallOutput(let value):
      item.value13 = value
    case .mcpListTools(let value):
      item.value14 = value
    case .mcpApprovalRequest(let value):
      item.value15 = value
    case .mcpApprovalResponse(let value):
      item.value16 = value
    case .mcpToolCall(let value):
      item.value17 = value
    }
    return item
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
        return Components.Schemas.EasyInputMessage.ContentPayload(value1: text)
      case .contentList(let content):
        return Components.Schemas.EasyInputMessage.ContentPayload(
          value2: content.map { $0.toOpenAPI() })
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
      if let text = message.content.value1 {
        .text(text)
      } else if let contentList = message.content.value2 {
        .contentList(contentList.map { InputContent($0) })
      } else {
        .text("")  // Default to empty text if no content is provided
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
    if let message = item.value1 {
      self = .easyInputMessage(EasyInputMessage(message))
    } else if let item = item.value2 {
      self = .item(Item(item))
    } else if let reference = item.value3 {
      self = .itemReferenceParam(reference)
    } else {
      fatalError("No value found in InputItem")
    }
  }

  public func toOpenAPI() -> Components.Schemas.InputItem {
    switch self {
    case .easyInputMessage(let easyInputMessage):
      return .init(value1: easyInputMessage.toOpenAPI())
    case .item(let item):
      return .init(value2: item.toOpenAPI())
    case .itemReferenceParam(let itemReferenceParam):
      return .init(value3: itemReferenceParam)
    }
  }
}
