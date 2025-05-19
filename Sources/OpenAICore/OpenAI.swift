import Logging
@_exported import OpenAIFoundation
import OpenAPIRuntime

public struct OpenAI: Sendable {
  let openAPIClient: Client
  public let logger: Logger

  public init(
    transport: any ClientTransport,
    apiKey: String,
    logger: Logger? = nil
  ) throws {
    var logger = logger ?? Logger(label: "swift-openai")
    logger.logLevel = .debug

    openAPIClient = Client(
      serverURL: try Servers.Server1.url(),
      transport: transport,
      middlewares: [
        AuthenticationMiddleware(bearerToken: apiKey),
        LoggingMiddleware(logger: logger, bodyLoggingConfiguration: .upTo(maxBytes: 2500)),
        // DebugBodyMiddleware(),
      ]
    )
    self.logger = logger
  }
}
