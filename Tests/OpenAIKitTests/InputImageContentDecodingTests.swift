import Foundation
import OpenAIFoundation
import Testing

@Suite("InputImageContent Decoding")
struct InputImageContentDecodingTests {
  @Test("Defaults detail to auto when omitted")
  func defaultsDetailToAutoWhenOmitted() throws {
    let payload = #"""
      {
        "type": "input_image",
        "image_url": "https://example.com/image.png"
      }
      """#

    let decoded = try JSONDecoder().decode(
      Components.Schemas.InputImageContent.self,
      from: Data(payload.utf8)
    )

    #expect(decoded.detail == .auto)
    #expect(decoded.imageUrl == "https://example.com/image.png")
    #expect(decoded.fileId == nil)
  }
}
