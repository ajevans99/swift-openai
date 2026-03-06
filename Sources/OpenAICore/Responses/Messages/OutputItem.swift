public enum OutputItem: Sendable {
  case message(OutputMessage)
  case fileSearchToolCall(Components.Schemas.FileSearchToolCall)
  case functionToolCall(Components.Schemas.FunctionToolCall)
  case webSearchToolCall(Components.Schemas.WebSearchToolCall)
  case computerToolCall(Components.Schemas.ComputerToolCall)
  case reasoning(Components.Schemas.ReasoningItem)
  case toolSearchCall(Components.Schemas.ToolSearchCall)
  case toolSearchOutput(Components.Schemas.ToolSearchOutput)
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
    } else if let toolSearchCall = openAPI.value7 {
      self = .toolSearchCall(toolSearchCall)
    } else if let toolSearchOutput = openAPI.value8 {
      self = .toolSearchOutput(toolSearchOutput)
    } else if let compactionBody = openAPI.value9 {
      self = .compactionBody(compactionBody)
    } else if let imageGenToolCall = openAPI.value10 {
      self = .imageGenToolCall(imageGenToolCall)
    } else if let codeInterpreterToolCall = openAPI.value11 {
      self = .codeInterpreterToolCall(codeInterpreterToolCall)
    } else if let localShellToolCall = openAPI.value12 {
      self = .localShellToolCall(localShellToolCall)
    } else if let functionShellCall = openAPI.value13 {
      self = .functionShellCall(functionShellCall)
    } else if let functionShellCallOutput = openAPI.value14 {
      self = .functionShellCallOutput(functionShellCallOutput)
    } else if let applyPatchToolCall = openAPI.value15 {
      self = .applyPatchToolCall(applyPatchToolCall)
    } else if let applyPatchToolCallOutput = openAPI.value16 {
      self = .applyPatchToolCallOutput(applyPatchToolCallOutput)
    } else if let mcpToolCall = openAPI.value17 {
      self = .mcpToolCall(mcpToolCall)
    } else if let mcpListTools = openAPI.value18 {
      self = .mcpListTools(mcpListTools)
    } else if let mcpApprovalRequest = openAPI.value19 {
      self = .mcpApprovalRequest(mcpApprovalRequest)
    } else if let customToolCall = openAPI.value20 {
      self = .customToolCall(customToolCall)
    } else {
      print("Failed to parse OutputItem: \(openAPI)")
      return nil
    }
  }
}
