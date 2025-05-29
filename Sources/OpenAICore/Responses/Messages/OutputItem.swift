public enum OutputItem: Sendable {
  case message(OutputMessage)
  case fileSearchToolCall(Components.Schemas.FileSearchToolCall)
  case functionToolCall(Components.Schemas.FunctionToolCall)
  case webSearchToolCall(Components.Schemas.WebSearchToolCall)
  case computerToolCall(Components.Schemas.ComputerToolCall)
  case reasoning(Components.Schemas.ReasoningItem)
  case imageGenToolCall(Components.Schemas.ImageGenToolCall)
  case codeInterpreterToolCall(Components.Schemas.CodeInterpreterToolCall)
  case localShellToolCall(Components.Schemas.LocalShellToolCall)
  case mcpToolCall(Components.Schemas.MCPToolCall)
  case mcpListTools(Components.Schemas.MCPListTools)
  case mcpApprovalRequest(Components.Schemas.MCPApprovalRequest)

  public init?(_ openAPI: Components.Schemas.OutputItem) {
    if let message = openAPI.value1 {
      self = .message(OutputMessage(message))
    } else if let fileSearchToolCall = openAPI.value2 {
      self = .fileSearchToolCall(fileSearchToolCall)
    } else if let functionToolCall = openAPI.value3 {
      self = .functionToolCall(functionToolCall)
    } else if let webSearchToolCall = openAPI.value4 {
      self = .webSearchToolCall(webSearchToolCall)
    } else if let computerToolCall = openAPI.value5 {
      self = .computerToolCall(computerToolCall)
    } else if let reasoning = openAPI.value6 {
      self = .reasoning(reasoning)
    } else if let imageGenToolCall = openAPI.value7 {
      self = .imageGenToolCall(imageGenToolCall)
    } else if let codeInterpreterToolCall = openAPI.value8 {
      self = .codeInterpreterToolCall(codeInterpreterToolCall)
    } else if let localShellToolCall = openAPI.value9 {
      self = .localShellToolCall(localShellToolCall)
    } else if let mcpToolCall = openAPI.value10 {
      self = .mcpToolCall(mcpToolCall)
    } else if let mcpListTools = openAPI.value11 {
      self = .mcpListTools(mcpListTools)
    } else if let mcpApprovalRequest = openAPI.value12 {
      self = .mcpApprovalRequest(mcpApprovalRequest)
    } else {
      print("Failed to parse OutputItem: \(openAPI)")
      return nil
    }
  }
}
