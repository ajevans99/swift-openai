import Foundation

/// A cancellable stream of typed Responses API events.
///
/// Call ``cancel()`` to stop the provider task and the underlying HTTP body
/// iteration without relying on sequence deallocation.
@available(macOS 15.0, *)
public struct ResponseEventStream: AsyncSequence, Sendable {
  public typealias Element = StreamingResponse
  public typealias AsyncIterator = AsyncThrowingStream<StreamingResponse, Error>.Iterator

  private let events: AsyncThrowingStream<StreamingResponse, Error>
  private let cancellation: ResponseEventStreamCancellation

  init(
    events: AsyncThrowingStream<StreamingResponse, Error>,
    cancellation: ResponseEventStreamCancellation
  ) {
    self.events = events
    self.cancellation = cancellation
  }

  public func makeAsyncIterator() -> AsyncIterator {
    events.makeAsyncIterator()
  }

  /// Cancels event decoding and the underlying HTTP response stream.
  public func cancel() {
    cancellation.cancel()
  }
}

@available(macOS 15.0, *)
final class ResponseEventStreamCancellation: @unchecked Sendable {
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
