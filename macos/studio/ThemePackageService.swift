import AppKit
import Foundation
import ImageIO

enum BuiltinThemeCatalog {
  static let orderedIDs = [
    "codex-default",
    "salary-cat-office",
    "miku-dream-skin",
    "nailong-sunshine",
    "cyrene-star-rail",
    "blue-archive-ensemble",
    "cartethyia-wuthering-waves",
    "furina-genshin",
    "firefly-star-rail",
    "saber-fate",
    "asuka-eva",
    "rem-rezero",
    "red-horizon",
    "black-gold-stage",
  ]

  static let ids = Set(orderedIDs)
}

struct ThemeDraft {
  let sourceImageURL: URL
  let id: String
  let name: String
  let author: String
  let description: String
  let category: String
  let appearance: String
  let accent: String
  let secondary: String
  let highlight: String
  let focusX: Double
}

struct ValidatedThemePackage {
  let manifest: ThemeManifest
  let sourceDirectory: URL
}

struct BuiltinThemeRepairReport {
  let repairedIDs: [String]
  let unavailableIDs: [String]

  var repairedCount: Int { repairedIDs.count }
  var isComplete: Bool { unavailableIDs.isEmpty }
}

enum ThemePackageError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}

private struct ThemeExportManifest: Encodable {
  let schemaVersion: Int
  let id: String
  let name: String
  let author: String
  let description: String
  let category: String
  let style: String
  let avatarOverlay: String
  let appearance: String
  let brandSubtitle: String
  let tagline: String
  let projectPrefix: String
  let projectLabel: String
  let statusText: String
  let quote: String
  let image: String
  let preview: String
  let colors: [String: String]
}

enum ThemePackageService {
  static let backgroundSize = NSSize(width: 2400, height: 800)
  static let previewSize = NSSize(width: 1200, height: 400)

  static func validate(directory: URL) throws -> ValidatedThemePackage {
    let root = directory.standardizedFileURL
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory),
          isDirectory.boolValue
    else {
      throw ThemePackageError.invalid("请选择一个主题文件夹")
    }

    let manifestURL = root.appendingPathComponent("theme.json")
    let backgroundURL = root.appendingPathComponent("background.png")
    let previewURL = root.appendingPathComponent("preview.png")
    try requireRegularFile(manifestURL, label: "theme.json", maximumBytes: 256 * 1024)
    try requireRegularFile(backgroundURL, label: "background.png", maximumBytes: 30 * 1024 * 1024)
    try requireRegularFile(previewURL, label: "preview.png", maximumBytes: 10 * 1024 * 1024)
    try requirePNG(backgroundURL, label: "background.png")
    try requirePNG(previewURL, label: "preview.png")

