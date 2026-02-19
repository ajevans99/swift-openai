import Foundation
import OpenAPIRuntime

public enum Tool: Sendable {
  case function(FunctionTool)
  case fileSearch(Components.Schemas.FileSearchTool)
  case webSearch(Components.Schemas.WebSearchTool)
  case webSearchPreview(Components.Schemas.WebSearchPreviewTool)
  case computer(Components.Schemas.ComputerUsePreviewTool)
  case mcp(Components.Schemas.MCPTool)
  case codeInterpreter(Components.Schemas.CodeInterpreterTool)
  case imageGen(ImageGenTool)
  case localShell(Components.Schemas.LocalShellToolParam)

  public init(_ tool: Components.Schemas.Tool) {
    switch tool {
    case .functionTool(let value):
      self = .function(FunctionTool(value))
    case .fileSearchTool(let value):
      self = .fileSearch(value)
    case .webSearchTool(let value):
      self = .webSearch(value)
    case .computerUsePreviewTool(let value):
      self = .computer(value)
    case .mcpTool(let value):
      self = .mcp(value)
    case .codeInterpreterTool(let value):
      self = .codeInterpreter(value)
    case .imageGenTool(let value):
      self = .imageGen(ImageGenTool(value))
    case .localShellToolParam(let value):
      self = .localShell(value)
    case .webSearchPreviewTool(let value):
      self = .webSearchPreview(value)
    default:
      fatalError("Unsupported tool case")
    }
  }

  public func toOpenAPI() -> Components.Schemas.Tool {
    switch self {
    case .function(let value):
      return .functionTool(value.toOpenAPI())
    case .fileSearch(let value):
      return .fileSearchTool(value)
    case .webSearch(let value):
      return .webSearchTool(value)
    case .webSearchPreview(let value):
      return .webSearchPreviewTool(value)
    case .computer(let value):
      return .computerUsePreviewTool(value)
    case .mcp(let value):
      return .mcpTool(value)
    case .codeInterpreter(let value):
      return .codeInterpreterTool(value)
    case .imageGen(let value):
      return .imageGenTool(value.toOpenAPI())
    case .localShell(let value):
      return .localShellToolParam(value)
    }
  }
}
