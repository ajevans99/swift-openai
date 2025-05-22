import OpenAPIRuntime

public struct FunctionTool: Sendable {
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

public struct FunctionToolCall: Sendable {
  public enum Status: Sendable {
    case inProgress
    case completed
    case incomplete

    public func toOpenAPI() -> Components.Schemas.FunctionToolCall.StatusPayload {
      switch self {
      case .inProgress:
        return .inProgress
      case .completed:
        return .completed
      case .incomplete:
        return .incomplete
      }
    }
  }
  public let arguments: String
  public let callId: String
  public let name: String
  public let id: String?
  public let status: Status?

  public init(
    arguments: String,
    callId: String,
    name: String,
    id: String? = nil,
    status: Status? = nil
  ) {
    self.arguments = arguments
    self.callId = callId
    self.name = name
    self.id = id
    self.status = status
  }

  public init(_ toolCall: Components.Schemas.FunctionToolCall) {
    self.arguments = toolCall.arguments
    self.callId = toolCall.callId
    self.name = toolCall.name
    self.id = toolCall.id
    self.status =
      switch toolCall.status {
      case .inProgress:
        .inProgress
      case .completed:
        .completed
      case .incomplete:
        .incomplete
      case .none:
        nil
      }
  }

  public func toOpenAPI() -> Components.Schemas.FunctionToolCall {
    Components.Schemas.FunctionToolCall(
      id: id,
      _type: .functionCall,
      callId: callId,
      name: name,
      arguments: arguments,
      status: status?.toOpenAPI()
    )
  }
}

public struct FunctionToolCallOutputItemParam: Sendable {
  public enum Status: Sendable {
    case inProgress
    case completed
    case incomplete

    public init(
      _ status: Components.Schemas.FunctionCallOutputItemParam.StatusPayload.Value1Payload
    ) {
      switch status {
      case .inProgress:
        self = .inProgress
      case .completed:
        self = .completed
      case .incomplete:
        self = .incomplete
      }
    }
  }

  public let callId: String
  public let output: String
  public let id: String?
  public let status: Status?

  public init(
    callId: String,
    output: String
  ) {
    self.callId = callId
    self.output = output
    self.id = nil  // Populated when returned by the API
    self.status = nil  // Populated when returned by the API
  }

  public init(_ toolCallOutputItemParam: Components.Schemas.FunctionCallOutputItemParam) {
    self.callId = toolCallOutputItemParam.callId
    self.output = toolCallOutputItemParam.output
    self.id = toolCallOutputItemParam.id?.value1
    self.status = toolCallOutputItemParam.status?.value1.map(Status.init)
  }

  public func toOpenAPI() -> Components.Schemas.FunctionCallOutputItemParam {
    // ID and status should not be sent to the API
    Components.Schemas.FunctionCallOutputItemParam(
      callId: callId,
      _type: .functionCallOutput,
      output: output
    )
  }
}
