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
    self.description = tool.description
    if let parameters = tool.parameters {
      var mapped: [String: OpenAPIValueContainer] = [:]
      for (key, value) in parameters.value {
        mapped[key] =
          (try? OpenAPIValueContainer(unvalidatedValue: value))
          ?? OpenAPIValueContainer(nilLiteral: ())
      }
      self.parameters = mapped
    } else {
      self.parameters = [:]
    }
    self.strict = tool.strict ?? true
  }

  public func toOpenAPI() -> Components.Schemas.FunctionTool {
    let parameterObject: OpenAPIObjectContainer?
    if parameters.isEmpty {
      parameterObject = nil
    } else {
      parameterObject = try? OpenAPIObjectContainer(
        unvalidatedValue: parameters.mapValues(\.value)
      )
    }

    return Components.Schemas.FunctionTool(
      _type: .function,
      name: name,
      description: description,
      parameters: parameterObject,
      strict: strict
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
    self.output =
      switch toolCallOutputItemParam.output {
      case .case1(let output): output
      case .case2: ""
      }
    self.id = nil
    self.status = nil
  }

  public func toOpenAPI() -> Components.Schemas.FunctionCallOutputItemParam {
    // ID and status should not be sent to the API
    Components.Schemas.FunctionCallOutputItemParam(
      callId: callId,
      _type: .functionCallOutput,
      output: .case1(output)
    )
  }
}
