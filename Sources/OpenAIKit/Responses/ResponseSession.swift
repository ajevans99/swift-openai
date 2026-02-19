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
/// ## Bounded buffering
///
/// Streaming channels use a bounded `bufferingNewest` strategy. If consumers
/// are slower than producers, older buffered events are dropped. Per-channel
/// drop counts are exposed through ``PluginChannel/droppedCount()``.
public actor ResponseSession {
  public typealias Message = Item

  private static let streamBufferLimit = 256

  private let client: OpenAI
  private let model: Model
  private let errorPolicy: ToolErrorPolicy

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
  ///   - errorPolicy: Behavior to apply when function tools fail.
  public init(
    client: OpenAI,
    model: Model,
    errorPolicy: ToolErrorPolicy = .failFast
  ) {
    self.client = client
    self.model = model
    self.errorPolicy = errorPolicy
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
  /// - Returns: Final concatenated assistant text for the turn.
  @discardableResult
  public func send(
    _ userText: String,
    additionalItems: [Item] = [],
    previousResponseID: String? = nil
  ) async throws -> String {
    let item = Item.inputMessage(
      InputMessage(role: .user, content: [.text(.init(text: userText))])
    )

    return try await advance(
      newItems: [item] + additionalItems,
      previousResponseID: previousResponseID
    )
  }

  /// Starts a streaming turn with typed plugin channel(s).
  ///
  /// - Parameters:
  ///   - userText: User message content.
  ///   - additionalItems: Additional input items to include in the turn.
  ///   - previousResponseID: The prior response ID for conversation
  ///     continuation.
  ///   - plugins: Plugins used to produce typed events.
  /// - Returns: A stream handle containing raw events and typed plugin
  ///   channel(s).
  @available(macOS 15.0, *)
  public func stream<each Plugin: ResponseStreamPlugin>(
    _ userText: String,
    additionalItems: [Item] = [],
    previousResponseID: String? = nil,
    plugins: repeat each Plugin
  ) async throws -> ResponseStreamHandle<(repeat PluginChannel<each Plugin>)> {
    let item = Item.inputMessage(
      InputMessage(role: .user, content: [.text(.init(text: userText))])
    )

    return try await stream(
      items: [item] + additionalItems,
      previousResponseID: previousResponseID,
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
    plugins: repeat each Plugin
  ) async throws -> ResponseStreamHandle<(repeat PluginChannel<each Plugin>)> {
    let (rawStream, rawEmitter) = Self.makeRawStream(bufferLimit: Self.streamBufferLimit)
    let (pluginChannels, pluginRuntimes) = Self.makePluginRuntimes(
      plugins: repeat each plugins,
      bufferLimit: Self.streamBufferLimit
    )

    startStreamTask(
      newItems: items,
      previousResponseID: previousResponseID,
      pluginRuntimes: pluginRuntimes,
      rawEmitter: rawEmitter
    )

    return ResponseStreamHandle(raw: rawStream, pluginEvents: pluginChannels)
  }

  /// Starts a raw-only streaming turn from user text.
  ///
  /// This bypasses plugin projection and yields protocol-level events directly.
  @available(macOS 15.0, *)
  public func streamRaw(
    _ userText: String,
    additionalItems: [Item] = [],
    previousResponseID: String? = nil
  ) async throws -> AsyncThrowingStream<StreamingResponse, Error> {
    let item = Item.inputMessage(
      InputMessage(role: .user, content: [.text(.init(text: userText))])
    )
    return try await streamRaw(
      items: [item] + additionalItems,
      previousResponseID: previousResponseID
    )
  }

  /// Starts a raw-only streaming turn from prebuilt input items.
  @available(macOS 15.0, *)
  public func streamRaw(
    items: [Item] = [],
    previousResponseID: String? = nil
  ) async throws -> AsyncThrowingStream<StreamingResponse, Error> {
    let (rawStream, rawEmitter) = Self.makeRawStream(bufferLimit: Self.streamBufferLimit)

    startStreamTask(
      newItems: items,
      previousResponseID: previousResponseID,
      pluginRuntimes: [],
      rawEmitter: rawEmitter
    )
    return rawStream
  }

  private func advance(newItems: [Item], previousResponseID: String? = nil) async throws -> String {
    let response = try await client.createResponse(
      input: .items(newItems.map { .item($0) }),
      model: model,
      previousResponseId: previousResponseID,
      tools: allTools
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
          guard let tool = functionTools[toolCall.name] else {
            throw ResponseSessionError.unknownTool(named: toolCall.name)
          }
          group.addTask {
            let result = try await tool.call(arguments: toolCall.arguments)
            return .functionCallOutputItemParam(
              .init(callId: toolCall.callId, output: result)
            )
          }

        case .computerToolCall, .fileSearchToolCall, .reasoning, .webSearchToolCall,
          .compactionBody, .imageGenToolCall, .codeInterpreterToolCall, .localShellToolCall,
          .functionShellCall, .functionShellCallOutput, .applyPatchToolCall,
          .applyPatchToolCallOutput, .mcpToolCall, .mcpListTools, .mcpApprovalRequest,
          .customToolCall:
          break
        }
      }

      for try await item in group {
        toolOutputItems.append(item)
      }
    }

    if !toolOutputItems.isEmpty {
      return try await advance(newItems: toolOutputItems, previousResponseID: response.id)
    }

    return generatedText
  }

  @available(macOS 15.0, *)
  private func streamLoop(
    newItems: [Item],
    previousResponseID: String?,
    pluginRuntimes: [AnyPluginRuntime],
    rawEmitter: StreamEmitter<StreamingResponse>
  ) async throws {
    var pendingItems = newItems
    var currentPreviousResponseID = previousResponseID
    var context = StreamPluginContext(
      executeFunctionTool: { [self] name, arguments in
        try await executeFunctionTool(named: name, arguments: arguments)
      }
    )

    while true {
      let stream = try await client.streamCreateResponse(
        input: .items(pendingItems.map { .item($0) }),
        model: model,
        previousResponseId: currentPreviousResponseID,
        tools: allTools
      )

      var latestResponseID = currentPreviousResponseID

      for try await event in stream {
        rawEmitter.yield(event)

        switch event {
        case .created(let response):
          latestResponseID = response.id
        case .inProgress(let response):
          latestResponseID = response.id
        case .completed(let response):
          latestResponseID = response.id
        default:
          break
        }

        for runtime in pluginRuntimes {
          try await runtime.consume(event, &context)
        }
      }

      let followUpItems = context.drainFollowUpItems()
      guard !followUpItems.isEmpty else { break }

      guard let latestResponseID else {
        throw ResponseSessionError.missingResponseIDForContinuation
      }

      pendingItems = followUpItems
      currentPreviousResponseID = latestResponseID
    }

    for runtime in pluginRuntimes {
      try await runtime.finishPlugin(&context)
    }
  }

  @available(macOS 15.0, *)
  private func startStreamTask(
    newItems: [Item],
    previousResponseID: String?,
    pluginRuntimes: [AnyPluginRuntime],
    rawEmitter: StreamEmitter<StreamingResponse>
  ) {
    Task {
      do {
        try await self.streamLoop(
          newItems: newItems,
          previousResponseID: previousResponseID,
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
  }

  private func executeFunctionTool(named name: String, arguments: String) async throws -> String {
    guard let tool = functionTools[name] else {
      throw ResponseSessionError.unknownTool(named: name)
    }

    let maxAttempts: Int
    switch errorPolicy {
    case .retry(let count):
      maxAttempts = max(1, count + 1)
    default:
      maxAttempts = 1
    }

    var attempt = 0
    var lastError: Error?
    while attempt < maxAttempts {
      do {
        return try await tool.call(arguments: arguments)
      } catch {
        lastError = error
        attempt += 1
      }
    }

    guard let lastError else {
      throw ResponseSessionError.toolExecutionFailed(name: name)
    }

    switch errorPolicy {
    case .failFast, .retry:
      throw lastError
    case .returnAsMessage:
      return "Tool '\(name)' failed: \(String(describing: lastError))"
    case .askAssistantToClarify(let systemMessage):
      return systemMessage(lastError)
    }
  }

  @available(macOS 15.0, *)
  private static func makeRawStream(
    bufferLimit: Int
  ) -> (AsyncThrowingStream<StreamingResponse, Error>, StreamEmitter<StreamingResponse>) {
    var continuation: AsyncThrowingStream<StreamingResponse, Error>.Continuation?
    let stream = AsyncThrowingStream<StreamingResponse, Error>(
      bufferingPolicy: .bufferingNewest(bufferLimit)
    ) { createdContinuation in
      continuation = createdContinuation
    }

    guard let continuation else {
      preconditionFailure("raw stream continuation was not initialized")
    }

    let emitter = StreamEmitter(continuation: continuation)
    return (stream, emitter)
  }

  @available(macOS 15.0, *)
  private static func makePluginRuntime<P: ResponseStreamPlugin>(
    plugin: P,
    type _: P.Type,
    bufferLimit: Int
  ) -> (PluginChannel<P>, AnyPluginRuntime) {
    var continuation: AsyncThrowingStream<P.Event, Error>.Continuation?
    let stream = AsyncThrowingStream<P.Event, Error>(
      bufferingPolicy: .bufferingNewest(bufferLimit)
    ) { createdContinuation in
      continuation = createdContinuation
    }

    guard let continuation else {
      preconditionFailure("plugin stream continuation was not initialized")
    }

    let emitter = StreamEmitter(continuation: continuation)
    let channel = PluginChannel<P>(
      events: stream,
      droppedCountProvider: { emitter.droppedCount() }
    )
    let runtime = AnyPluginRuntime(
      consume: { event, context in
        guard let pluginEvent = try await plugin.consume(event, context: &context) else { return }
        emitter.yield(pluginEvent)
      },
      finishPlugin: { context in
        guard let pluginEvent = try await plugin.finish(context: &context) else { return }
        emitter.yield(pluginEvent)
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
    bufferLimit: Int
  ) -> ((repeat PluginChannel<each Plugin>), [AnyPluginRuntime]) {
    var runtimes: [AnyPluginRuntime] = []

    func makeChannel<P: ResponseStreamPlugin>(_ plugin: P) -> PluginChannel<P> {
      let (channel, runtime) = Self.makePluginRuntime(
        plugin: plugin,
        type: P.self,
        bufferLimit: bufferLimit
      )
      runtimes.append(runtime)
      return channel
    }

    let channels = (repeat makeChannel(each plugins))
    return (channels, runtimes)
  }
}

@available(macOS 15.0, *)
private struct AnyPluginRuntime: Sendable {
  let consume: @Sendable (
    _ event: StreamingResponse,
    _ context: inout StreamPluginContext
  ) async throws -> Void
  let finishPlugin: @Sendable (_ context: inout StreamPluginContext) async throws -> Void
  let finishStream: @Sendable (_ error: Error?) -> Void
}
