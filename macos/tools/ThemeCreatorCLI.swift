import Darwin
import Foundation

private struct ThemeCreatorResult: Encodable {
  let schemaVersion = 1
  let status = "installed"
  let themeId: String
  let name: String
  let themePath: String
  let themesRoot: String
  let managerRefresh = "automatic"
}

private enum ThemeCreatorCLIError: LocalizedError {
  case invalid(String)

  var errorDescription: String? {
    switch self {
    case .invalid(let message): return message
    }
  }
}

@main
struct ThemeCreatorCLI {
  static func main() {
    do {
      let arguments = try parseArguments(Array(CommandLine.arguments.dropFirst()))
      if arguments["help"] == "true" {
        printUsage()
        return
      }

      let image = try required("image", in: arguments)
      let id = try required("id", in: arguments)
      let name = try required("name", in: arguments)
      guard !BuiltinThemeCatalog.ids.contains(id) else {
        throw ThemeCreatorCLIError.invalid("内置主题 ID 受保护，请使用新的主题 ID")
      }

      let focusPercent = try number("focus", in: arguments, fallback: 50)
      guard (0...100).contains(focusPercent) else {
        throw ThemeCreatorCLIError.invalid("--focus 必须为 0 到 100")
      }
      let themesRoot = URL(
        fileURLWithPath: arguments["themes-root"] ?? defaultThemesRoot(),
        isDirectory: true
      ).standardizedFileURL
      let replacing = arguments["replace"] == "true"
      let draft = ThemeDraft(
        sourceImageURL: URL(fileURLWithPath: image).standardizedFileURL,
        id: id,
        name: name,
        author: arguments["author"] ?? "",
        description: arguments["description"] ?? "",
        category: arguments["category"] ?? "自定义",
        appearance: arguments["appearance"] ?? "dark",
        accent: arguments["accent"] ?? "#4F9FE8",
        secondary: arguments["secondary"] ?? "#70C7B3",
        highlight: arguments["highlight"] ?? "#E8995C",
        focusX: focusPercent / 100
      )

      try ThemePackageService.create(draft: draft, in: themesRoot, replacing: replacing)
      let destination = themesRoot.appendingPathComponent(id, isDirectory: true)
      _ = try ThemePackageService.validate(directory: destination)
      try writeLibraryRevision(for: id, themesRoot: themesRoot)

      let result = ThemeCreatorResult(
        themeId: id,
        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
        themePath: destination.path,
        themesRoot: themesRoot.path
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
      FileHandle.standardOutput.write(try encoder.encode(result))
      FileHandle.standardOutput.write(Data("\n".utf8))
    } catch {
      FileHandle.standardError.write(Data("创建主题失败：\(error.localizedDescription)\n".utf8))
      exit(1)
    }
  }

  private static func parseArguments(_ input: [String]) throws -> [String: String] {
    var result: [String: String] = [:]
    var index = 0
    let flags = Set(["replace", "help"])
    let values = Set([
      "image", "id", "name", "author", "description", "category", "appearance",
      "accent", "secondary", "highlight", "focus", "themes-root",
    ])

    while index < input.count {
      let argument = input[index]
      guard argument.hasPrefix("--") else {
        throw ThemeCreatorCLIError.invalid("未知参数：\(argument)")
      }
      let key = String(argument.dropFirst(2))
      if flags.contains(key) {
        result[key] = "true"
        index += 1
        continue
      }
      guard values.contains(key) else {
        throw ThemeCreatorCLIError.invalid("未知参数：\(argument)")
      }
      guard index + 1 < input.count, !input[index + 1].hasPrefix("--") else {
        throw ThemeCreatorCLIError.invalid("\(argument) 缺少参数值")
      }
      result[key] = input[index + 1]
      index += 2
    }
    return result
  }

  private static func required(_ key: String, in arguments: [String: String]) throws -> String {
    guard let value = arguments[key]?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty
    else {
      throw ThemeCreatorCLIError.invalid("缺少 --\(key)")
    }
    return value
  }

  private static func number(
    _ key: String,
    in arguments: [String: String],
    fallback: Double
  ) throws -> Double {
    guard let raw = arguments[key] else { return fallback }
    guard let value = Double(raw) else {
      throw ThemeCreatorCLIError.invalid("--\(key) 必须是数字")
    }
    return value
  }

  private static func defaultThemesRoot() -> String {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support/CodexDreamSkinStudio/themes")
      .path
  }

  private static func writeLibraryRevision(for id: String, themesRoot: URL) throws {
    let marker = themesRoot.deletingLastPathComponent()
      .appendingPathComponent("theme-library.changed")
    let value = "\(Date().timeIntervalSince1970) \(id)\n"
    try Data(value.utf8).write(to: marker, options: .atomic)
  }

  private static func printUsage() {
    print("""
    Usage: CodexThemeCreator --image PATH --id THEME_ID --name NAME [options]
      --author TEXT --description TEXT --category TEXT
      --appearance light|dark
      --accent #RRGGBB --secondary #RRGGBB --highlight #RRGGBB
      --focus 0..100 --replace --themes-root PATH
    """)
  }
}
