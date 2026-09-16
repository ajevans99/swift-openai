import OpenAPIJSONRuntime

struct ResponsesCredentials: JSONCredentialProvider {
  let apiKey: String

  func credentials(for alternative: JSONSecurityAlternative) async throws -> [String: String]? {
    guard alternative.schemes.count == 1,
      let scheme = alternative.schemes.first,
      scheme.placement == .bearer
    else { return nil }
    return [scheme.name: apiKey]
  }
}
