import Foundation
import OpenAICore

/// A transformation layer that converts raw ``StreamingResponse`` events into
/// higher-level, domain-specific events.
///
/// Implement this protocol to extend ``ResponseSession`` streaming with custom
/// behavior while keeping typed output channels for consumers.
@available(macOS 15.0, *)
public protocol ResponseStreamPlugin: Sendable {
  /// The strongly typed event emitted by this plugin.
  associatedtype Event: Sendable

  /// Consumes a single raw stream event.
  ///
  /// - Parameters:
  ///   - event: The raw streaming event emitted by the OpenAI Responses SSE
  ///     stream.
  ///   - context: Shared mutable context for cross-event coordination.
  /// - Returns: A typed event to emit for consumers, or `nil` if this raw
  ///   event does not produce plugin output.
  func consume(
    _ event: StreamingResponse,
    context: inout StreamPluginContext
  ) async throws -> Event?

  /// Finishes plugin processing when the underlying raw stream completes.
  ///
  /// - Parameter context: Shared mutable context for cross-event coordination.
  /// - Returns: A final typed event to emit for consumers, or `nil`.
  func finish(context: inout StreamPluginContext) async throws -> Event?
}

@available(macOS 15.0, *)
public extension ResponseStreamPlugin {
  /// Default no-op finish behavior.
  func finish(context: inout StreamPluginContext) async throws -> Event? {
    nil
  }
}

/// Shared mutable context provided to stream plugins.
///
/// Plugins can use this context to enqueue follow-up ``Item`` values and to
/// invoke function tools registered at the session level (compatibility path).
@available(macOS 15.0, *)
public struct StreamPluginContext: Sendable {
  private let executeFunctionToolImpl: @Sendable (
    _ name: String,
    _ arguments: String,
    _ policy: ToolErrorPolicy?
  ) async throws -> String
  private var followUpItems: [Item] = []

  init(
    executeFunctionTool: @escaping @Sendable (
      _ name: String,
      _ arguments: String,
      _ policy: ToolErrorPolicy?
    ) async throws -> String
  ) {
    self.executeFunctionToolImpl = executeFunctionTool
  }

  /// Calls a function tool by name using the session-level registry.
  ///
  /// Use this only as a compatibility fallback. Prefer plugin-owned tool
  /// registries (for example ``ToolOrchestratorPlugin``).
  ///
  /// - Parameters:
  ///   - name: The function tool name.
  ///   - arguments: A JSON argument string to pass to the tool.
  ///   - errorPolicy: Optional override for tool error handling. If omitted,
  ///     the session default policy is used.
  /// - Returns: Tool output string.
  public mutating func callFunctionTool(
    named name: String,
    arguments: String,
    errorPolicy: ToolErrorPolicy? = nil
  ) async throws -> String {
    try await executeFunctionToolImpl(name, arguments, errorPolicy)
  }

  /// Enqueues an item that will be sent in a follow-up request in the same
  /// session turn.
  ///
  /// This is most commonly used by orchestration plugins after executing a tool
  /// call.
  ///
  /// - Parameter item: The follow-up response input item.
  public mutating func enqueueFollowUpItem(_ item: Item) {
    followUpItems.append(item)
  }

  mutating func drainFollowUpItems() -> [Item] {
    defer { followUpItems.removeAll(keepingCapacity: true) }
    return followUpItems
  }
}

/// A typed stream channel for events emitted by a specific plugin.
///
/// Access these channels through ``ResponseStreamHandle/pluginEvents``.
@available(macOS 15.0, *)
public struct PluginChannel<P: ResponseStreamPlugin>: Sendable {
  /// Asynchronous sequence of typed plugin events.
  public let events: AsyncThrowingStream<P.Event, Error>
  private let droppedCountProvider: @Sendable () -> Int

  init(
    events: AsyncThrowingStream<P.Event, Error>,
    droppedCountProvider: @escaping @Sendable () -> Int
  ) {
    self.events = events
    self.droppedCountProvider = droppedCountProvider
  }

  /// Returns the number of events dropped due to bounded buffering.
  ///
  /// Channels use `bufferingNewest` semantics. If consumers are slower than
  /// producers, older buffered events are dropped.
  public func droppedCount() -> Int {
    droppedCountProvider()
  }
}

/// A streaming handle containing both raw and typed plugin event channels.
///
/// `PluginEvents` is either a single ``PluginChannel`` (for one plugin) or a
/// tuple of channels (for multi-plugin overloads).
@available(macOS 15.0, *)
public struct ResponseStreamHandle<PluginEvents: Sendable>: Sendable {
  /// Raw protocol-level stream events.
  public let raw: AsyncThrowingStream<StreamingResponse, Error>
  /// Typed plugin event channel(s), aligned with plugin order.
  public let pluginEvents: PluginEvents
}

final class StreamEmitter<Element: Sendable>: @unchecked Sendable {
  private let continuation: AsyncThrowingStream<Element, Error>.Continuation
  private let lock = NSLock()
  private var droppedCountValue = 0

  init(
    continuation: AsyncThrowingStream<Element, Error>.Continuation
  ) {
    self.continuation = continuation
  }

  func yield(_ element: Element) {
    switch continuation.yield(element) {
    case .dropped:
      lock.lock()
      droppedCountValue += 1
      lock.unlock()
    case .enqueued, .terminated:
      break
    @unknown default:
      break
    }
  }

  func finish(throwing error: Error? = nil) {
    if let error {
      continuation.finish(throwing: error)
    } else {
      continuation.finish()
    }
  }

  func droppedCount() -> Int {
    lock.lock()
    defer { lock.unlock() }
    return droppedCountValue
  }
}
