import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CreateThemeView: View {
  @ObservedObject var store: ThemeStore
  @Environment(\.dismiss) private var dismiss

  @State private var imageURL: URL?
  @State private var image: NSImage?
  @State private var name = ""
  @State private var themeID = ""
  @State private var author = ""
  @State private var themeDescription = ""
  @State private var category = "自定义"
  @State private var appearance = "dark"
  @State private var accent = Color(red: 0.31, green: 0.64, blue: 0.91)
  @State private var secondary = Color(red: 0.44, green: 0.78, blue: 0.70)
  @State private var highlight = Color(red: 0.91, green: 0.60, blue: 0.36)
  @State private var focusX = 0.5
  @State private var idWasEdited = false
  @State private var errorMessage: String?
  @State private var isCreating = false

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("创建主题")
            .font(.system(size: 22, weight: .bold))
          Text("生成标准 schema 2 主题包")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button(action: dismiss.callAsFunction) {
          Image(systemName: "xmark")
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help("关闭")
      }
      .padding(.horizontal, 26)
      .frame(height: 72)

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 22) {
          imagePicker

          HStack(alignment: .top, spacing: 26) {
            VStack(alignment: .leading, spacing: 15) {
              field("主题名称") {
                TextField("例如：晴空工作室", text: $name)
                  .onChange(of: name) { _, newValue in
                    if !idWasEdited {
                      themeID = ThemePackageService.suggestedID(for: newValue)
                    }
                  }
              }
              field("主题 ID") {
                TextField("lowercase-theme-id", text: Binding(
                  get: { themeID },
                  set: {
                    themeID = $0
                    idWasEdited = true
                  }
                ))
              }
              field("作者") {
                TextField("可选", text: $author)
              }
              field("描述") {
                TextField("一句话描述这套主题", text: $themeDescription)
              }
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 15) {
              field("分类") {
                Picker("", selection: $category) {
                  ForEach(["自定义", "动漫", "角色", "清新", "暗色", "极简"], id: \.self) {
                    Text($0)
                  }
                }
                .labelsHidden()
              }
              field("界面模式") {
                Picker("", selection: $appearance) {
                  Text("浅色").tag("light")
                  Text("暗色").tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
              }
              HStack(spacing: 18) {
                colorField("强调色", color: $accent)
                colorField("辅助色", color: $secondary)
                colorField("点缀色", color: $highlight)
              }
            }
            .frame(maxWidth: .infinity)
          }

          if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
              .font(.system(size: 12))
              .foregroundStyle(.red)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .padding(26)
      }

      Divider()

      HStack {
        Text("输出：background.png · preview.png · theme.json")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
        Spacer()
        Button("取消", action: dismiss.callAsFunction)
          .keyboardShortcut(.cancelAction)
        Button(action: createTheme) {
          HStack(spacing: 7) {
            if isCreating {
              ProgressView().controlSize(.small)
            } else {
              Image(systemName: "sparkles")
            }
            Text(isCreating ? "正在创建…" : "创建主题")
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(StudioPalette.accent)
        .keyboardShortcut(.defaultAction)
        .disabled(isCreating || imageURL == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding(.horizontal, 26)
      .frame(height: 68)
    }
    .frame(width: 860, height: 760)
    .background(StudioPalette.canvas)
  }

  private var imagePicker: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("背景图片")
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        Button(image == nil ? "选择图片" : "更换图片", systemImage: "photo.badge.plus", action: chooseImage)
          .buttonStyle(.bordered)
      }

      Group {
        if let image {
          FocalImagePreview(image: image, horizontalFocus: focusX)
        } else {
          ZStack {
            StudioPalette.surface
            VStack(spacing: 10) {
              Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(StudioPalette.muted)
              Text("3:1 主题预览")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(StudioPalette.muted)
            }
          }
        }
      }
      .aspectRatio(3, contentMode: .fit)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(StudioPalette.line))

      if image != nil {
        HStack(spacing: 12) {
          Image(systemName: "arrow.left")
          Slider(value: $focusX, in: 0...1)
          Image(systemName: "arrow.right")
          Button("居中") { focusX = 0.5 }
            .buttonStyle(.plain)
            .foregroundStyle(StudioPalette.accent)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(StudioPalette.muted)
      }
    }
  }

  private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(StudioPalette.muted)
      content()
        .textFieldStyle(.roundedBorder)
    }
  }

  private func colorField(_ title: String, color: Binding<Color>) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(StudioPalette.muted)
      ColorPicker("", selection: color, supportsOpacity: false)
        .labelsHidden()
        .frame(width: 42, height: 28)
    }
  }

  private func chooseImage() {
    let panel = NSOpenPanel()
    panel.title = "选择主题背景"
    panel.prompt = "选择"
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.image]
    guard panel.runModal() == .OK, let url = panel.url, let selected = NSImage(contentsOf: url) else {
      return
    }
    imageURL = url
    image = selected
    errorMessage = nil
  }

  private func createTheme() {
    guard let imageURL else { return }
    let id = themeID.trimmingCharacters(in: .whitespacesAndNewlines)
    let replacing = store.themes.contains(where: { $0.id == id })
    if replacing {
      guard !BuiltinThemeCatalog.ids.contains(id) else {
        errorMessage = "内置主题 ID 受保护，请使用新的主题 ID"
        return
      }
      let alert = NSAlert()
      alert.messageText = "替换现有主题？"
      alert.informativeText = "主题 ID “\(id)”已经存在，继续会替换原主题包。"
      alert.alertStyle = .warning
      alert.addButton(withTitle: "替换")
      alert.addButton(withTitle: "取消")
      guard alert.runModal() == .alertFirstButtonReturn else { return }
    }

    let draft = ThemeDraft(
      sourceImageURL: imageURL,
      id: id,
      name: name,
      author: author,
      description: themeDescription,
      category: category,
      appearance: appearance,
      accent: colorHex(accent),
      secondary: colorHex(secondary),
      highlight: colorHex(highlight),
      focusX: focusX
    )
    isCreating = true
    errorMessage = nil
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try ThemePackageService.create(draft: draft, in: store.themesRoot, replacing: replacing)
        DispatchQueue.main.async {
          store.reload()
          store.status = "已创建“\(draft.name)”"
          isCreating = false
          dismiss()
        }
      } catch {
        DispatchQueue.main.async {
          isCreating = false
          errorMessage = error.localizedDescription
        }
      }
    }
  }

  private func colorHex(_ color: Color) -> String {
    guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return "#5CA3E6" }
    let red = min(max(converted.redComponent, 0), 1)
    let green = min(max(converted.greenComponent, 0), 1)
    let blue = min(max(converted.blueComponent, 0), 1)
    return String(
      format: "#%02X%02X%02X",
      Int(round(red * 255)),
      Int(round(green * 255)),
      Int(round(blue * 255))
    )
  }
}

private struct FocalImagePreview: View {
  let image: NSImage
  let horizontalFocus: Double

  var body: some View {
    GeometryReader { proxy in
      let container = proxy.size
      let source = image.size
      let scale = max(container.width / source.width, container.height / source.height)
      let renderedWidth = source.width * scale
      let renderedHeight = source.height * scale
      Image(nsImage: image)
        .resizable()
        .frame(width: renderedWidth, height: renderedHeight)
        .offset(
          x: (container.width - renderedWidth) * horizontalFocus,
          y: (container.height - renderedHeight) / 2
        )
    }
    .clipped()
  }
}
