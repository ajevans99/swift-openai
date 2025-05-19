import OpenAIFoundation
import OpenAPIRuntime

extension OpenAI {
  // MARK: - Create Image

  public func createImage(
    prompt: String,
    model: CreateImageRequest.Model? = nil,
    n: Int? = nil,
    quality: CreateImageRequest.Quality? = nil,
    responseFormat: CreateImageRequest.ResponseFormat? = nil,
    outputFormat: CreateImageRequest.OutputFormat? = nil,
    outputCompression: Int? = nil,
    size: CreateImageRequest.Size? = nil,
    moderation: CreateImageRequest.Moderation? = nil,
    background: CreateImageRequest.Background? = nil,
    style: CreateImageRequest.Style? = nil,
    user: String? = nil
  ) async throws -> ImagesResponse {
    let requestData = CreateImageRequest(
      prompt: prompt,
      model: model,
      n: n,
      quality: quality,
      responseFormat: responseFormat,
      outputFormat: outputFormat,
      outputCompression: outputCompression,
      size: size,
      moderation: moderation,
      background: background,
      style: style,
      user: user
    )
    return try await createImage(requestData)
  }

  public func createImage(_ requestData: CreateImageRequest) async throws -> ImagesResponse {
    let input = Operations.CreateImage.Input(
      headers: .init(),
      body: .json(requestData.toOpenAPI())
    )

    let output = try await openAPIClient.createImage(input)

    switch try output.ok.body {
    case .json(let response):
      return ImagesResponse(openAPI: response)
    }
  }
}
