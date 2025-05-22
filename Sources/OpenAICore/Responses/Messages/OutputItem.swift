public enum OutputItem: Sendable {
  case message(OutputMessage)
  case fileSearchToolCall(Components.Schemas.FileSearchToolCall)
  case functionToolCall(Components.Schemas.FunctionToolCall)
  case webSearchToolCall(Components.Schemas.WebSearchToolCall)
  case computerToolCall(Components.Schemas.ComputerToolCall)
  case reasoning(Components.Schemas.ReasoningItem)

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
    } else {
      return nil
    }
  }
}
