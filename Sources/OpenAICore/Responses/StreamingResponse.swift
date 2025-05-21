public enum StreamingResponse {
  public enum OutputItem {
    case added(item: OpenAICore.OutputItem, outputIndex: Int)
    case done(item: OpenAICore.OutputItem, outputIndex: Int)

    public var value: String {
      switch self {
      case .added: "added"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseOutputItemAddedEvent) {
      self = .added(item: OpenAICore.OutputItem(openAPI.item)!, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseOutputItemDoneEvent) {
      self = .done(item: OpenAICore.OutputItem(openAPI.item)!, outputIndex: openAPI.outputIndex)
    }
  }

  public enum ContentPart {
    case added(part: OutputContent, contentIndex: Int, itemId: String, outputIndex: Int)
    case done(part: OutputContent, contentIndex: Int, itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .added: "added"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseContentPartAddedEvent) {
      self = .added(
        part: OutputContent(openAPI.part),
        contentIndex: openAPI.contentIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }

    public init(openAPI: Components.Schemas.ResponseContentPartDoneEvent) {
      self = .done(
        part: OutputContent(openAPI.part),
        contentIndex: openAPI.contentIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }
  }

  public enum OutputText {
    public enum Annotation {
      case added(
        annotation: Components.Schemas.Annotation,
        annotationIndex: Int,
        contentIndex: Int,
        itemId: String,
        outputIndex: Int
      )

      public var value: String {
        switch self {
        case .added: "added"
        }
      }

      public init(openAPI: Components.Schemas.ResponseTextAnnotationDeltaEvent) {
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

    public init(openAPI: Components.Schemas.ResponseTextAnnotationDeltaEvent) {
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

  public enum Refusal {
    case delta(delta: String, contentIndex: Int, itemId: String, outputIndex: Int)
    case done(refusal: String, contentIndex: Int, itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseRefusalDeltaEvent) {
      self = .delta(
        delta: openAPI.delta,
        contentIndex: openAPI.contentIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }

    public init(openAPI: Components.Schemas.ResponseRefusalDoneEvent) {
      self = .done(
        refusal: openAPI.refusal,
        contentIndex: openAPI.contentIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }
  }

  public enum FunctionCallArguments {
    case delta(delta: String, itemId: String, outputIndex: Int)
    case done(arguments: String, itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseFunctionCallArgumentsDeltaEvent) {
      self = .delta(delta: openAPI.delta, itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseFunctionCallArgumentsDoneEvent) {
      self = .done(
        arguments: openAPI.arguments,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }
  }

  public enum FileSearchCall {
    case inProgress(itemId: String, outputIndex: Int)
    case searching(itemId: String, outputIndex: Int)
    case completed(itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .inProgress: "in_progress"
      case .searching: "searching"
      case .completed: "completed"
      }
    }

    public init(openAPI: Components.Schemas.ResponseFileSearchCallInProgressEvent) {
      self = .inProgress(itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseFileSearchCallSearchingEvent) {
      self = .searching(itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseFileSearchCallCompletedEvent) {
      self = .completed(itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }
  }

  public enum WebSearchCall {
    case inProgress(itemId: String, outputIndex: Int)
    case searching(itemId: String, outputIndex: Int)
    case completed(itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .inProgress: "in_progress"
      case .searching: "searching"
      case .completed: "completed"
      }
    }

    public init(openAPI: Components.Schemas.ResponseWebSearchCallInProgressEvent) {
      self = .inProgress(itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseWebSearchCallSearchingEvent) {
      self = .searching(itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseWebSearchCallCompletedEvent) {
      self = .completed(itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }
  }

  public enum ReasoningSummaryPart {
    case delta(part: String, summaryIndex: Int, itemId: String, outputIndex: Int)
    case done(part: String, summaryIndex: Int, itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseReasoningSummaryPartAddedEvent) {
      self = .delta(
        part: openAPI.part.text,
        summaryIndex: openAPI.summaryIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }

    public init(openAPI: Components.Schemas.ResponseReasoningSummaryPartDoneEvent) {
      self = .done(
        part: openAPI.part.text,
        summaryIndex: openAPI.summaryIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }
  }

  public enum ReasoningSummaryText {
    case delta(delta: String, summaryIndex: Int, itemId: String, outputIndex: Int)
    case done(text: String, summaryIndex: Int, itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseReasoningSummaryTextDeltaEvent) {
      self = .delta(
        delta: openAPI.delta,
        summaryIndex: openAPI.summaryIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }

    public init(openAPI: Components.Schemas.ResponseReasoningSummaryTextDoneEvent) {
      self = .done(
        text: openAPI.text,
        summaryIndex: openAPI.summaryIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }
  }

  public enum Audio {
    case delta(delta: String)
    case done

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseAudioDeltaEvent) {
      self = .delta(delta: openAPI.delta)
    }

    public init(openAPI: Components.Schemas.ResponseAudioDoneEvent) {
      self = .done
    }
  }

  public enum AudioTranscript {
    case delta(delta: String)
    case done

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseAudioTranscriptDeltaEvent) {
      self = .delta(delta: openAPI.delta)
    }

    public init(openAPI: Components.Schemas.ResponseAudioTranscriptDoneEvent) {
      self = .done
    }
  }

  public enum CodeInterpreterCall {
    case codeDelta(delta: String, outputIndex: Int)
    case codeDone(code: String, outputIndex: Int)
    case completed(
      outputIndex: Int,
      codeInterpreterCall: Components.Schemas.CodeInterpreterToolCall
    )
    case inProgress(
      outputIndex: Int,
      codeInterpreterCall: Components.Schemas.CodeInterpreterToolCall
    )
    case interpreting(
      outputIndex: Int,
      codeInterpreterCall: Components.Schemas.CodeInterpreterToolCall
    )

    public var value: String {
      switch self {
      case .codeDelta: "code_delta"
      case .codeDone: "code_done"
      case .completed: "completed"
      case .inProgress: "in_progress"
      case .interpreting: "interpreting"
      }
    }

    public init(openAPI: Components.Schemas.ResponseCodeInterpreterCallCodeDeltaEvent) {
      self = .codeDelta(delta: openAPI.delta, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseCodeInterpreterCallCodeDoneEvent) {
      self = .codeDone(code: openAPI.code, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseCodeInterpreterCallCompletedEvent) {
      self = .completed(
        outputIndex: openAPI.outputIndex,
        codeInterpreterCall: openAPI.codeInterpreterCall
      )
    }

    public init(openAPI: Components.Schemas.ResponseCodeInterpreterCallInProgressEvent) {
      self = .inProgress(
        outputIndex: openAPI.outputIndex,
        codeInterpreterCall: openAPI.codeInterpreterCall
      )
    }

    public init(openAPI: Components.Schemas.ResponseCodeInterpreterCallInterpretingEvent) {
      self = .interpreting(
        outputIndex: openAPI.outputIndex,
        codeInterpreterCall: openAPI.codeInterpreterCall
      )
    }
  }

  case created(Response)
  case inProgress(Response)
  case completed(Response)
  case failed(Response)
  case incomplete(Response)
  case outputItem(OutputItem)
  case contentPart(ContentPart)
  case outputText(OutputText)
  case refusal(Refusal)
  case functionCallArgument(FunctionCallArguments)
  case fileSearchCall(FileSearchCall)
  case webSearchCall(WebSearchCall)
  case reasoningSummaryPart(ReasoningSummaryPart)
  case reasoningSummaryText(ReasoningSummaryText)
  case error(message: String, code: String?, param: String?)
  case audio(Audio)
  case audioTranscript(AudioTranscript)
  case codeInterpreterCall(CodeInterpreterCall)

  public var value: String {
    switch self {
    case .created: "response.created"
    case .inProgress: "response.in_progress"
    case .completed: "response.completed"
    case .failed: "response.failed"
    case .incomplete: "response.incomplete"
    case .outputItem(let item): "response.output_item.\(item.value)"
    case .contentPart(let part): "response.content_part.\(part.value)"
    case .outputText(let text): "response.output_text.\(text.value)"
    case .refusal(let refusal): "response.refusal.\(refusal.value)"
    case .functionCallArgument(let argument): "response.function_call_argument.\(argument.value)"
    case .fileSearchCall(let call): "response.file_search_call.\(call.value)"
    case .webSearchCall(let call): "response.web_search_call.\(call.value)"
    case .reasoningSummaryPart(let summary): "response.reasoning_summary_part.\(summary.value)"
    case .reasoningSummaryText(let text): "response.reasoning_summary_text.\(text.value)"
    case .error: "error"
    case .audio(let audio): "response.audio.\(audio.value)"
    case .audioTranscript(let transcript): "response.audio_transcript.\(transcript.value)"
    case .codeInterpreterCall(let call): "response.code_interpreter_call.\(call.value)"
    }
  }

  public init?(openAPI: Components.Schemas.ResponseStreamEvent) {
    if let event = openAPI.value1 {
      self = .audio(Audio(openAPI: event))
    } else if let event = openAPI.value2 {
      self = .audio(Audio(openAPI: event))
    } else if let event = openAPI.value3 {
      self = .audioTranscript(AudioTranscript(openAPI: event))
    } else if let event = openAPI.value4 {
      self = .audioTranscript(AudioTranscript(openAPI: event))
    } else if let event = openAPI.value5 {
      self = .codeInterpreterCall(CodeInterpreterCall(openAPI: event))
    } else if let event = openAPI.value6 {
      self = .codeInterpreterCall(CodeInterpreterCall(openAPI: event))
    } else if let event = openAPI.value7 {
      self = .codeInterpreterCall(CodeInterpreterCall(openAPI: event))
    } else if let event = openAPI.value8 {
      self = .codeInterpreterCall(CodeInterpreterCall(openAPI: event))
    } else if let event = openAPI.value9 {
      self = .codeInterpreterCall(CodeInterpreterCall(openAPI: event))
    } else if let event = openAPI.value13 {
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
      self = .outputItem(OutputItem(openAPI: event))
    } else if let event = openAPI.value24 {
      self = .outputItem(OutputItem(openAPI: event))
    } else if let event = openAPI.value11 {
      self = .contentPart(ContentPart(openAPI: event))
    } else if let event = openAPI.value12 {
      self = .contentPart(ContentPart(openAPI: event))
    } else if let event = openAPI.value32 {
      self = .outputText(OutputText(openAPI: event))
    } else if let event = openAPI.value31 {
      self = .outputText(OutputText(openAPI: event))
    } else if let event = openAPI.value33 {
      self = .outputText(OutputText(openAPI: event))
    } else if let event = openAPI.value29 {
      self = .refusal(Refusal(openAPI: event))
    } else if let event = openAPI.value30 {
      self = .refusal(Refusal(openAPI: event))
    } else if let event = openAPI.value18 {
      self = .functionCallArgument(FunctionCallArguments(openAPI: event))
    } else if let event = openAPI.value19 {
      self = .functionCallArgument(FunctionCallArguments(openAPI: event))
    } else if let event = openAPI.value16 {
      self = .fileSearchCall(FileSearchCall(openAPI: event))
    } else if let event = openAPI.value17 {
      self = .fileSearchCall(FileSearchCall(openAPI: event))
    } else if let event = openAPI.value15 {
      self = .fileSearchCall(FileSearchCall(openAPI: event))
    } else if let event = openAPI.value35 {
      self = .webSearchCall(WebSearchCall(openAPI: event))
    } else if let event = openAPI.value36 {
      self = .webSearchCall(WebSearchCall(openAPI: event))
    } else if let event = openAPI.value34 {
      self = .webSearchCall(WebSearchCall(openAPI: event))
    } else if let event = openAPI.value25 {
      self = .reasoningSummaryPart(ReasoningSummaryPart(openAPI: event))
    } else if let event = openAPI.value26 {
      self = .reasoningSummaryPart(ReasoningSummaryPart(openAPI: event))
    } else if let event = openAPI.value27 {
      self = .reasoningSummaryText(ReasoningSummaryText(openAPI: event))
    } else if let event = openAPI.value28 {
      self = .reasoningSummaryText(ReasoningSummaryText(openAPI: event))
    } else if let event = openAPI.value14 {
      self = .error(message: event.message, code: event.code, param: event.param)
    } else {
      return nil
    }
  }
}
