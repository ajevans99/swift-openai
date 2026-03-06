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

This is useful when implementing custom plugin behavior outside of
`OpenAIKit`.

## Buffering and drops

Raw and plugin channels use bounded `bufferingNewest` semantics. If a consumer
falls behind, older buffered events are dropped.

Use ``PluginChannel/droppedCount()`` to inspect loss for each plugin channel.

## Error behavior

If a plugin throws while consuming events:

- The raw channel is terminated with that error.
- All plugin channels are terminated with the same error.

This keeps stream termination consistent across channels.
