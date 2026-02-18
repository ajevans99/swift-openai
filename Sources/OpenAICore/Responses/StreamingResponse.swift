import OpenAPIRuntime

public enum StreamingResponse: Sendable {
  public enum OutputItem: Sendable {
    case added(item: OpenAICore.OutputItem, outputIndex: Int)
    case done(item: OpenAICore.OutputItem, outputIndex: Int)

    public var value: String {
      switch self {
      case .added: "added"
      case .done: "done"
      }
    }

    public init?(openAPI: Components.Schemas.ResponseOutputItemAddedEvent) {
      guard let item = OpenAICore.OutputItem(openAPI.item) else { return nil }
      self = .added(item: item, outputIndex: openAPI.outputIndex)
    }

    public init?(openAPI: Components.Schemas.ResponseOutputItemDoneEvent) {
      guard let item = OpenAICore.OutputItem(openAPI.item) else { return nil }
      self = .done(item: item, outputIndex: openAPI.outputIndex)
    }
  }

  public enum OutputText: Sendable {
    public enum Annotation: Sendable {
      case added(
        annotation: OpenAPIObjectContainer,
        annotationIndex: Int,
        contentIndex: Int,
        itemId: String,
        outputIndex: Int
      )

      public var value: String { "added" }

      public init(openAPI: Components.Schemas.ResponseOutputTextAnnotationAddedEvent) {
        self = .added(
          annotation: openAPI.annotation,
          annotationIndex: openAPI.annotationIndex,
          contentIndex: openAPI.contentIndex,
          itemId: openAPI.itemId,
          outputIndex: openAPI.outputIndex
        )
      }
    }

    case delta(delta: String, contentIndex: Int, itemId: String, outputIndex: Int)
    case annotation(Annotation)
    case done(text: String, contentIndex: Int, itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .delta: "delta"
      case .annotation(let annotation): "annotation.\(annotation.value)"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseTextDeltaEvent) {
      self = .delta(
        delta: openAPI.delta,
        contentIndex: openAPI.contentIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }

    public init(openAPI: Components.Schemas.ResponseOutputTextAnnotationAddedEvent) {
      self = .annotation(Annotation(openAPI: openAPI))
    }

    public init(openAPI: Components.Schemas.ResponseTextDoneEvent) {
      self = .done(
        text: openAPI.text,
        contentIndex: openAPI.contentIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }
  }

  case created(Response)
  case inProgress(Response)
  case completed(Response)
  case failed(Response)
  case incomplete(Response)
  case outputItem(OutputItem)
  case outputText(OutputText)
  case error(message: String, code: String?, param: String?)

  public var value: String {
    switch self {
    case .created: "response.created"
    case .inProgress: "response.in_progress"
    case .completed: "response.completed"
    case .failed: "response.failed"
    case .incomplete: "response.incomplete"
    case .outputItem(let item): "response.output_item.\(item.value)"
    case .outputText(let text): "response.output_text.\(text.value)"
    case .error: "error"
    }
  }

  public init?(openAPI: Components.Schemas.ResponseStreamEvent) {
    if let event = openAPI.value13 {
      self = .created(Response(openAPI: event.response))
    } else if let event = openAPI.value20 {
      self = .inProgress(Response(openAPI: event.response))
    } else if let event = openAPI.value10 {
      self = .completed(Response(openAPI: event.response))
    } else if let event = openAPI.value21 {
      self = .failed(Response(openAPI: event.response))
    } else if let event = openAPI.value22 {
      self = .incomplete(Response(openAPI: event.response))
    } else if let event = openAPI.value23 {
      guard let item = OutputItem(openAPI: event) else { return nil }
      self = .outputItem(item)
    } else if let event = openAPI.value24 {
      guard let item = OutputItem(openAPI: event) else { return nil }
      self = .outputItem(item)
    } else if let event = openAPI.value33 {
      self = .outputText(OutputText(openAPI: event))
    } else if let event = openAPI.value34 {
      self = .outputText(OutputText(openAPI: event))
    } else if let event = openAPI.value50 {
      self = .outputText(OutputText(openAPI: event))
    } else if let event = openAPI.value14 {
      self = .error(message: event.message, code: nil, param: nil)
    } else {
      return nil
    }
  }
}
