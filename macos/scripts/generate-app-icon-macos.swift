import AppKit

guard CommandLine.arguments.count == 2 else {
  fputs("Usage: generate-app-icon-macos.swift <output.png>\n", stderr)
  exit(2)
}

let pixels = 1024
guard let bitmap = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: pixels,
  pixelsHigh: pixels,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
) else {
  fputs("Could not allocate icon bitmap.\n", stderr)
  exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.shouldAntialias = true

let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
NSColor.clear.setFill()
canvas.fill()

let tile = NSRect(x: 72, y: 72, width: 880, height: 880)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 218, yRadius: 218)
let tileShadow = NSShadow()
tileShadow.shadowColor = NSColor(calibratedWhite: 0.04, alpha: 0.30)
tileShadow.shadowBlurRadius = 52
tileShadow.shadowOffset = NSSize(width: 0, height: -24)
tileShadow.set()
NSGradient(colors: [
  NSColor(red: 0.91, green: 0.28, blue: 0.22, alpha: 1),
  NSColor(red: 0.83, green: 0.43, blue: 0.18, alpha: 1),
  NSColor(red: 0.72, green: 0.53, blue: 0.15, alpha: 1),
])?.draw(in: tilePath, angle: -42)

NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
let sheen = NSRect(x: 72, y: 500, width: 880, height: 452)
NSGradient(colors: [
  NSColor.white.withAlphaComponent(0.24),
  NSColor.white.withAlphaComponent(0.0),
])?.draw(in: sheen, angle: -90)
NSGraphicsContext.restoreGraphicsState()

func roundedCard(_ rect: NSRect, color: NSColor, shadow: Bool) {
  let path = NSBezierPath(roundedRect: rect, xRadius: 76, yRadius: 76)
  if shadow {
    let cardShadow = NSShadow()
    cardShadow.shadowColor = NSColor(calibratedWhite: 0.08, alpha: 0.22)
    cardShadow.shadowBlurRadius = 34
    cardShadow.shadowOffset = NSSize(width: 0, height: -18)
    cardShadow.set()
  }
  color.setFill()
  path.fill()
}

roundedCard(
  NSRect(x: 244, y: 340, width: 468, height: 362),
  color: NSColor(red: 0.05, green: 0.54, blue: 0.49, alpha: 1),
  shadow: true
)
roundedCard(
  NSRect(x: 322, y: 246, width: 468, height: 362),
  color: NSColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 1),
  shadow: true
)

let rail = NSBezierPath(roundedRect: NSRect(x: 382, y: 515, width: 212, height: 28), xRadius: 14, yRadius: 14)
NSColor(red: 0.12, green: 0.16, blue: 0.17, alpha: 0.16).setFill()
rail.fill()

for (index, color) in [
  NSColor(red: 0.91, green: 0.28, blue: 0.22, alpha: 1),
  NSColor(red: 0.05, green: 0.54, blue: 0.49, alpha: 1),
  NSColor(red: 0.78, green: 0.57, blue: 0.17, alpha: 1),
].enumerated() {
  color.setFill()
  NSBezierPath(ovalIn: NSRect(x: 382 + CGFloat(index * 58), y: 298, width: 30, height: 30)).fill()
}

func sparkle(center: NSPoint, outer: CGFloat, inner: CGFloat) -> NSBezierPath {
  let points = [
    NSPoint(x: center.x, y: center.y + outer),
    NSPoint(x: center.x + inner, y: center.y + inner),
    NSPoint(x: center.x + outer, y: center.y),
    NSPoint(x: center.x + inner, y: center.y - inner),
    NSPoint(x: center.x, y: center.y - outer),
    NSPoint(x: center.x - inner, y: center.y - inner),
    NSPoint(x: center.x - outer, y: center.y),
    NSPoint(x: center.x - inner, y: center.y + inner),
  ]
  let path = NSBezierPath()
  path.move(to: points[0])
  for point in points.dropFirst() { path.line(to: point) }
  path.close()
  return path
}

NSColor(red: 0.91, green: 0.28, blue: 0.22, alpha: 1).setFill()
sparkle(center: NSPoint(x: 596, y: 430), outer: 108, inner: 28).fill()
NSColor(red: 0.78, green: 0.57, blue: 0.17, alpha: 1).setFill()
sparkle(center: NSPoint(x: 698, y: 500), outer: 38, inner: 11).fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = bitmap.representation(using: .png, properties: [:]) else {
  fputs("Could not encode icon PNG.\n", stderr)
  exit(1)
}
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
