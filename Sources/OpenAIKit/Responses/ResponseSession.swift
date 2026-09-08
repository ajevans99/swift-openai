import Foundation
import OpenAICore

/// A high-level conversational session that wraps the OpenAI Responses API.
///
/// `ResponseSession` supports two interaction styles:
///
/// - Non-streaming turns through ``send(_:additionalItems:previousResponseID:)``.
/// - Streaming turns through ``stream(_:additionalItems:previousResponseID:plugins:)``
///   and related overloads.
///
/// Stream APIs produce both:
///
/// - Raw protocol events (`StreamingResponse`) via
///   ``ResponseStreamHandle/raw``.
/// - Typed plugin channels via ``ResponseStreamHandle/pluginEvents``.
///
/// ## Tool handling
///
/// - Session-level `register(tool:)` remains available for non-streaming turns
///   and for streaming fallback lookup.
/// - Prefer plugin-local tool registration on ``ToolOrchestratorPlugin`` for
///   streaming flows.
///
/// ## Event retention
///
/// Streaming channels are lossless and unbounded by default. Consumers should
/// drain every enabled channel concurrently or disable raw events through
/// ``ResponseStreamOptions``. Opt-in bounded channels fail explicitly instead
/// of silently truncating output.
public actor ResponseSession {
  public typealias Message = Item

  public struct RequestOptions: Sendable {
    public var reasoning: Reasoning?
    public var maxOutputTokens: Int?
    public var truncation: Truncation?
    /// Instructions used for this turn and all of its tool follow-up rounds.
    /// When omitted, the session's durable instructions are used.
    public var instructions: String?

    public init(
      reasoning: Reasoning? = nil,
      maxOutputTokens: Int? = nil,
      truncation: Truncation? = nil,
      instructions: String? = nil
    ) {
      self.reasoning = reasoning
      self.maxOutputTokens = maxOutputTokens
      self.truncation = truncation
      self.instructions = instructions
    }
  }

  private let client: OpenAI
  private let model: Model
  private let instructions: String?
  private let errorPolicy: ToolErrorPolicy
  private let toolCallMessaging: any ToolCallMessaging

  private var functionTools: [String: any Toolable] = [:]
  private var openAITools: [OpenAICore.Tool] = []

  var allTools: [OpenAICore.Tool] {
    functionTools.values.map { $0.toTool() } + openAITools
  }

  /// Creates a new response session.
  ///
  /// - Parameters:
  ///   - client: The configured OpenAI client.
  ///   - model: The model used for all turns in this session.
  ///   - instructions: Durable instructions resent on every response request,
  ///     including recursive tool follow-up rounds.
  ///   - errorPolicy: Behavior to apply when function tools fail.
  ///   - toolCallMessaging: Observability hooks for tool call parsing failures.
  public init(
    client: OpenAI,
    model: Model,
    instructions: String? = nil,
    errorPolicy: ToolErrorPolicy = .failFast,
    toolCallMessaging: any ToolCallMessaging = DefaultToolCallMessaging()
  ) {
    self.client = client
    self.model = model
    self.instructions = instructions
    self.errorPolicy = errorPolicy
    self.toolCallMessaging = toolCallMessaging
  }

  /// Registers a function tool on the session.
  ///
  /// This registry is used by:
  ///
  /// - Non-streaming tool orchestration (`send` recursion path).
  /// - Streaming fallback lookup from ``ToolOrchestratorPlugin`` when a tool is
  ///   not registered directly on the plugin.
  ///
  /// - Parameter tool: The tool to register.
  public func register(tool: any Toolable) {
    functionTools[tool.name] = tool
  }

  /// Registers a built-in OpenAI tool for response creation.
  ///
  /// Registered tools are sent on every request for session continuity.
  ///
  /// - Parameter openAITool: A built-in OpenAI tool descriptor.
  public func register(openAITool: OpenAICore.Tool) {
    openAITools.append(openAITool)
  }

  /// Sends a non-streaming user turn and returns the final assistant text.
  ///
  /// If the model emits function tool calls, the session executes them and
  /// recursively continues until the assistant emits a plain response.
  ///
  /// - Parameters:
  ///   - userText: User message content.
  ///   - additionalItems: Additional input items to include in the turn.
  ///   - previousResponseID: The prior response ID for conversation
  ///     continuation.
  ///   - requestOptions: Optional request-level response creation settings.
  /// - Returns: Final concatenated assistant text for the turn.
  @discardableResult
  public func send(
    _ userText: String,
    additionalItems: [Item] = [],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init()
  ) async throws -> String {
    let item = Item.inputMessage(
      InputMessage(role: .user, content: [.text(.init(text: userText))])
    )

    return try await advance(
      newItems: [.item(item)] + additionalItems.map(InputItem.item),
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions
    )
  }

  /// Sends a non-streaming turn from full typed conversational history.
  ///
  /// ``InputItem/easyInputMessage(_:)`` supports user, assistant, system, and
  /// developer messages. Tool and reasoning history can be supplied through
  /// ``InputItem/item(_:)``.
  @discardableResult
  public func send(
    inputItems: [InputItem],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init()
  ) async throws -> String {
    try await advance(
      newItems: inputItems,
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions
    )
  }

  /// Starts a streaming turn with typed plugin channel(s).
  ///
  /// - Parameters:
  ///   - userText: User message content.
  ///   - additionalItems: Additional input items to include in the turn.
  ///   - previousResponseID: The prior response ID for conversation
  ///     continuation.
  ///   - requestOptions: Optional request-level response creation settings.
  ///   - plugins: Plugins used to produce typed events.
  /// - Returns: A stream handle containing raw events and typed plugin
  ///   channel(s).
  @available(macOS 15.0, *)
  public func stream<each Plugin: ResponseStreamPlugin>(
    _ userText: String,
    additionalItems: [Item] = [],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    streamOptions: ResponseStreamOptions = .init(),
    plugins: repeat each Plugin
  ) async throws -> ResponseStreamHandle<(repeat PluginChannel<each Plugin>)> {
    let item = Item.inputMessage(
      InputMessage(role: .user, content: [.text(.init(text: userText))])
    )

    return try await stream(
      inputItems: [.item(item)] + additionalItems.map(InputItem.item),
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      streamOptions: streamOptions,
      plugins: repeat each plugins
    )
  }

  /// Starts a streaming turn with typed plugin channel(s) using prebuilt input
  /// items.
  ///
  /// Use this overload when you already have structured ``Item`` values.
  @available(macOS 15.0, *)
  public func stream<each Plugin: ResponseStreamPlugin>(
    items: [Item] = [],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    streamOptions: ResponseStreamOptions = .init(),
    plugins: repeat each Plugin
  ) async throws -> ResponseStreamHandle<(repeat PluginChannel<each Plugin>)> {
    try await stream(
      inputItems: items.map(InputItem.item),
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      streamOptions: streamOptions,
      plugins: repeat each plugins
    )
  }

  /// Starts a streaming turn from full typed conversational history.
  @available(macOS 15.0, *)
  public func stream<each Plugin: ResponseStreamPlugin>(
    inputItems: [InputItem],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    streamOptions: ResponseStreamOptions = .init(),
    plugins: repeat each Plugin
  ) async throws -> ResponseStreamHandle<(repeat PluginChannel<each Plugin>)> {
    let (rawStream, rawEmitter) = Self.makeRawStream(policy: streamOptions.rawEvents)
    let (pluginChannels, pluginRuntimes) = Self.makePluginRuntimes(
      plugins: repeat each plugins,
      policy: streamOptions.pluginEvents
    )

    let cancellation = startStreamTask(
      newItems: inputItems,
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      pluginRuntimes: pluginRuntimes,
      rawEmitter: rawEmitter
    )

    return ResponseStreamHandle(
      raw: rawStream,
      pluginEvents: pluginChannels,
      cancellation: cancellation
    )
  }

  /// Starts a raw-only streaming turn from user text.
  ///
  /// This bypasses plugin projection and yields protocol-level events directly.
  @available(macOS 15.0, *)
  public func streamRaw(
    _ userText: String,
    additionalItems: [Item] = [],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    bufferingPolicy: ResponseStreamBufferingPolicy = .unbounded
  ) async throws -> AsyncThrowingStream<StreamingResponse, Error> {
    let item = Item.inputMessage(
      InputMessage(role: .user, content: [.text(.init(text: userText))])
    )
    return try await streamRaw(
      inputItems: [.item(item)] + additionalItems.map(InputItem.item),
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      bufferingPolicy: bufferingPolicy
    )
  }

  /// Starts a raw-only streaming turn from prebuilt input items.
  @available(macOS 15.0, *)
  public func streamRaw(
    items: [Item] = [],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    bufferingPolicy: ResponseStreamBufferingPolicy = .unbounded
  ) async throws -> AsyncThrowingStream<StreamingResponse, Error> {
    try await streamRaw(
      inputItems: items.map(InputItem.item),
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      bufferingPolicy: bufferingPolicy
    )
  }

  /// Starts a raw-only stream from full typed conversational history.
  ///
  /// Use ``streamRawHandle(inputItems:previousResponseID:metadata:requestOptions:bufferingPolicy:)``
  /// when explicit cancellation is required.
  @available(macOS 15.0, *)
  public func streamRaw(
    inputItems: [InputItem],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    bufferingPolicy: ResponseStreamBufferingPolicy = .unbounded
  ) async throws -> AsyncThrowingStream<StreamingResponse, Error> {
    let handle = try await streamRawHandle(
      inputItems: inputItems,
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      bufferingPolicy: bufferingPolicy
    )
    return handle.events
  }

  /// Starts an explicitly cancellable raw-only stream.
  @available(macOS 15.0, *)
  public func streamRawHandle(
    inputItems: [InputItem],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    bufferingPolicy: ResponseStreamBufferingPolicy = .unbounded
  ) async throws -> RawResponseStreamHandle {
    let (rawStream, rawEmitter) = Self.makeRawStream(policy: bufferingPolicy)

    let cancellation = startStreamTask(
      newItems: inputItems,
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      pluginRuntimes: [],
      rawEmitter: rawEmitter
    )
    return RawResponseStreamHandle(events: rawStream, cancellation: cancellation)
  }

  /// Starts an explicitly cancellable raw-only stream from legacy ``Item`` values.
  @available(macOS 15.0, *)
  public func streamRawHandle(
    items: [Item],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init(),
    bufferingPolicy: ResponseStreamBufferingPolicy = .unbounded
  ) async throws -> RawResponseStreamHandle {
    try await streamRawHandle(
      inputItems: items.map(InputItem.item),
      previousResponseID: previousResponseID,
      metadata: metadata,
      requestOptions: requestOptions,
      bufferingPolicy: bufferingPolicy
    )
  }

  private func advance(
    newItems: [InputItem],
    previousResponseID: String? = nil,
    metadata: [String: String]? = nil,
    requestOptions: RequestOptions = .init()
  ) async throws -> String {
    let response = try await client.createResponse(
      input: .items(newItems),
      model: model,
      instructions: requestOptions.instructions ?? instructions,
      maxOutputTokens: requestOptions.maxOutputTokens,
      metadata: metadata,
      previousResponseId: previousResponseID,
      reasoning: requestOptions.reasoning,
      tools: allTools,
      truncation: requestOptions.truncation
    )

    var generatedText = ""
    var toolOutputItems: [Item] = []

    try await withThrowingTaskGroup(of: Item.self) { group in
      for output in response.output {
        switch output {
        case .message(let outputMessage):
          generatedText += outputMessage.content.reduce(into: "") {
            switch $1 {
            case .text(let text):
              $0 += text.text
            case .refusal(let refusal):
              $0 += refusal.refusal
            }
          }

        case .functionToolCall(let toolCall):
          let toolName = toolCall.name
          let toolArguments = toolCall.arguments
          let callID = toolCall.callId
          group.addTask {
            let result = try await self.executeFunctionTool(
              named: toolName,
              arguments: toolArguments
            )
            return .functionCallOutputItemParam(
              .init(callId: callID, output: result)
            )
          }

        case .computerToolCall, .fileSearchToolCall, .webSearchToolCall,
          .functionToolCallOutputResource, .computerToolCallOutputResource,
          .toolSearchCall, .toolSearchOutput, .compactionBody, .imageGenToolCall,
          .codeInterpreterToolCall, .localShellToolCall, .localShellToolCallOutput,
          .functionShellCall, .functionShellCallOutput, .applyPatchToolCall,
          .applyPatchToolCallOutput, .mcpToolCall, .mcpListTools,
          .mcpApprovalRequest, .mcpApprovalResponseResource, .customToolCall,
          .customToolCallOutputResource:
          break
        }
      }

      for try await item in group {
        toolOutputItems.append(item)
      }
    }

    if !toolOutputItems.isEmpty {
      return try await advance(
        newItems: toolOutputItems.map(InputItem.item),
        previousResponseID: response.id,
        metadata: metadata,
        requestOptions: requestOptions
      )
    }

    return generatedText
  }

  @available(macOS 15.0, *)
  private func streamLoop(
    newItems: [InputItem],
    previousResponseID: String?,
    metadata: [String: String]?,
    requestOptions: RequestOptions = .init(),
    pluginRuntimes: [AnyPluginRuntime],
    rawEmitter: StreamEmitter<StreamingResponse>
  ) async throws {
    var pendingItems = newItems
    var currentPreviousResponseID = previousResponseID
    var context = StreamPluginContext(
      executeFunctionTool: { [self] name, arguments, policy in
        try await executeFunctionTool(
          named: name,
          arguments: arguments,
          policyOverride: policy
        )
      }
    )

    while true {
      try Task.checkCancellation()
      let requestTools = await mergedTools(for: pluginRuntimes)
      let stream = try await client.streamCreateResponseHandle(
        input: .items(pendingItems),
        model: model,
        instructions: requestOptions.instructions ?? instructions,
        maxOutputTokens: requestOptions.maxOutputTokens,
        metadata: metadata,
        previousResponseId: currentPreviousResponseID,
        reasoning: requestOptions.reasoning,
        tools: requestTools,
        truncation: requestOptions.truncation
      )

      var completedResponseID: String?
      var terminalEventObserved = false

      try await withTaskCancellationHandler {
        for try await event in stream {
          try rawEmitter.yield(event)

          switch event {
          case .completed(let response):
            completedResponseID = response.id
            terminalEventObserved = true
          case .failed, .incomplete, .error:
            terminalEventObserved = true
          default:
            break
          }

          for runtime in pluginRuntimes {
            try await runtime.consume(event, &context)
          }
        }
      } onCancel: {
        stream.cancel()
      }

      try Task.checkCancellation()
      let followUpItems = context.drainFollowUpItems()
      guard let completedResponseID else {
        if terminalEventObserved {
          break
        }
        throw ResponseSessionError.missingTerminalEvent
      }
      guard !followUpItems.isEmpty else { break }

      pendingItems = followUpItems.map(InputItem.item)
      currentPreviousResponseID = completedResponseID
    }

    for runtime in pluginRuntimes {
      try await runtime.finishPlugin(&context)
    }
  }

  @available(macOS 15.0, *)
  private func startStreamTask(
    newItems: [InputItem],
    previousResponseID: String?,
    metadata: [String: String]?,
    requestOptions: RequestOptions = .init(),
    pluginRuntimes: [AnyPluginRuntime],
    rawEmitter: StreamEmitter<StreamingResponse>
  ) -> StreamTaskCancellation {
    let cancellation = StreamTaskCancellation()
    let task = Task {
      defer { cancellation.taskDidFinish() }
      do {
        try await self.streamLoop(
          newItems: newItems,
          previousResponseID: previousResponseID,
          metadata: metadata,
          requestOptions: requestOptions,
          pluginRuntimes: pluginRuntimes,
          rawEmitter: rawEmitter
        )

        rawEmitter.finish()
        for runtime in pluginRuntimes {
          runtime.finishStream(nil)
        }
      } catch {
        rawEmitter.finish(throwing: error)
        for runtime in pluginRuntimes {
          runtime.finishStream(error)
        }
      }
    }
    cancellation.install(task)
    return cancellation
  }

  @available(macOS 15.0, *)
  private func mergedTools(for pluginRuntimes: [AnyPluginRuntime]) async -> [OpenAICore.Tool] {
    var merged = allTools

    for runtime in pluginRuntimes {
      for pluginTool in await runtime.responseTools() {
        if case .function(let functionTool) = pluginTool {
          merged.removeAll { tool in
            guard case .function(let existingFunctionTool) = tool else { return false }
            return existingFunctionTool.name == functionTool.name
          }
        }
        merged.append(pluginTool)
      }
    }

    return merged
  }

  private func executeFunctionTool(
    named name: String,
    arguments: String,
    policyOverride: ToolErrorPolicy? = nil
  ) async throws -> String {
    guard let tool = functionTools[name] else {
      throw ResponseSessionError.unknownTool(named: name)
    }

    return try await executeToolWithPolicy(
      named: name,
      policy: policyOverride ?? errorPolicy
    ) {
      try await tool.call(arguments: arguments, messaging: toolCallMessaging)
    }
  }

  @available(macOS 15.0, *)
  private static func makeRawStream(
    policy: ResponseStreamBufferingPolicy
  ) -> (AsyncThrowingStream<StreamingResponse, Error>, StreamEmitter<StreamingResponse>) {
    var continuation: AsyncThrowingStream<StreamingResponse, Error>.Continuation?
    let stream = AsyncThrowingStream<StreamingResponse, Error>(
      bufferingPolicy: bufferingPolicy(for: policy)
    ) { createdContinuation in
      continuation = createdContinuation
    }

    guard let continuation else {
      preconditionFailure("raw stream continuation was not initialized")
    }

    let emitter = StreamEmitter(
      continuation: continuation,
      channelName: "raw",
      policy: policy
    )
    return (stream, emitter)
  }

  @available(macOS 15.0, *)
  private static func makePluginRuntime<P: ResponseStreamPlugin>(
    plugin: P,
    type _: P.Type,
    policy: ResponseStreamBufferingPolicy
  ) -> (PluginChannel<P>, AnyPluginRuntime) {
    var continuation: AsyncThrowingStream<P.Event, Error>.Continuation?
    let stream = AsyncThrowingStream<P.Event, Error>(
      bufferingPolicy: bufferingPolicy(for: policy)
    ) { createdContinuation in
      continuation = createdContinuation
    }

    guard let continuation else {
      preconditionFailure("plugin stream continuation was not initialized")
    }

    let channelName = String(reflecting: P.self)
    let emitter = StreamEmitter(
      continuation: continuation,
      channelName: channelName,
      policy: policy
    )
    let channel = PluginChannel<P>(events: stream)
    let runtime = AnyPluginRuntime(
      responseTools: {
        await plugin.responseTools()
      },
      consume: { event, context in
        guard let pluginEvent = try await plugin.consume(event, context: &context) else { return }
        try emitter.yield(pluginEvent)
      },
      finishPlugin: { context in
        guard let pluginEvent = try await plugin.finish(context: &context) else { return }
        try emitter.yield(pluginEvent)
      },
      finishStream: { error in
        emitter.finish(throwing: error)
      }
    )
    return (channel, runtime)
  }

  @available(macOS 15.0, *)
  private static func makePluginRuntimes<each Plugin: ResponseStreamPlugin>(
    plugins: repeat each Plugin,
    policy: ResponseStreamBufferingPolicy
  ) -> ((repeat PluginChannel<each Plugin>), [AnyPluginRuntime]) {
    var runtimes: [AnyPluginRuntime] = []

    func makeChannel<P: ResponseStreamPlugin>(_ plugin: P) -> PluginChannel<P> {
      let (channel, runtime) = Self.makePluginRuntime(
        plugin: plugin,
        type: P.self,
        policy: policy
      )
      runtimes.append(runtime)
      return channel
    }

    let channels = (repeat makeChannel(each plugins))
    return (channels, runtimes)
  }

  @available(macOS 15.0, *)
  private static func bufferingPolicy<Element>(
    for policy: ResponseStreamBufferingPolicy
  ) -> AsyncThrowingStream<Element, Error>.Continuation.BufferingPolicy {
    switch policy {
    case .unbounded, .disabled:
      return .unbounded
    case .bounded(let capacity):
      precondition(capacity > 0, "Bounded stream capacity must be greater than zero")
      return .bufferingOldest(capacity)
    }
  }
}

@available(macOS 15.0, *)
private struct AnyPluginRuntime: Sendable {
  let responseTools: @Sendable () async -> [OpenAICore.Tool]
  let consume:
    @Sendable (
      _ event: StreamingResponse,
      _ context: inout StreamPluginContext
    ) async throws -> Void
  let finishPlugin: @Sendable (_ context: inout StreamPluginContext) async throws -> Void
  let finishStream: @Sendable (_ error: Error?) -> Void
}
