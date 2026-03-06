import Foundation
import OpenAICore
import OpenAIFoundation

/// Emits textual model output as deltas and completed chunks.
///
/// This plugin listens to `response.output_text.*` raw events and projects them
/// into a compact event model suitable for chat rendering.
@available(macOS 15.0, *)
public struct TextPlugin: ResponseStreamPlugin {
  /// Typed text output events.
  public enum Event: Sendable, Equatable {
    /// A partial text delta from the model.
    case delta(String)
    /// A completed text segment from the model.
    case completed(String)
  }

  /// Creates a text projection plugin.
  public init() {}

  public func consume(
    _ event: StreamingResponse,
    context: inout StreamPluginContext
  ) async throws -> Event? {
    guard case .outputText(let text) = event else { return nil }

    switch text {
    case .delta(let delta, _, _, _):
      return .delta(delta)
    case .done(let text, _, _, _):
      return .completed(text)
    case .annotation:
      return nil
    }
  }
}

/// Handles function tool calls and emits tool execution lifecycle events.
///
/// `ToolOrchestratorPlugin` can execute tools from its own plugin-local
/// registry. If a tool is not found there, it falls back to session-level tool
/// registration through ``StreamPluginContext/callFunctionTool(named:arguments:)``.
@available(macOS 15.0, *)
public struct ToolOrchestratorPlugin: ResponseStreamPlugin {
  /// Typed tool orchestration events.
  public enum Event: Sendable, Equatable {
    /// A function tool call was executed and its output captured.
    case executed(name: String, arguments: String, callID: String, output: String)
  }

  private let registry: FunctionToolRegistry
  private let errorPolicyOverride: ToolErrorPolicy?
  private let toolCallMessaging: any ToolCallMessaging

  /// Creates a tool orchestrator with optional plugin-local tools.
  ///
  /// - Parameters:
  ///   - tools: Function tools owned by this plugin.
  ///   - errorPolicy: Optional override for tool error behavior. If omitted,
  ///     session-level policy is used for fallback lookup, while plugin-local
  ///     tools default to fail-fast.
  ///   - toolCallMessaging: Observability hooks for tool call parsing failures.
  public init(
    tools: [any Toolable] = [],
    errorPolicy: ToolErrorPolicy? = nil,
    toolCallMessaging: any ToolCallMessaging = DefaultToolCallMessaging()
  ) {
    self.registry = FunctionToolRegistry(tools: tools)
    self.errorPolicyOverride = errorPolicy
    self.toolCallMessaging = toolCallMessaging
  }

  /// Registers a function tool in this plugin's local registry.
  ///
  /// Plugin-local tools are preferred over session-level tools when resolving
  /// function call events.
  ///
  /// - Parameter tool: A function tool implementation.
  public func register(tool: any Toolable) async {
    await registry.register(tool: tool)
  }

  /// Returns a copy of this plugin after registering a tool.
  ///
  /// This helper enables fluent construction:
  ///
  /// ```swift
  /// let plugin = ToolOrchestratorPlugin()
  ///   .registering(tool: WeatherTool(...))
  /// ```
  ///
  /// - Parameter tool: A function tool implementation.
  /// - Returns: The same plugin value after registration.
  @discardableResult
  public func registering(tool: any Toolable) async -> Self {
    await register(tool: tool)
    return self
  }

  public func consume(
    _ event: StreamingResponse,
    context: inout StreamPluginContext
  ) async throws -> Event? {
    guard case .outputItem(.done(let item, _)) = event else { return nil }
    guard case .functionToolCall(let toolCall) = item else { return nil }

    let output: String
    if let tool = await registry.tool(named: toolCall.name) {
      let localPolicy = errorPolicyOverride ?? .failFast
      output = try await executeToolWithPolicy(
        named: toolCall.name,
        policy: localPolicy
      ) {
        try await tool.call(arguments: toolCall.arguments, messaging: toolCallMessaging)
      }
    } else {
      output = try await context.callFunctionTool(
        named: toolCall.name,
        arguments: toolCall.arguments,
        errorPolicy: errorPolicyOverride
      )
    }

    context.enqueueFollowUpItem(
      .functionCallOutputItemParam(
        .init(callId: toolCall.callId, output: output)
      )
    )

    return .executed(
      name: toolCall.name,
      arguments: toolCall.arguments,
      callID: toolCall.callId,
      output: output
    )
  }
}

/// Emits image generation lifecycle events from the response stream.
///
/// This plugin surfaces partial image frames and final image call completion
/// metadata.
@available(macOS 15.0, *)
public struct ImagePlugin: ResponseStreamPlugin {
  /// Typed image generation events.
  public enum Event: Sendable, Equatable {
    /// A partial image frame from an in-progress generation call.
    case partial(
      itemID: String,
      outputIndex: Int,
      base64: String,
      partialIndex: Int,
      sequenceNumber: Int
    )
    /// A completed image generation call and optional final base64 image.
    case completed(itemID: String, status: String, resultBase64: String?)
  }

  /// Creates an image projection plugin.
  public init() {}

  public func consume(
    _ event: StreamingResponse,
    context: inout StreamPluginContext
  ) async throws -> Event? {
    switch event {
    case .imageGenCall(
      .partialImage(
        let itemID,
        let outputIndex,
        let partialImageBase64,
        let partialImageIndex,
        let sequenceNumber
      )
    ):
      return .partial(
        itemID: itemID,
        outputIndex: outputIndex,
        base64: partialImageBase64,
        partialIndex: partialImageIndex,
        sequenceNumber: sequenceNumber
      )

    case .outputItem(.done(.imageGenToolCall(let item), _)):
      return .completed(
        itemID: item.id,
        status: item.status.rawValue,
        resultBase64: item.result
      )

    default:
      return nil
    }
  }
}

private actor FunctionToolRegistry {
  private var tools: [String: any Toolable]

  init(tools: [any Toolable]) {
    self.tools = Dictionary(uniqueKeysWithValues: tools.map { ($0.name, $0) })
  }

  func register(tool: any Toolable) {
    tools[tool.name] = tool
  }

  func tool(named name: String) -> (any Toolable)? {
    return tools[name]
  }
}
