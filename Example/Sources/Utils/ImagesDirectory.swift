import Foundation

public enum ImagesDirectory {
  public static func create() throws -> URL {
    // Create images directory in the repository
    let repoDirectory = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let imagesDirectory = repoDirectory.appendingPathComponent(
      "generated-images", isDirectory: true)

    // Create the directory if it doesn't exist
    try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

    return imagesDirectory
  }
}
