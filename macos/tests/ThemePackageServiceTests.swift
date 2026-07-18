import AppKit
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

@main
struct ThemePackageServiceTests {
  static func main() throws {
    guard CommandLine.arguments.count == 3 else {
      throw ThemePackageError.invalid("Usage: ThemePackageServiceTests <source-image> <test-root>")
    }
    let source = URL(fileURLWithPath: CommandLine.arguments[1])
    let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    let themesRoot = root.appendingPathComponent("themes", isDirectory: true)
    try? FileManager.default.removeItem(at: root)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

    let draft = ThemeDraft(
      sourceImageURL: source,
      id: "test-created-theme",
      name: "创建服务测试",
      author: "Tests",
      description: "验证标准主题包生成与严格导入。",
      category: "测试",
      appearance: "dark",
      accent: "#4F9FE8",
      secondary: "#70C7B3",
      highlight: "#E8995C",
      focusX: 0.58
    )
    try ThemePackageService.create(draft: draft, in: themesRoot, replacing: false)
    let created = themesRoot.appendingPathComponent(draft.id, isDirectory: true)
    let package = try ThemePackageService.validate(directory: created)
    guard package.manifest.id == draft.id,
          package.manifest.style == draft.id,
          package.manifest.avatarOverlay == "show",
          package.manifest.appearance == "dark",
          package.manifest.image == "background.png",
          package.manifest.preview == "preview.png"
    else {
      throw ThemePackageError.invalid("Created manifest did not preserve schema 2 invariants")
    }
    try requireSize(created.appendingPathComponent("background.png"), width: 2400, height: 800)
    try requireSize(created.appendingPathComponent("preview.png"), width: 1200, height: 400)

    try requireRejectedCopy(of: created, at: root, name: "task-image") { object in
      object["taskImage"] = "task.png"
    }
    try requireRejectedCopy(of: created, at: root, name: "missing-style") { object in
      object.removeValue(forKey: "style")
    }
    try requireRejectedCopy(of: created, at: root, name: "missing-appearance") { object in
      object.removeValue(forKey: "appearance")
    }
    guard ThemePackageService.suggestedID(for: "蕾姆冰蓝夜庭").hasPrefix("lei-mu-bing-lan-ye-ting") else {
      throw ThemePackageError.invalid("Chinese theme name did not produce a complete suggested ID")
    }
    print("PASS: theme creation, normalized PNG output, complete ID suggestion, and strict import rejection.")
  }

  private static func requireRejectedCopy(
    of source: URL,
    at root: URL,
    name: String,
    mutate: (inout [String: Any]) -> Void
  ) throws {
    let invalid = root.appendingPathComponent("invalid-\(name)", isDirectory: true)
    try FileManager.default.copyItem(at: source, to: invalid)
    let manifestURL = invalid.appendingPathComponent("theme.json")
    let data = try Data(contentsOf: manifestURL)
    var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    mutate(&object)
    let invalidData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
    try invalidData.write(to: manifestURL, options: .atomic)

    var rejected = false
    do {
      _ = try ThemePackageService.validate(directory: invalid)
    } catch {
      rejected = true
    }
    guard rejected else {
      throw ThemePackageError.invalid("Strict importer accepted invalid package: \(name)")
    }
  }

  private static func requireSize(_ url: URL, width: Int, height: Int) throws {
    guard let image = NSImage(contentsOf: url),
          let representation = image.representations.first,
          representation.pixelsWide == width,
          representation.pixelsHigh == height
    else {
      throw ThemePackageError.invalid("Unexpected image size: \(url.lastPathComponent)")
    }
  }
}
