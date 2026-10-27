// Draws the Proofer app icon and writes Resources/AppIcon.icns.
// Run: swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

func drawIcon() {
    // Tile on Apple's macOS grid: 824pt body, centred, continuous-ish corners.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0x2A2F8F).setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(colors: [color(0x6A4DF5), color(0x3B3FC9), color(0x1F2A78)],
               atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
        .draw(in: tile, angle: -70)
    // Soft highlight in the top-left for depth.
    NSGradient(colors: [.white.withAlphaComponent(0.2), .white.withAlphaComponent(0)])!
        .draw(fromCenter: NSPoint(x: 260, y: 900), radius: 0, toCenter: NSPoint(x: 260, y: 900), radius: 620, options: [])
    NSGraphicsContext.restoreGraphicsState()

    // Note sheet, tilted slightly.
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: 500, yBy: 520)
    transform.rotate(byDegrees: -6)
    transform.concat()

    let sheet = NSRect(x: -230, y: -290, width: 460, height: 580)
    let sheetPath = NSBezierPath(roundedRect: sheet, xRadius: 36, yRadius: 36)
    let sheetShadow = NSShadow()
    sheetShadow.shadowColor = .black.withAlphaComponent(0.4)
    sheetShadow.shadowBlurRadius = 30
    sheetShadow.shadowOffset = NSSize(width: 0, height: -16)
    NSGraphicsContext.saveGraphicsState()
    sheetShadow.set()
    color(0xFBFAF7).setFill()
    sheetPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Lines of "text".
    let lineColor = color(0xC9CBD6)
    let lines: [(y: CGFloat, width: CGFloat)] = [(200, 330), (120, 380), (40, 250), (-90, 360), (-170, 290)]
    for line in lines {
        lineColor.setFill()
        NSBezierPath(roundedRect: NSRect(x: -170, y: line.y, width: line.width, height: 34),
                     xRadius: 17, yRadius: 17).fill()
    }

    // Red spell-check squiggle under the third line.
    let squiggle = NSBezierPath()
    let startX: CGFloat = -170, endX: CGFloat = 80, baseY: CGFloat = 4, amp: CGFloat = 11, wave: CGFloat = 26
    squiggle.move(to: NSPoint(x: startX, y: baseY))
    var x = startX
    var up = true
    while x < endX {
        let next = min(x + wave, endX)
        squiggle.curve(to: NSPoint(x: next, y: baseY),
                       controlPoint1: NSPoint(x: x + wave * 0.5, y: baseY + (up ? amp : -amp) * 1.6),
                       controlPoint2: NSPoint(x: next - wave * 0.5, y: baseY + (up ? amp : -amp) * 1.6))
        x = next
        up.toggle()
    }
    squiggle.lineWidth = 12
    squiggle.lineCapStyle = .round
    color(0xF0445A).setStroke()
    squiggle.stroke()
    NSGraphicsContext.restoreGraphicsState()

    // Green check badge overlapping the sheet's bottom-right corner.
    let badge = NSRect(x: 590, y: 170, width: 270, height: 270)
    let badgePath = NSBezierPath(ovalIn: badge)
    NSGraphicsContext.saveGraphicsState()
    let badgeShadow = NSShadow()
    badgeShadow.shadowColor = .black.withAlphaComponent(0.35)
    badgeShadow.shadowBlurRadius = 24
    badgeShadow.shadowOffset = NSSize(width: 0, height: -10)
    badgeShadow.set()
    color(0x22C55E).setFill()
    badgePath.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.saveGraphicsState()
    badgePath.addClip()
    NSGradient(colors: [color(0x4ADE80), color(0x16A34A)])!.draw(in: badge, angle: -90)
    NSGraphicsContext.restoreGraphicsState()
    color(0xFFFFFF, 0.9).setStroke()
    badgePath.lineWidth = 10
    NSBezierPath(ovalIn: badge.insetBy(dx: 5, dy: 5)).stroke()

    let check = NSBezierPath()
    check.move(to: NSPoint(x: 660, y: 310))
    check.line(to: NSPoint(x: 712, y: 255))
    check.line(to: NSPoint(x: 800, y: 362))
    check.lineWidth = 34
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    NSColor.white.setStroke()
    check.stroke()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let resources = root.appendingPathComponent("Resources")
try fm.createDirectory(at: resources, withIntermediateDirectories: true)
try png(pixels: 1024).write(to: resources.appendingPathComponent("AppIcon.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
