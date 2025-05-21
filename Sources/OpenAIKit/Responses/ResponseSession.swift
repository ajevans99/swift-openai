import Foundation
import OpenAICore

public actor ResponseSession {
  public typealias Message = Item

  public enum StreamEvent: Sendable {
    case output(String, isFinal: Bool)
    case toolCalled(name: String, arguments: String)
  }

  private let client: OpenAI
  private let model: Model
  private let errorPolicy: ToolErrorPolicy
  private var history: any HistoryBuffer

  private var tools: [String: any Tool] = [:]

  public init(
    client: OpenAI, model: Model, history: HistoryBuffer = RolllingHistoryBuffer(capacity: 100),
    errorPolicy: ToolErrorPolicy = .failFast
  ) {
    self.client = client
    self.model = model
    self.history = history
    self.errorPolicy = errorPolicy
  }

  public func register(tool: any Tool) {
    tools[tool.name] = tool
  }

  @discardableResult
  public func send(_ userText: String) async throws -> String {
    history.appendUser(userText)

    return try await advance()
  }

  @available(macOS 15.0, *)
  public func stream(_ userText: String) async throws -> AsyncThrowingStream<StreamEvent, Error> {
    history.appendUser(userText)
    client.logger.debug("Starting stream for user text: \(userText)")

    return AsyncThrowingStream { continuation in
      Task {
        do {
          try await streamAdvance(continuation: continuation)
        } catch {
          client.logger.error("Stream failed with error: \(error)")
          continuation.finish(throwing: error)
        }
      }
    }
  }

  private func advance(previousResponseID: String? = nil) async throws -> String {
    let response = try await client.createResponse(
      input: .items(history.entries.map { .item($0) }),
      model: model,
      previousResponseId: previousResponseID,
      tools: Array(tools.values).map { $0.toTool() }
    )

    var generatedText = ""
    var newItems: [Item] = []

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
          client.logger.debug("Tool call: \(toolCall.name)")
          guard let tool = tools[toolCall.name] else {
            client.logger.error("Unknown tool")
            throw ResponseSessionError.unknownTool(named: toolCall.name)
          }
          group.addTask { [logger = client.logger] in
            let result = try await tool.call(arguments: toolCall.arguments)
            logger.debug("Tool call result: \(result)")
            return .functionCallOutputItemParam(
              .init(callId: toolCall.callId, output: result)
            )
          }
        case .computerToolCall, .fileSearchToolCall, .reasoning, .webSearchToolCall:
          break
        }
      }

      for try await item in group { newItems.append(item) }
    }

    // If we had tool calls, append their outputs to history,
    // then recurse until the assistant produces a plain reply.
    if !newItems.isEmpty {
      history.appendResponse(responseID: response.id, items: newItems)
      return try await advance(previousResponseID: response.id)
    }

    return generatedText
  }

  @available(macOS 15.0, *)
  private func streamAdvance(
    continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation,
    previousResponseID: String? = nil
  ) async throws {
    client.logger.debug(
      "Starting streamAdvance with previousResponseID: \(previousResponseID ?? "none")")

    let stream = try await client.streamCreateResponse(
      input: .items(history.entries.map { .item($0) }),
      model: model,
      previousResponseId: previousResponseID,
      tools: Array(tools.values).map { $0.toTool() }
    )
    var newItems: [Item] = []
    var responseID: String?

    for try await event in stream {
      switch event {
      case .outputText(let text):
        switch text {
        case .delta(let delta, _, _, _):
          client.logger.debug("Received text delta: \(delta)")
          continuation.yield(.output(delta, isFinal: false))
        case .done(let text, _, _, _):
          client.logger.debug("Received complete text: \(text)")
          continuation.yield(.output(text, isFinal: true))
        case .annotation:
          client.logger.debug("Received annotation")
          break
        }

      case .outputItem(let item):
        switch item {
        case .done(let outputItem, _):
          if case .functionToolCall(let toolCall) = outputItem {
            client.logger.debug("Received complete function tool call for: \(toolCall.name)")
            continuation.yield(.toolCalled(name: toolCall.name, arguments: toolCall.arguments))

            guard let tool = tools[toolCall.name] else {
              throw ResponseSessionError.unknownTool(named: toolCall.name)
            }

            do {
              client.logger.debug("Executing tool call for: \(toolCall.name)")
              let result = try await tool.call(arguments: toolCall.arguments)
              client.logger.debug("Tool call result: \(result)")
              newItems.append(
                .functionCallOutputItemParam(
                  .init(callId: toolCall.callId, output: result)
                ))
            } catch {
              throw error
            }
          }
        default:
          break
        }

      case .completed(let response):
        client.logger.debug("Stream completed with response ID: \(response.id)")
        responseID = response.id
        break

      case .error(let message, let code, let param):
        client.logger.error(
          "Stream error: \(message) (code: \(code ?? "unknown"), param: \(param ?? "none"))")
        throw ResponseSessionError.unknownTool(named: message)

      default:
        client.logger.debug("Received event: \(event.value)")
        continue
      }
    }

    // Handle recursion if we have tool call results
    if !newItems.isEmpty, let responseID {
      client.logger.debug("Appending \(newItems.count) new items to history")
      history.appendResponse(responseID: responseID, items: newItems)
      // Recursively stream the next response with tool call results
      try await streamAdvance(continuation: continuation, previousResponseID: responseID)
    } else {
      continuation.finish()
    }
  }
}
