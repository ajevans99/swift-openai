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
    image: Data,
    prompt: String,
    mask: Data? = nil,
    model: CreateImageRequest.Model? = nil,
    n: Int? = nil,
    size: CreateImageRequest.Size? = nil,
    responseFormat: CreateImageRequest.ResponseFormat? = nil,
    user: String? = nil
  ) async throws -> ImagesResponse {
    let requestData = CreateImageEditRequest(
      image: image,
      prompt: prompt,
      mask: mask,
      model: model.map { model in
        switch model {
        case .dallE2: return .dallE2
        case .dallE3: return .dallE2  // Map dall-e-3 to dall-e-2 for edits
        case .gptImage1: return .gptImage1
        }
      },
      n: n,
      size: size.map { size in
        switch size {
        case .auto: return .auto
        case .size1024x1024: return .size1024x1024
        case .size1536x1024: return .size1536x1024
        case .size1024x1536: return .size1024x1536
        case .size256x256: return .size256x256
        case .size512x512: return .size512x512
        case .size1792x1024: return .size1024x1024  // Map to closest supported size
        case .size1024x1792: return .size1024x1536  // Map to closest supported size
        }
      },
      responseFormat: responseFormat.map { format in
        switch format {
        case .url: return .url
        case .b64Json: return .b64Json
        }
      },
      user: user
    )
    return try await editImage(requestData)
  }

  public func editImage(_ requestData: CreateImageEditRequest) async throws -> ImagesResponse {
    let input = Operations.CreateImageEdit.Input(
      headers: .init(),
      body: .multipartForm(.init(requestData.toOpenAPI()))
    )

    let output = try await openAPIClient.createImageEdit(input)

    switch try output.ok.body {
    case .json(let response):
      return ImagesResponse(openAPI: response)
    }
  }
}
