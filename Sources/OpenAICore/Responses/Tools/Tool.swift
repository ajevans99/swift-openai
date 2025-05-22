import Foundation
import OpenAPIRuntime

public enum Tool: Sendable {
  case function(FunctionTool)
  case fileSearch(Components.Schemas.FileSearchTool)
  case webSearch(Components.Schemas.WebSearchPreviewTool)
  case computer(Components.Schemas.ComputerUsePreviewTool)
  case mcp(Components.Schemas.MCPTool)
  case codeInterpreter(Components.Schemas.CodeInterpreterTool)
  case imageGen(ImageGenTool)
  case localShell(Components.Schemas.LocalShellTool)

  public init(_ tool: Components.Schemas.Tool) {
    if let value = tool.value1 {
      self = .function(FunctionTool(value))
    } else if let value = tool.value2 {
      self = .fileSearch(value)
    } else if let value = tool.value3 {
      self = .webSearch(value)
    } else if let value = tool.value4 {
      self = .computer(value)
    } else if let value = tool.value5 {
      self = .mcp(value)
    } else if let value = tool.value6 {
      self = .codeInterpreter(value)
    } else if let value = tool.value7 {
      self = .imageGen(ImageGenTool(value))
    } else if let value = tool.value8 {
      self = .localShell(value)
    } else {
      fatalError("No tool value found")
    }
  }

  public func toOpenAPI() -> Components.Schemas.Tool {
    var tool = Components.Schemas.Tool()
    switch self {
    case .function(let value):
      tool.value1 = value.toOpenAPI()
    case .fileSearch(let value):
      tool.value2 = value
    case .webSearch(let value):
      tool.value3 = value
    case .computer(let value):
      tool.value4 = value
    case .mcp(let value):
      tool.value5 = value
    case .codeInterpreter(let value):
      tool.value6 = value
    case .imageGen(let value):
      tool.value7 = value.toOpenAPI()
    case .localShell(let value):
      tool.value8 = value
    }
    return tool
  }
}
