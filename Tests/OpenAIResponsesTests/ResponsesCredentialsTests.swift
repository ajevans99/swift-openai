import CustomDump
import OpenAPIJSONRuntime
import Testing
@testable import OpenAIResponses

struct ResponsesCredentialsTests {
  @Test("OpenAI bearer credentials use the generated security scheme name")
  func bearerCredentials() async throws {
    let credentials = ResponsesCredentials(apiKey: "recording-only")
    let values = try await credentials.credentials(
      for: .init(schemes: [.init(name: "ApiKeyAuth", placement: .bearer)])
    )
    expectNoDifference(values, ["ApiKeyAuth": "recording-only"])
  }

  @Test("Bearer credentials do not satisfy unrelated authentication alternatives")
  func unrelatedSchemes() async throws {
    let credentials = ResponsesCredentials(apiKey: "recording-only")
    let alternatives: [JSONSecurityAlternative] = [
      .init(schemes: []),
      .init(schemes: [.init(name: "BasicAuth", placement: .basic)]),
      .init(schemes: [.init(name: "ApiKeyAuth", placement: .query("key"))]),
      .init(schemes: [
        .init(name: "First", placement: .bearer),
        .init(name: "Second", placement: .bearer),
      ]),
    ]
    for alternative in alternatives {
      let values = try await credentials.credentials(for: alternative)
      expectNoDifference(values, nil)
    }
  }
}
