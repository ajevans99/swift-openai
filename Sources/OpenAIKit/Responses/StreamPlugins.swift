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

  /// Returns tools that this plugin needs advertised on response requests.
  ///
  /// Plugins that only project events can use the default empty implementation.
  func responseTools() async -> [OpenAICore.Tool]
}

@available(macOS 15.0, *)
public extension ResponseStreamPlugin {
  /// Default no-op finish behavior.
  func finish(context: inout StreamPluginContext) async throws -> Event? {
    nil
  }

  /// Default behavior for plugins that do not own tools.
  func responseTools() async -> [OpenAICore.Tool] {
    []
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

  init(events: AsyncThrowingStream<P.Event, Error>) {
    self.events = events
  }

  /// Returns zero because channels no longer silently drop events.
  @available(*, deprecated, message: "Streams are lossless or fail with bufferOverflow.")
  public func droppedCount() -> Int {
    0
  }
}

/// Configures event retention for a response stream channel.
@available(macOS 15.0, *)
public enum ResponseStreamBufferingPolicy: Sendable, Equatable {
  /// Retains every event until consumed. This is lossless but unconsumed
  /// channels can grow without bound.
  case unbounded
  /// Retains a bounded prefix and fails the entire stream with
  /// ``ResponseSessionError/bufferOverflow(channel:capacity:)`` rather than
  /// silently dropping the next event.
  case bounded(Int)
  /// Discards all events for the channel. Use this for raw events when only
  /// plugin projections are needed.
  case disabled
}

/// Controls raw and plugin channel event retention.
@available(macOS 15.0, *)
public struct ResponseStreamOptions: Sendable, Equatable {
  public var rawEvents: ResponseStreamBufferingPolicy
  public var pluginEvents: ResponseStreamBufferingPolicy

  public init(
    rawEvents: ResponseStreamBufferingPolicy = .unbounded,
    pluginEvents: ResponseStreamBufferingPolicy = .unbounded
  ) {
    self.rawEvents = rawEvents
    self.pluginEvents = pluginEvents
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
  private let cancellation: StreamTaskCancellation

  init(
    raw: AsyncThrowingStream<StreamingResponse, Error>,
    pluginEvents: PluginEvents,
    cancellation: StreamTaskCancellation
  ) {
    self.raw = raw
    self.pluginEvents = pluginEvents
    self.cancellation = cancellation
  }

  /// Cancels the provider task, HTTP stream, and all consumer channels.
  public func cancel() {
    cancellation.cancel()
  }
}

/// A cancellable raw-only Responses API stream.
@available(macOS 15.0, *)
public struct RawResponseStreamHandle: Sendable {
  /// Raw protocol-level events.
  public let events: AsyncThrowingStream<StreamingResponse, Error>
  private let cancellation: StreamTaskCancellation

  init(
    events: AsyncThrowingStream<StreamingResponse, Error>,
    cancellation: StreamTaskCancellation
  ) {
    self.events = events
    self.cancellation = cancellation
  }

  /// Cancels the provider task, HTTP stream, and raw consumer channel.
  public func cancel() {
    cancellation.cancel()
  }
}

@available(macOS 15.0, *)
final class StreamEmitter<Element: Sendable>: @unchecked Sendable {
  private let continuation: AsyncThrowingStream<Element, Error>.Continuation
  private let channelName: String
  private let capacity: Int?
  private let isDisabled: Bool

  init(
    continuation: AsyncThrowingStream<Element, Error>.Continuation,
    channelName: String,
    policy: ResponseStreamBufferingPolicy
  ) {
    self.continuation = continuation
    self.channelName = channelName
    switch policy {
    case .unbounded:
      self.capacity = nil
      self.isDisabled = false
    case .bounded(let capacity):
      precondition(capacity > 0, "Bounded stream capacity must be greater than zero")
      self.capacity = capacity
      self.isDisabled = false
    case .disabled:
      self.capacity = nil
      self.isDisabled = true
    }
  }

  func yield(_ element: Element) throws {
    guard !isDisabled else { return }
    switch continuation.yield(element) {
    case .dropped:
      throw ResponseSessionError.bufferOverflow(
        channel: channelName,
        capacity: capacity ?? 0
      )
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
}

@available(macOS 15.0, *)
final class StreamTaskCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var task: Task<Void, Never>?
  private var isCancelled = false

  func install(_ task: Task<Void, Never>) {
    let shouldCancel = lock.withLock {
      self.task = task
      return isCancelled
    }
    if shouldCancel {
      task.cancel()
    }
  }

  func cancel() {
    let task = lock.withLock {
      isCancelled = true
      return self.task
    }
    task?.cancel()
  }

  func taskDidFinish() {
    lock.withLock {
      task = nil
    }
  }
}
