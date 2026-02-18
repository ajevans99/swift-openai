public enum OutputItem: Sendable {
  case message(OutputMessage)
  case fileSearchToolCall(Components.Schemas.FileSearchToolCall)
  case functionToolCall(Components.Schemas.FunctionToolCall)
  case webSearchToolCall(Components.Schemas.WebSearchToolCall)
  case computerToolCall(Components.Schemas.ComputerToolCall)
  case reasoning(Components.Schemas.ReasoningItem)
  case compactionBody(Components.Schemas.CompactionBody)
  case imageGenToolCall(Components.Schemas.ImageGenToolCall)
  case codeInterpreterToolCall(Components.Schemas.CodeInterpreterToolCall)
  case localShellToolCall(Components.Schemas.LocalShellToolCall)
  case functionShellCall(Components.Schemas.FunctionShellCall)
  case functionShellCallOutput(Components.Schemas.FunctionShellCallOutput)
  case applyPatchToolCall(Components.Schemas.ApplyPatchToolCall)
  case applyPatchToolCallOutput(Components.Schemas.ApplyPatchToolCallOutput)
  case mcpToolCall(Components.Schemas.MCPToolCall)
  case mcpListTools(Components.Schemas.MCPListTools)
  case mcpApprovalRequest(Components.Schemas.MCPApprovalRequest)
  case customToolCall(Components.Schemas.CustomToolCall)

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
    } else if let compactionBody = openAPI.value7 {
      self = .compactionBody(compactionBody)
    } else if let imageGenToolCall = openAPI.value8 {
      self = .imageGenToolCall(imageGenToolCall)
    } else if let codeInterpreterToolCall = openAPI.value9 {
      self = .codeInterpreterToolCall(codeInterpreterToolCall)
    } else if let localShellToolCall = openAPI.value10 {
      self = .localShellToolCall(localShellToolCall)
    } else if let functionShellCall = openAPI.value11 {
      self = .functionShellCall(functionShellCall)
    } else if let functionShellCallOutput = openAPI.value12 {
      self = .functionShellCallOutput(functionShellCallOutput)
    } else if let applyPatchToolCall = openAPI.value13 {
      self = .applyPatchToolCall(applyPatchToolCall)
    } else if let applyPatchToolCallOutput = openAPI.value14 {
      self = .applyPatchToolCallOutput(applyPatchToolCallOutput)
    } else if let mcpToolCall = openAPI.value15 {
      self = .mcpToolCall(mcpToolCall)
    } else if let mcpListTools = openAPI.value16 {
      self = .mcpListTools(mcpListTools)
    } else if let mcpApprovalRequest = openAPI.value17 {
      self = .mcpApprovalRequest(mcpApprovalRequest)
    } else if let customToolCall = openAPI.value18 {
      self = .customToolCall(customToolCall)
    } else {
      print("Failed to parse OutputItem: \(openAPI)")
      return nil
    }
  }
}
