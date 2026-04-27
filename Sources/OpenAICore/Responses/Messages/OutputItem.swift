public enum OutputItem: Sendable {
  case message(OutputMessage)
  case fileSearchToolCall(Components.Schemas.FileSearchToolCall)
  case functionToolCall(Components.Schemas.FunctionToolCall)
  case functionToolCallOutputResource(Components.Schemas.FunctionToolCallOutputResource)
  case webSearchToolCall(Components.Schemas.WebSearchToolCall)
  case computerToolCall(Components.Schemas.ComputerToolCall)
  case computerToolCallOutputResource(Components.Schemas.ComputerToolCallOutputResource)
  case toolSearchCall(Components.Schemas.ToolSearchCall)
  case toolSearchOutput(Components.Schemas.ToolSearchOutput)
  case compactionBody(Components.Schemas.CompactionBody)
  case imageGenToolCall(Components.Schemas.ImageGenToolCall)
  case codeInterpreterToolCall(Components.Schemas.CodeInterpreterToolCall)
  case localShellToolCall(Components.Schemas.LocalShellToolCall)
  case localShellToolCallOutput(Components.Schemas.LocalShellToolCallOutput)
  case functionShellCall(Components.Schemas.FunctionShellCall)
  case functionShellCallOutput(Components.Schemas.FunctionShellCallOutput)
  case applyPatchToolCall(Components.Schemas.ApplyPatchToolCall)
  case applyPatchToolCallOutput(Components.Schemas.ApplyPatchToolCallOutput)
  case mcpToolCall(Components.Schemas.MCPToolCall)
  case mcpListTools(Components.Schemas.MCPListTools)
  case mcpApprovalRequest(Components.Schemas.MCPApprovalRequest)
  case mcpApprovalResponseResource(Components.Schemas.MCPApprovalResponseResource)
  case customToolCall(Components.Schemas.CustomToolCall)
  case customToolCallOutputResource(Components.Schemas.CustomToolCallOutputResource)

  public init?(_ openAPI: Components.Schemas.OutputItem) {
    switch openAPI {
    case .outputMessage(let message):
      self = .message(OutputMessage(message))
    case .fileSearchToolCall(let fileSearchToolCall):
      self = .fileSearchToolCall(fileSearchToolCall)
    case .functionToolCall(let functionToolCall):
      self = .functionToolCall(functionToolCall)
    case .functionToolCallOutputResource(let functionToolCallOutputResource):
      self = .functionToolCallOutputResource(functionToolCallOutputResource)
    case .webSearchToolCall(let webSearchToolCall):
      self = .webSearchToolCall(webSearchToolCall)
    case .computerToolCall(let computerToolCall):
      self = .computerToolCall(computerToolCall)
    case .computerToolCallOutputResource(let computerToolCallOutputResource):
      self = .computerToolCallOutputResource(computerToolCallOutputResource)
    case .reasoningItem:
      // Intentionally drop raw reasoning items; only provider-provided summaries may be surfaced.
      return nil
    case .toolSearchCall(let toolSearchCall):
      self = .toolSearchCall(toolSearchCall)
    case .toolSearchOutput(let toolSearchOutput):
      self = .toolSearchOutput(toolSearchOutput)
    case .compactionBody(let compactionBody):
      self = .compactionBody(compactionBody)
    case .imageGenToolCall(let imageGenToolCall):
      self = .imageGenToolCall(imageGenToolCall)
    case .codeInterpreterToolCall(let codeInterpreterToolCall):
      self = .codeInterpreterToolCall(codeInterpreterToolCall)
    case .localShellToolCall(let localShellToolCall):
      self = .localShellToolCall(localShellToolCall)
    case .localShellToolCallOutput(let localShellToolCallOutput):
      self = .localShellToolCallOutput(localShellToolCallOutput)
    case .functionShellCall(let functionShellCall):
      self = .functionShellCall(functionShellCall)
    case .functionShellCallOutput(let functionShellCallOutput):
      self = .functionShellCallOutput(functionShellCallOutput)
    case .applyPatchToolCall(let applyPatchToolCall):
      self = .applyPatchToolCall(applyPatchToolCall)
    case .applyPatchToolCallOutput(let applyPatchToolCallOutput):
      self = .applyPatchToolCallOutput(applyPatchToolCallOutput)
    case .mcpToolCall(let mcpToolCall):
      self = .mcpToolCall(mcpToolCall)
    case .mcpListTools(let mcpListTools):
      self = .mcpListTools(mcpListTools)
    case .mcpApprovalRequest(let mcpApprovalRequest):
      self = .mcpApprovalRequest(mcpApprovalRequest)
    case .mcpApprovalResponseResource(let mcpApprovalResponseResource):
      self = .mcpApprovalResponseResource(mcpApprovalResponseResource)
    case .customToolCall(let customToolCall):
      self = .customToolCall(customToolCall)
    case .customToolCallOutputResource(let customToolCallOutputResource):
      self = .customToolCallOutputResource(customToolCallOutputResource)
    }
  }
}
