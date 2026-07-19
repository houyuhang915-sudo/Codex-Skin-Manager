import Foundation

private enum UpdateMetadataTestError: Error {
  case invalid(String)
}

@main
enum UpdateMetadataTests {
  static func main() throws {
    for value in ["2026-07-19T15:55:16.963Z", "2026-07-19T15:55:16Z"] {
      guard UpdateMetadata.parsePublishedAt(value) != nil else {
        throw UpdateMetadataTestError.invalid("Rejected valid ISO 8601 timestamp: \(value)")
      }
    }
    guard UpdateMetadata.parsePublishedAt("2026/07/19 15:55:16") == nil else {
      throw UpdateMetadataTestError.invalid("Accepted a non-ISO timestamp.")
    }

    guard CommandLine.arguments.count == 2 else {
      throw UpdateMetadataTestError.invalid("Expected the updates directory.")
    }
    let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    for filename in ["stable.json", "themes.json"] {
      let data = try Data(contentsOf: root.appendingPathComponent(filename))
      guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let publishedAt = object["publishedAt"] as? String,
            UpdateMetadata.parsePublishedAt(publishedAt) != nil
      else {
        throw UpdateMetadataTestError.invalid("Invalid publishedAt in \(filename).")
      }
    }
    print("PASS: macOS accepts signed-feed ISO 8601 timestamps with optional fractions.")
  }
}
