import Foundation
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

  // MARK: - Edit Image

  public func editImage(
    image: CreateImageEditRequest.ImageData,
    prompt: String,
    mask: String? = nil,
    model: CreateImageEditRequest.Model? = nil,
    n: Int? = nil,
    size: CreateImageEditRequest.Size? = nil,
    responseFormat: CreateImageEditRequest.ResponseFormat? = nil,
    user: String? = nil,
    quality: CreateImageEditRequest.Quality? = nil
  ) async throws -> ImagesResponse {
    let requestData = CreateImageEditRequest(
      image: image,
      prompt: prompt,
      mask: mask,
      model: model,
      n: n,
      size: size,
      responseFormat: responseFormat,
      user: user
    )
    return try await editImage(requestData)
  }

  public func editImage(_ requestData: CreateImageEditRequest) async throws -> ImagesResponse {
    let input = Operations.CreateImageEdit.Input(
      headers: .init(),
      body: .multipartForm(requestData.toOpenAPI())
    )

    let output = try await openAPIClient.createImageEdit(input)

    switch try output.ok.body {
    case .json(let response):
      return ImagesResponse(openAPI: response)
    }
  }
}
