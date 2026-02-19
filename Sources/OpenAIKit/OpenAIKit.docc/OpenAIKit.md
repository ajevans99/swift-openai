# ``OpenAIKit``

High-level APIs for building conversational, tool-augmented experiences on top
of the OpenAI Responses API.

## Overview

`OpenAIKit` provides:

- ``ResponseSession`` for multi-turn orchestration.
- Typed streaming via plugin channels.
- Raw streaming access for protocol-level control.
- Tool abstractions for function calling.

A typical flow:

1. Create an ``OpenAI`` client.
2. Create a ``ResponseSession``.
3. Configure tools and plugins.
4. Stream raw and typed events from one handle.

```swift
let handle = try await session.stream(
  "Plan a day trip to Yosemite",
  plugins: TextPlugin(), ToolOrchestratorPlugin()
)

let (textChannel, toolChannel) = handle.pluginEvents
```

## Topics

### Sessions

- ``ResponseSession``
- ``ResponseSessionError``

### Streaming

- ``ResponseStreamPlugin``
- ``StreamPluginContext``
- ``PluginChannel``
- ``ResponseStreamHandle``
- <doc:ResponseSessionStreaming>

### Built-in Plugins

- ``TextPlugin``
- ``ToolOrchestratorPlugin``
- ``ImagePlugin``

### Tools

- ``Toolable``
- ``ToolErrorPolicy``
