# ResponseSession Streaming

Build streaming experiences by combining raw protocol events with typed plugin
channels.

## Overview

``ResponseSession`` streaming APIs return a ``ResponseStreamHandle`` with:

- `raw`: protocol-level ``StreamingResponse`` events.
- `pluginEvents`: one typed ``PluginChannel`` (or a tuple of channels).

This lets consumers choose abstraction level per feature, without losing low
level visibility.

## One plugin

Use a single plugin for focused event handling:

```swift
let handle = try await session.stream(
  "Summarize this log file",
  streamOptions: .init(rawEvents: .disabled),
  plugins: TextPlugin()
)

let text = handle.pluginEvents
for try await event in text.events {
  switch event {
  case .delta(let chunk):
    print(chunk, terminator: "")
  case .completed:
    print()
  }
}
```

## Multiple plugins

Channels are returned in the same order as plugin arguments:

```swift
let handle = try await session.stream(
  "Generate a hero image and caption",
  plugins: TextPlugin(), ImagePlugin()
)

let (textChannel, imageChannel) = handle.pluginEvents
```

Consume every enabled channel concurrently. Channels are independent, so
reading one channel does not drain another.

## Response lifecycle

Use ``ResponseLifecyclePlugin`` to observe response IDs and terminal states
without matching raw SSE event names:

```swift
let handle = try await session.stream(
  inputItems: history,
  streamOptions: .init(rawEvents: .disabled),
  plugins: ResponseLifecyclePlugin(), TextPlugin()
)

let (lifecycle, text) = handle.pluginEvents
for try await event in lifecycle.events {
  switch event {
  case .created(let response), .completed(let response):
    print(response.id)
  case .failed(let response), .incomplete(let response):
    print("Terminal response:", response.id)
  case .error(let message, _, _):
    print(message)
  }
}
```

## Tool orchestration

Register function tools directly on ``ToolOrchestratorPlugin`` for streaming
flows:

```swift
let orchestrator = ToolOrchestratorPlugin(
  tools: [WeatherTool(apiKey: "...")],
  errorPolicy: .askAssistantToClarify { error in
    "Weather tool failed (\(error)). Ask the user to confirm location."
  }
)

let handle = try await session.stream(
  "What's the weather in San Francisco?",
  plugins: TextPlugin(), orchestrator
)
```

Session-level ``ResponseSession/register(tool:)`` remains available and is used
as a fallback lookup path for compatibility.

When set, `ToolOrchestratorPlugin.errorPolicy` overrides handling for both:

- plugin-local tools registered on the orchestrator, and
- fallback execution through session-level tool registration.

If omitted, fallback continues using the session-level default policy.

## Raw streaming

For protocol-level handling, use:

- ``ResponseSession/streamRaw(_:additionalItems:previousResponseID:)``
- ``ResponseSession/streamRaw(items:previousResponseID:)``
- ``ResponseSession/streamRawHandle(inputItems:previousResponseID:metadata:requestOptions:bufferingPolicy:)``

This is useful when implementing custom plugin behavior outside of
`OpenAIKit`.

## Cancellation

Call `handle.cancel()` to explicitly stop the response task, underlying HTTP
body, and every raw/plugin channel. Cancelled channels terminate with
`CancellationError`.

## Event retention

Raw and plugin channels are unbounded and lossless by default. This avoids
corrupting semantic streams such as text deltas, but an enabled channel that is
never consumed can retain memory for the duration of the response.

Use ``ResponseStreamOptions`` to disable unused raw events. Bounded channels are
also available; they terminate the entire response with
``ResponseSessionError/bufferOverflow(channel:capacity:)`` if their capacity is
exceeded, rather than silently dropping events.

## Error behavior

If a plugin throws while consuming events:

- The raw channel is terminated with that error.
- All plugin channels are terminated with the same error.

This keeps stream termination consistent across channels.
