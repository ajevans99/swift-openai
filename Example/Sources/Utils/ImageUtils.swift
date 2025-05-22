import Foundation

public enum ImageUtils {
  /// Saves base64 encoded images to the specified directory
  /// - Parameters:
  ///   - images: Array of base64 encoded image data
  ///   - imageId: Base identifier for the images
  ///   - imagesDirectory: Directory to save the images to
  /// - Returns: Array of tuples containing the image ID and file path
  /// - Throws: File system errors if writing fails
  public static func saveBase64Images(
    images: [String?],
    imageId: String,
    imagesDirectory: URL
  ) throws -> [(id: String, url: String)] {
    var savedImages: [(id: String, url: String)] = []

    for (index, imageData) in images.enumerated() {
      if let imageData = imageData,
        let data = Data(base64Encoded: imageData)
      {
        let imageId = "\(imageId)-\(index + 1)"
        let imageURL = imagesDirectory.appendingPathComponent("\(imageId).png")
        try data.write(to: imageURL)
        savedImages.append((id: imageId, url: imageURL.path))
      }
    }

    return savedImages
  }

  /// Saves a partial base64 encoded image to the specified directory
  /// - Parameters:
  ///   - base64Data: Base64 encoded image data
  ///   - imageId: Base identifier for the image
  ///   - partialIndex: Index of the partial image
  ///   - imagesDirectory: Directory to save the image to
  /// - Returns: Tuple containing the image ID and file path
  /// - Throws: File system errors if writing fails
  public static func savePartialImage(
    base64Data: String,
    imageId: String,
    partialIndex: Int,
    imagesDirectory: URL
  ) throws -> (id: String, url: String) {
    guard let data = Data(base64Encoded: base64Data) else {
      throw NSError(
        domain: "ImageUtils", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid base64 data"])
    }

    let partialImageId = "\(imageId)-partial-\(partialIndex)"
    let imageURL = imagesDirectory.appendingPathComponent("\(partialImageId).png")
    try data.write(to: imageURL)

    return (id: partialImageId, url: imageURL.path)
  }
}
