import Foundation
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

  public enum ContentPart: Sendable {
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

  public enum OutputText: Sendable {
    public enum Annotation: Sendable {
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

  public enum Refusal: Sendable {
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

  public enum FunctionCallArguments: Sendable {
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

  public enum FileSearchCall: Sendable {
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

  public enum WebSearchCall: Sendable {
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

  public enum ReasoningSummaryPart: Sendable {
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

  public enum ReasoningSummaryText: Sendable {
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

  public enum ReasoningSummary: Sendable {
    case delta(
      delta: OpenAPIRuntime.OpenAPIObjectContainer,
      summaryIndex: Int,
      itemId: String,
      outputIndex: Int,
      sequenceNumber: Int
    )
    case done(
      text: String,
      summaryIndex: Int,
      itemId: String,
      outputIndex: Int,
      sequenceNumber: Int
    )

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseReasoningSummaryDeltaEvent) {
      self = .delta(
        delta: openAPI.delta,
        summaryIndex: openAPI.summaryIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        sequenceNumber: openAPI.sequenceNumber
      )
    }

    public init(openAPI: Components.Schemas.ResponseReasoningSummaryDoneEvent) {
      self = .done(
        text: openAPI.text,
        summaryIndex: openAPI.summaryIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        sequenceNumber: openAPI.sequenceNumber
      )
    }
  }

  public enum Audio: Sendable {
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

  public enum AudioTranscript: Sendable {
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

  public enum CodeInterpreterCall: Sendable {
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

  public enum ImageGenCall: Sendable {
    case completed(itemId: String, outputIndex: Int)
    case generating(itemId: String, outputIndex: Int, sequenceNumber: Int)
    case inProgress(itemId: String, outputIndex: Int, sequenceNumber: Int)
    case partialImage(
      itemId: String, outputIndex: Int, partialImageBase64: String, partialImageIndex: Int,
      sequenceNumber: Int
    )

    public var value: String {
      switch self {
      case .completed: "completed"
      case .generating: "generating"
      case .inProgress: "in_progress"
      case .partialImage: "partial_image"
      }
    }

    public init(openAPI: Components.Schemas.ResponseImageGenCallCompletedEvent) {
      self = .completed(itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }

    public init(openAPI: Components.Schemas.ResponseImageGenCallGeneratingEvent) {
      self = .generating(
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        sequenceNumber: openAPI.sequenceNumber
      )
    }

    public init(openAPI: Components.Schemas.ResponseImageGenCallInProgressEvent) {
      self = .inProgress(
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        sequenceNumber: openAPI.sequenceNumber
      )
    }

    public init(openAPI: Components.Schemas.ResponseImageGenCallPartialImageEvent) {
      self = .partialImage(
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        partialImageBase64: openAPI.partialImageB64,
        partialImageIndex: openAPI.partialImageIndex,
        sequenceNumber: openAPI.sequenceNumber
      )
    }
  }

  public enum MCPCall: Sendable {
    case argumentsDelta(
      delta: OpenAPIRuntime.OpenAPIObjectContainer, itemId: String, outputIndex: Int)
    case argumentsDone(
      arguments: OpenAPIRuntime.OpenAPIObjectContainer, itemId: String, outputIndex: Int)
    case completed(sequenceNumber: Int)
    case failed(sequenceNumber: Int)
    case inProgress(itemId: String, outputIndex: Int, sequenceNumber: Int)

    public var value: String {
      switch self {
      case .argumentsDelta: "arguments_delta"
      case .argumentsDone: "arguments_done"
      case .completed: "completed"
      case .failed: "failed"
      case .inProgress: "in_progress"
      }
    }

    public init(openAPI: Components.Schemas.ResponseMCPCallArgumentsDeltaEvent) {
      self = .argumentsDelta(
        delta: openAPI.delta,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }

    public init(openAPI: Components.Schemas.ResponseMCPCallArgumentsDoneEvent) {
      self = .argumentsDone(
        arguments: openAPI.arguments,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex
      )
    }

    public init(openAPI: Components.Schemas.ResponseMCPCallCompletedEvent) {
      self = .completed(sequenceNumber: openAPI.sequenceNumber)
    }

    public init(openAPI: Components.Schemas.ResponseMCPCallFailedEvent) {
      self = .failed(sequenceNumber: openAPI.sequenceNumber)
    }

    public init(openAPI: Components.Schemas.ResponseMCPCallInProgressEvent) {
      self = .inProgress(
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        sequenceNumber: openAPI.sequenceNumber
      )
    }
  }

  public enum MCPListTools: Sendable {
    case completed(sequenceNumber: Int)
    case failed(sequenceNumber: Int)
    case inProgress(sequenceNumber: Int)

    public var value: String {
      switch self {
      case .completed: "completed"
      case .failed: "failed"
      case .inProgress: "in_progress"
      }
    }

    public init(openAPI: Components.Schemas.ResponseMCPListToolsCompletedEvent) {
      self = .completed(sequenceNumber: openAPI.sequenceNumber)
    }

    public init(openAPI: Components.Schemas.ResponseMCPListToolsFailedEvent) {
      self = .failed(sequenceNumber: openAPI.sequenceNumber)
    }

    public init(openAPI: Components.Schemas.ResponseMCPListToolsInProgressEvent) {
      self = .inProgress(sequenceNumber: openAPI.sequenceNumber)
    }
  }

  public enum Reasoning: Sendable {
    case delta(
      delta: OpenAPIRuntime.OpenAPIObjectContainer, itemId: String, outputIndex: Int,
      contentIndex: Int, sequenceNumber: Int)
    case done(text: String, itemId: String, outputIndex: Int)

    public var value: String {
      switch self {
      case .delta: "delta"
      case .done: "done"
      }
    }

    public init(openAPI: Components.Schemas.ResponseReasoningDeltaEvent) {
      self = .delta(
        delta: openAPI.delta,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        contentIndex: openAPI.contentIndex,
        sequenceNumber: openAPI.sequenceNumber
      )
    }

    public init(openAPI: Components.Schemas.ResponseReasoningDoneEvent) {
      self = .done(text: openAPI.text, itemId: openAPI.itemId, outputIndex: openAPI.outputIndex)
    }
  }

  public enum Queued: Sendable {
    case queued(response: Response, sequenceNumber: Int)

    public var value: String {
      switch self {
      case .queued: "queued"
      }
    }

    public init(openAPI: Components.Schemas.ResponseQueuedEvent) {
      self = .queued(
        response: Response(openAPI: openAPI.response), sequenceNumber: openAPI.sequenceNumber)
    }
  }

  public enum OutputTextAnnotation: Sendable {
    case added(
      annotation: OpenAPIRuntime.OpenAPIObjectContainer,
      annotationIndex: Int,
      contentIndex: Int,
      itemId: String,
      outputIndex: Int,
      sequenceNumber: Int
    )

    public var value: String {
      switch self {
      case .added: "added"
      }
    }

    public init(openAPI: Components.Schemas.ResponseOutputTextAnnotationAddedEvent) {
      self = .added(
        annotation: openAPI.annotation,
        annotationIndex: openAPI.annotationIndex,
        contentIndex: openAPI.contentIndex,
        itemId: openAPI.itemId,
        outputIndex: openAPI.outputIndex,
        sequenceNumber: openAPI.sequenceNumber
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
  case reasoningSummary(ReasoningSummary)
  case reasoningSummaryPart(ReasoningSummaryPart)
  case reasoningSummaryText(ReasoningSummaryText)
  case error(message: String, code: String?, param: String?)
  case audio(Audio)
  case audioTranscript(AudioTranscript)
  case codeInterpreterCall(CodeInterpreterCall)
  case imageGenCall(ImageGenCall)
  case mcpCall(MCPCall)
  case mcpListTools(MCPListTools)
  case reasoning(Reasoning)
  case queued(Queued)
  case outputTextAnnotation(OutputTextAnnotation)

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
    case .reasoningSummary(let summary): "response.reasoning_summary.\(summary.value)"
    case .reasoningSummaryPart(let summary): "response.reasoning_summary_part.\(summary.value)"
    case .reasoningSummaryText(let text): "response.reasoning_summary_text.\(text.value)"
    case .error: "error"
    case .audio(let audio): "response.audio.\(audio.value)"
    case .audioTranscript(let transcript): "response.audio_transcript.\(transcript.value)"
    case .codeInterpreterCall(let call): "response.code_interpreter_call.\(call.value)"
    case .imageGenCall(let call): "response.image_gen_call.\(call.value)"
    case .mcpCall(let call): "response.mcp_call.\(call.value)"
    case .mcpListTools(let tools): "response.mcp_list_tools.\(tools.value)"
    case .reasoning(let reasoning): "response.reasoning.\(reasoning.value)"
    case .queued(let queued): "response.queued.\(queued.value)"
    case .outputTextAnnotation(let annotation):
      "response.output_text_annotation.\(annotation.value)"
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
      guard let item = OutputItem(openAPI: event) else {
        print("Failed to parse OutputItem: \(event)")
        return nil
      }
      self = .outputItem(item)
    } else if let event = openAPI.value24 {
      guard let item = OutputItem(openAPI: event) else {
        print("Failed to parse OutputItem: \(event)")
        return nil
      }
      self = .outputItem(item)
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
    } else if let event = openAPI.value37 {
      self = .imageGenCall(ImageGenCall(openAPI: event))
    } else if let event = openAPI.value38 {
      self = .imageGenCall(ImageGenCall(openAPI: event))
    } else if let event = openAPI.value39 {
      self = .imageGenCall(ImageGenCall(openAPI: event))
    } else if let event = openAPI.value40 {
      self = .imageGenCall(ImageGenCall(openAPI: event))
    } else if let event = openAPI.value41 {
      self = .mcpCall(MCPCall(openAPI: event))
    } else if let event = openAPI.value42 {
      self = .mcpCall(MCPCall(openAPI: event))
    } else if let event = openAPI.value43 {
      self = .mcpCall(MCPCall(openAPI: event))
    } else if let event = openAPI.value44 {
      self = .mcpCall(MCPCall(openAPI: event))
    } else if let event = openAPI.value45 {
      self = .mcpCall(MCPCall(openAPI: event))
    } else if let event = openAPI.value46 {
      self = .mcpListTools(MCPListTools(openAPI: event))
    } else if let event = openAPI.value47 {
      self = .mcpListTools(MCPListTools(openAPI: event))
    } else if let event = openAPI.value48 {
      self = .mcpListTools(MCPListTools(openAPI: event))
    } else if let event = openAPI.value49 {
      self = .outputTextAnnotation(OutputTextAnnotation(openAPI: event))
    } else if let event = openAPI.value50 {
      self = .queued(Queued(openAPI: event))
    } else if let event = openAPI.value51 {
      self = .reasoning(Reasoning(openAPI: event))
    } else if let event = openAPI.value52 {
      self = .reasoning(Reasoning(openAPI: event))
    } else if let event = openAPI.value53 {
      self = .reasoningSummary(ReasoningSummary(openAPI: event))
    } else if let event = openAPI.value54 {
      self = .reasoningSummary(ReasoningSummary(openAPI: event))
    } else {
      return nil
    }
  }
}
