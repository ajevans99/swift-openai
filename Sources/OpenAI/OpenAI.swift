import OpenAIModels
import OpenAPIRuntime

public struct OpenAI {
  let openAPIClient: Client

  public init(
    transport: any ClientTransport,
    apiKey: String
  ) throws {
    openAPIClient = Client(
      serverURL: try Servers.Server1.url(),
      transport: transport,
      middlewares: [
        AuthenticationMiddleware(bearerToken: apiKey)
      ]
    )
  }
}
