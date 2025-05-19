import OpenAICore

public actor ResponseSession {
  public typealias Message = Item

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
          guard let tool = tools[toolCall.name] else {
            throw ResponseSessionError.unknownTool(named: toolCall.name)
          }
          group.addTask {
            let result = try await tool.call(arguments: toolCall.arguments)
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
}