    let data = try Data(contentsOf: manifestURL)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ThemePackageError.invalid("theme.json 必须是 JSON 对象")
    }
    guard object["taskImage"] == nil else {
      throw ThemePackageError.invalid("schema 2 不使用 taskImage 字段")
    }

    let manifest: ThemeManifest
    do {
      manifest = try JSONDecoder().decode(ThemeManifest.self, from: data)
    } catch {
      throw ThemePackageError.invalid("theme.json 字段不完整：\(error.localizedDescription)")
    }

    try validateManifest(manifest)
    try validateImage(
      backgroundURL,
      label: "background.png",
      minimumWidth: 1200,
      minimumHeight: 400,
      maximumWidth: 12000,
      maximumHeight: 4000
    )
    try validateImage(
      previewURL,
      label: "preview.png",
      minimumWidth: 600,
      minimumHeight: 200,
      maximumWidth: 6000,
      maximumHeight: 2000
    )
    return ValidatedThemePackage(manifest: manifest, sourceDirectory: root)
  }

  static func install(
    package: ValidatedThemePackage,
    into themesRoot: URL,
    replacing: Bool
  ) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: themesRoot, withIntermediateDirectories: true)
    let destination = themesRoot.appendingPathComponent(package.manifest.id, isDirectory: true)
    guard destination.deletingLastPathComponent().standardizedFileURL == themesRoot.standardizedFileURL else {
      throw ThemePackageError.invalid("主题 ID 对应的目标目录无效")
    }
    if fileManager.fileExists(atPath: destination.path), !replacing {
      throw ThemePackageError.invalid("“\(package.manifest.name)”已经安装")
    }

    let token = UUID().uuidString
    let staging = themesRoot.appendingPathComponent(".\(package.manifest.id).importing.\(token)", isDirectory: true)
    let backup = themesRoot.appendingPathComponent(".\(package.manifest.id).backup.\(token)", isDirectory: true)
    try? fileManager.removeItem(at: staging)
    try? fileManager.removeItem(at: backup)

    do {
      try fileManager.createDirectory(at: staging, withIntermediateDirectories: false)
      for filename in ["theme.json", "background.png", "preview.png"] {
        try fileManager.copyItem(
          at: package.sourceDirectory.appendingPathComponent(filename),
          to: staging.appendingPathComponent(filename)
        )
      }
      _ = try validate(directory: staging)

      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.moveItem(at: destination, to: backup)
      }
      do {
        try fileManager.moveItem(at: staging, to: destination)
        try? fileManager.removeItem(at: backup)
      } catch {
        if fileManager.fileExists(atPath: backup.path) {
          try? fileManager.moveItem(at: backup, to: destination)
        }
        throw error
      }
    } catch {
      try? fileManager.removeItem(at: staging)
      try? fileManager.removeItem(at: backup)
      throw error
    }
  }

  /// Restores missing or incomplete built-in themes from the first complete
  /// source root that contains each catalog entry. Existing complete themes are
  /// left untouched so launching the manager does not repeatedly copy artwork.
  static func repairBuiltinThemes(
    from sourceRoots: [URL],
    into themesRoot: URL
  ) -> BuiltinThemeRepairReport {
    var repairedIDs: [String] = []
    var unavailableIDs: [String] = []

    for themeID in BuiltinThemeCatalog.orderedIDs {
      let destination = themesRoot.appendingPathComponent(themeID, isDirectory: true)
      if isCompleteBuiltinTheme(at: destination, expectedID: themeID) { continue }

      var repaired = false
      for sourceRoot in sourceRoots {
        let source = sourceRoot.appendingPathComponent(themeID, isDirectory: true)
        guard isCompleteBuiltinTheme(at: source, expectedID: themeID) else { continue }
        do {
          try installBuiltinTheme(from: source, id: themeID, into: themesRoot)
          repairedIDs.append(themeID)
          repaired = true
          break
        } catch {
          continue
        }
      }
      if !repaired { unavailableIDs.append(themeID) }
    }

    return BuiltinThemeRepairReport(
      repairedIDs: repairedIDs,
      unavailableIDs: unavailableIDs
    )
  }

  private static func installBuiltinTheme(
    from source: URL,
    id themeID: String,
    into themesRoot: URL
  ) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: themesRoot, withIntermediateDirectories: true)
    let destination = themesRoot.appendingPathComponent(themeID, isDirectory: true)
    let token = UUID().uuidString
    let staging = themesRoot.appendingPathComponent(".\(themeID).repairing.\(token)", isDirectory: true)
    let backup = themesRoot.appendingPathComponent(".\(themeID).backup.\(token)", isDirectory: true)
    try? fileManager.removeItem(at: staging)
    try? fileManager.removeItem(at: backup)

    do {
      try fileManager.copyItem(at: source, to: staging)
      guard isCompleteBuiltinTheme(at: staging, expectedID: themeID) else {
        throw ThemePackageError.invalid("内置主题修复源不完整：\(themeID)")
      }
      if fileManager.fileExists(atPath: destination.path) {
        try fileManager.moveItem(at: destination, to: backup)
      }
      do {
        try fileManager.moveItem(at: staging, to: destination)
        try? fileManager.removeItem(at: backup)
      } catch {
        if fileManager.fileExists(atPath: backup.path),
           !fileManager.fileExists(atPath: destination.path) {
          try? fileManager.moveItem(at: backup, to: destination)
        }
        throw error
      }
    } catch {
      try? fileManager.removeItem(at: staging)
      if fileManager.fileExists(atPath: backup.path),
         !fileManager.fileExists(atPath: destination.path) {
        try? fileManager.moveItem(at: backup, to: destination)
      }
      throw error
    }
  }

  static func create(draft: ThemeDraft, in themesRoot: URL, replacing: Bool) throws {
    try validateDraft(draft)
    try requireRegularFile(draft.sourceImageURL, label: "源图片", maximumBytes: 50 * 1024 * 1024)
    let fileManager = FileManager.default
    let temporary = fileManager.temporaryDirectory
      .appendingPathComponent("codex-skin-\(UUID().uuidString)", isDirectory: true)
    defer { try? fileManager.removeItem(at: temporary) }
    try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)

    guard let image = NSImage(contentsOf: draft.sourceImageURL) else {
      throw ThemePackageError.invalid("所选图片无法读取")
    }
    let backgroundData = try renderPNG(
      image: image,
      targetSize: backgroundSize,
      horizontalFocus: draft.focusX
    )
    let previewData = try renderPNG(
      image: image,
      targetSize: previewSize,
      horizontalFocus: draft.focusX
    )

    let appearance = draft.appearance
    let isDark = appearance == "dark"
    let accentRGB = try rgbComponents(from: draft.accent)
    let colors = [
      "background": isDark ? "#0d1422" : "#f4f7f9",
      "panel": isDark ? "#151e2e" : "#ffffff",
      "panelAlt": isDark ? "#202b3d" : "#edf3f6",
      "accent": draft.accent,
      "accentAlt": draft.accent,
      "secondary": draft.secondary,
      "highlight": draft.highlight,
      "text": isDark ? "#f4f7fb" : "#25313a",
      "muted": isDark ? "#aab5c4" : "#687783",
      "line": "rgba(\(accentRGB.red), \(accentRGB.green), \(accentRGB.blue), .28)",
    ]
    let shortName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
    let manifest = ThemeExportManifest(
      schemaVersion: 2,
      id: draft.id,
      name: shortName,
      author: draft.author.trimmingCharacters(in: .whitespacesAndNewlines),
      description: description,
      category: draft.category,
      style: draft.id,
      avatarOverlay: "show",
      appearance: appearance,
      brandSubtitle: "CUSTOM THEME",
      tagline: description.isEmpty ? "让喜欢的画面陪你完成今天的工作。" : description,
      projectPrefix: "\(shortName) · ",
      projectLabel: "选择项目",
      statusText: "CUSTOM THEME ONLINE",
      quote: "\(shortName) · 专注创作",
      image: "background.png",
      preview: "preview.png",
      colors: colors
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let manifestData = try encoder.encode(manifest)
    try manifestData.write(to: temporary.appendingPathComponent("theme.json"), options: .atomic)
    try backgroundData.write(to: temporary.appendingPathComponent("background.png"), options: .atomic)
    try previewData.write(to: temporary.appendingPathComponent("preview.png"), options: .atomic)

    let package = try validate(directory: temporary)
    try install(package: package, into: themesRoot, replacing: replacing)
  }

  static func suggestedID(for name: String) -> String {
    let latin = name.applyingTransform(.toLatin, reverse: false)?
      .applyingTransform(.stripDiacritics, reverse: false) ?? name
    let normalized = latin.lowercased()
      .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
      .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    if normalized.count >= 3 {
      return String(normalized.prefix(48))
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return "custom-\(formatter.string(from: Date()))"
  }

  private static func isCompleteBuiltinTheme(at directory: URL, expectedID: String) -> Bool {
    let manifestURL = directory.appendingPathComponent("theme.json")
    guard let data = try? Data(contentsOf: manifestURL),
          let manifest = try? JSONDecoder().decode(ThemeManifest.self, from: data),
          manifest.schemaVersion == 2,
          manifest.id == expectedID,
          manifest.image == "background.png",
          manifest.preview == "preview.png",
          manifest.avatarOverlay == "show",
          let style = manifest.style, !style.isEmpty,
          let appearance = manifest.appearance,
          ["auto", "light", "dark"].contains(appearance)
    else { return false }

    let backgroundURL = directory.appendingPathComponent("background.png")
    let previewURL = directory.appendingPathComponent("preview.png")
    do {
      try requireRegularFile(manifestURL, label: "theme.json", maximumBytes: 256 * 1024)
      try requireRegularFile(backgroundURL, label: "background.png", maximumBytes: 30 * 1024 * 1024)
      try requireRegularFile(previewURL, label: "preview.png", maximumBytes: 10 * 1024 * 1024)
      try requirePNG(backgroundURL, label: "background.png")
      try requirePNG(previewURL, label: "preview.png")
      try validateImage(
        backgroundURL,
        label: "background.png",
        minimumWidth: 1200,
        minimumHeight: 400,
        maximumWidth: 12000,
        maximumHeight: 4000
      )
      try validateImage(
        previewURL,
        label: "preview.png",
        minimumWidth: 600,
        minimumHeight: 200,
        maximumWidth: 6000,
        maximumHeight: 2000
      )
    } catch {
      return false
    }
    return true
  }

  private static func validateDraft(_ draft: ThemeDraft) throws {
    guard FileManager.default.isReadableFile(atPath: draft.sourceImageURL.path) else {
      throw ThemePackageError.invalid("请先选择背景图片")
    }
    try validateID(draft.id)
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (1...80).contains(name.count) else {
      throw ThemePackageError.invalid("主题名称需为 1 到 80 个字符")
    }
    guard draft.description.count <= 180 else {
      throw ThemePackageError.invalid("主题描述不能超过 180 个字符")
    }
    guard ["light", "dark"].contains(draft.appearance) else {
      throw ThemePackageError.invalid("创建主题时请选择浅色或暗色")
    }
    for (label, value) in [
      ("强调色", draft.accent),
      ("辅助色", draft.secondary),
      ("点缀色", draft.highlight),
    ] {
      guard value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else {
        throw ThemePackageError.invalid("\(label)格式无效")
      }
    }
  }

  private static func validateManifest(_ manifest: ThemeManifest) throws {
    guard manifest.schemaVersion == 2 else {
      throw ThemePackageError.invalid("schemaVersion 必须为 2")
    }
    try validateID(manifest.id)
    guard !manifest.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          manifest.name.count <= 80
    else {
      throw ThemePackageError.invalid("主题名称缺失或过长")
    }
    guard manifest.image == "background.png", manifest.preview == "preview.png" else {
      throw ThemePackageError.invalid("image 和 preview 必须使用标准 PNG 文件名")
    }
    guard manifest.avatarOverlay == "show" else {
      throw ThemePackageError.invalid("avatarOverlay 必须为 show")
    }
    guard manifest.mode == nil || manifest.mode != "original" else {
      throw ThemePackageError.invalid("自定义主题不能声明 original 模式")
    }
    guard let style = manifest.style,
          !style.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          style.count <= 64
    else {
      throw ThemePackageError.invalid("style 为必需字段且不能超过 64 个字符")
    }
    guard let appearance = manifest.appearance,
          ["auto", "light", "dark"].contains(appearance)
    else {
      throw ThemePackageError.invalid("appearance 仅支持 auto、light 或 dark")
    }
    let requiredColors = [
      "background", "panel", "panelAlt", "accent", "accentAlt",
      "secondary", "highlight", "text", "muted", "line",
    ]
    guard let colors = manifest.colors,
          requiredColors.allSatisfy({ colors[$0]?.isEmpty == false })
    else {
      throw ThemePackageError.invalid("colors 缺少 schema 2 必需色值")
    }
  }

  private static func validateID(_ id: String) throws {
    guard (3...64).contains(id.count),
          id.range(of: "^[a-z0-9]+(?:-[a-z0-9]+)*$", options: .regularExpression) != nil
    else {
      throw ThemePackageError.invalid("主题 ID 仅支持 3–64 位小写字母、数字和连字符")
    }
  }

  private static func requireRegularFile(_ url: URL, label: String, maximumBytes: Int) throws {
    let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    guard values?.isRegularFile == true, values?.isSymbolicLink != true else {
      throw ThemePackageError.invalid("缺少普通文件 \(label)，符号链接不受支持")
    }
    guard let size = values?.fileSize, size > 0, size <= maximumBytes else {
      throw ThemePackageError.invalid("\(label) 为空或超过大小限制")
    }
  }

  private static func requirePNG(_ url: URL, label: String) throws {
    let header = try Data(contentsOf: url, options: .mappedIfSafe).prefix(8)
    let signature = Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    guard header == signature else {
      throw ThemePackageError.invalid("\(label) 必须是真实 PNG 文件")
    }
  }

  private static func validateImage(
    _ url: URL,
    label: String,
    minimumWidth: Int,
    minimumHeight: Int,
    maximumWidth: Int,
    maximumHeight: Int
  ) throws {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width >= minimumWidth,
          height >= minimumHeight,
          width <= maximumWidth,
          height <= maximumHeight,
          width == height * 3
    else {
      throw ThemePackageError.invalid(
        "\(label) 必须是 \(minimumWidth)×\(minimumHeight) 到 \(maximumWidth)×\(maximumHeight) 的精确 3:1 图片"
      )
    }
  }

  private static func renderPNG(
    image: NSImage,
    targetSize: NSSize,
    horizontalFocus: Double
  ) throws -> Data {
    guard let representation = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(targetSize.width),
      pixelsHigh: Int(targetSize.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: representation)
    else {
      throw ThemePackageError.invalid("创建图片画布失败")
    }

    let sourceSize = image.size
    guard sourceSize.width > 0, sourceSize.height > 0 else {
      throw ThemePackageError.invalid("所选图片尺寸无效")
    }
    let targetRatio = targetSize.width / targetSize.height
    let sourceRatio = sourceSize.width / sourceSize.height
    let focus = min(max(horizontalFocus, 0), 1)
    let sourceRect: NSRect
    if sourceRatio > targetRatio {
      let cropWidth = sourceSize.height * targetRatio
      let originX = (sourceSize.width - cropWidth) * focus
      sourceRect = NSRect(x: originX, y: 0, width: cropWidth, height: sourceSize.height)
    } else {
      let cropHeight = sourceSize.width / targetRatio
      sourceRect = NSRect(
        x: 0,
        y: (sourceSize.height - cropHeight) / 2,
        width: sourceSize.width,
        height: cropHeight
      )
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor.clear.setFill()
    NSRect(origin: .zero, size: targetSize).fill()
    image.draw(
      in: NSRect(origin: .zero, size: targetSize),
      from: sourceRect,
      operation: .copy,
      fraction: 1,
      respectFlipped: false,
      hints: [.interpolation: NSImageInterpolation.high]
    )
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = representation.representation(using: .png, properties: [:]) else {
      throw ThemePackageError.invalid("PNG 编码失败")
    }
    return data
  }

  private static func rgbComponents(from hex: String) throws -> (red: Int, green: Int, blue: Int) {
    guard hex.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil,
          let value = Int(hex.dropFirst(), radix: 16)
    else {
      throw ThemePackageError.invalid("主题色格式无效")
    }
    return ((value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff)
  }
}
