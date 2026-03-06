import Foundation
import OpenAPIRuntime

public struct OpenAIHTTPError: Error, Sendable, LocalizedError, CustomStringConvertible {
  public let operation: String
  public let statusCode: Int
  public let message: String
  public let type: String?
  public let param: String?
  public let code: String?
  public let requestID: String?
  public let rawBodyPreview: String?

  public var errorDescription: String? {
    description
  }

  public var description: String {
    var components = ["OpenAI \(operation) failed with HTTP \(statusCode): \(message)"]
    if let code, !code.isEmpty {
      components.append("code=\(code)")
    }
    if let param, !param.isEmpty {
      components.append("param=\(param)")
    }
    if let requestID, !requestID.isEmpty {
      components.append("request_id=\(requestID)")
    }
    return components.joined(separator: " ")
  }
}

extension OpenAI {
  private struct APIErrorEnvelope: Decodable {
    let error: APIErrorBody
  }

  private struct APIErrorBody: Decodable {
    let message: String
    let type: String?
    let param: String?
    let code: String?
  }

  private struct PreviewEnvelope: Decodable {
    let value: String?
  }

  func makeUndocumentedResponseError(
    statusCode: Int,
    payload: OpenAPIRuntime.UndocumentedPayload,
    operation: String
  ) async -> OpenAIHTTPError {
    let bodyPreview = await undocumentedPayloadBodyPreview(payload.body, maxBytes: 16_384)
    let requestID = extractRequestID(from: payload)

    if let parsed = parseOpenAIErrorBody(from: bodyPreview) {
      return OpenAIHTTPError(
        operation: operation,
        statusCode: statusCode,
        message: parsed.message,
        type: parsed.type,
        param: parsed.param,
        code: parsed.code,
        requestID: requestID,
        rawBodyPreview: bodyPreview
      )
    }

    return OpenAIHTTPError(
      operation: operation,
      statusCode: statusCode,
      message: "Unexpected response from OpenAI.",
      type: nil,
      param: nil,
      code: nil,
      requestID: requestID,
      rawBodyPreview: bodyPreview
    )
  }

  private func parseOpenAIErrorBody(from bodyPreview: String?) -> APIErrorBody? {
    guard let bodyPreview, let data = bodyPreview.data(using: .utf8) else {
      return nil
    }

    let decoder = JSONDecoder()

    if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
      return envelope.error
    }

    // Some telemetry wrappers store the real JSON under a string-valued `value` key.
    if let wrapper = try? decoder.decode(PreviewEnvelope.self, from: data),
      let nested = wrapper.value?.data(using: .utf8),
      let envelope = try? decoder.decode(APIErrorEnvelope.self, from: nested)
    {
      return envelope.error
    }

    return nil
  }

  private func extractRequestID(from payload: OpenAPIRuntime.UndocumentedPayload) -> String? {
    for field in payload.headerFields {
      if String(describing: field.name).lowercased() == "x-request-id" {
        return field.value
      }
    }
    return nil
  }

  private func undocumentedPayloadBodyPreview(_ body: OpenAPIRuntime.HTTPBody?, maxBytes: Int)
    async -> String?
  {
    guard let body else {
      return nil
    }

    guard let data = try? await Data(collecting: body, upTo: maxBytes) else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }
}
