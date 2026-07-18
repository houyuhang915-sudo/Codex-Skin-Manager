import Foundation

struct ThemeManifest: Decodable {
  let schemaVersion: Int
  let id: String
  let name: String
  let author: String?
  let description: String?
  let category: String?
  let mode: String?
  let style: String?
  let avatarOverlay: String?
  let appearance: String?
  let brandSubtitle: String?
  let image: String
  let preview: String?
  let colors: [String: String]?
}
