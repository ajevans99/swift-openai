import Foundation
import HTTPTypes
import OpenAPIRuntime

actor RecordingTransport: ClientTransport {
  struct Request: Sendable {
    let request: HTTPRequest
    let body: Data?
    let baseURL: URL
    let operationID: String
  }

  struct Reply: Sendable {
    let response: HTTPResponse
    let body: HTTPBody?
  }

  enum Failure: Error {
    case noQueuedResponse
  }

  private(set) var requests: [Request] = []
  private var replies: [Reply]

  init(replies: [Reply] = []) {
    self.replies = replies
  }

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    let bytes: Data?
    if let body {
      bytes = try await Data(collecting: body, upTo: 1_000_000)
    } else {
      bytes = nil
    }
    requests.append(
      Request(request: request, body: bytes, baseURL: baseURL, operationID: operationID)
    )
    guard !replies.isEmpty else { throw Failure.noQueuedResponse }
    let reply = replies.removeFirst()
    return (reply.response, reply.body)
  }
}
