import Foundation
import HTTPTypes
import OpenAPIRuntime

struct DebugBodyMiddleware: ClientMiddleware {
  func intercept(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String,
    next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
  ) async throws -> (HTTPResponse, HTTPBody?) {
    // Debug request body
    if let body = body {
      print("Request body for \(operationID):")
      var data = Data()
      for try await chunk in body {
        data.append(contentsOf: chunk)
      }
      do {
        let json = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        if let prettyString = String(data: prettyData, encoding: .utf8) {
          print(prettyString)
        }
      } catch {
        print(String(data: data, encoding: .utf8) ?? "Could not decode body as string")
      }
    }

    // Get response
    let (response, responseBody) = try await next(request, body, baseURL)

    // Debug response body
    if let responseBody = responseBody {
      print("Response body for \(operationID):")
      var data = Data()
      for try await chunk in responseBody {
        data.append(contentsOf: chunk)
      }
      do {
        let json = try JSONSerialization.jsonObject(with: data)
        let prettyData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
        if let prettyString = String(data: prettyData, encoding: .utf8) {
          print(prettyString)
        }
      } catch {
        print(String(data: data, encoding: .utf8) ?? "Could not decode body as string")
      }
    }

    return (response, responseBody)
  }
}
