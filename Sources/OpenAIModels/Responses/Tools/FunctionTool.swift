import OpenAPIRuntime

public struct FunctionTool {
  public let name: String
  public let description: String?
  public let parameters: [String: OpenAPIValueContainer]
  public let strict: Bool

  public init(
    name: String,
    description: String? = nil,
    parameters: [String: OpenAPIValueContainer],
    strict: Bool = true
  ) {
    self.name = name
    self.description = description
    self.parameters = parameters
    self.strict = strict
  }

  public init(_ tool: Components.Schemas.FunctionTool) {
    self.name = tool.name
    self.description = tool.description?.value1
    self.parameters = tool.parameters.value1?.additionalProperties ?? [:]
    self.strict = tool.strict.value1 ?? true
  }

  public func toOpenAPI() -> Components.Schemas.FunctionTool {
    Components.Schemas.FunctionTool(
      _type: .function,
      name: name,
      description: description.map {
        Components.Schemas.FunctionTool.DescriptionPayload(value1: $0)
      },
      parameters: Components.Schemas.FunctionTool.ParametersPayload(
        value1: Components.Schemas.FunctionTool.ParametersPayload.Value1Payload(
          additionalProperties: parameters
        )
      ),
      strict: Components.Schemas.FunctionTool.StrictPayload(value1: strict)
    )
  }
}
