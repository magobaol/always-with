#!/usr/bin/env swift

import AppKit
import CoreGraphics

let bgTop    = NSColor(srgbRed: 0.42, green: 0.22, blue: 0.88, alpha: 1)
let bgBottom = NSColor(srgbRed: 0.20, green: 0.50, blue: 0.97, alpha: 1)
let wandDark = NSColor(srgbRed: 0.18, green: 0.12, blue: 0.30, alpha: 1)
let goldTip  = NSColor(srgbRed: 1.00, green: 0.82, blue: 0.30, alpha: 1)
let goldStar = NSColor(srgbRed: 1.00, green: 0.92, blue: 0.55, alpha: 1)
let sparkleC = NSColor.white.withAlphaComponent(0.92)
let textFill = NSColor(srgbRed: 0.13, green: 0.13, blue: 0.22, alpha: 1)
let appPalette: [NSColor] = [
    NSColor(srgbRed: 1.00, green: 0.66, blue: 0.18, alpha: 1),
    NSColor(srgbRed: 0.95, green: 0.30, blue: 0.45, alpha: 1),
    NSColor(srgbRed: 0.25, green: 0.82, blue: 0.62, alpha: 1),
    NSColor(srgbRed: 0.95, green: 0.85, blue: 0.30, alpha: 1),
    NSColor(srgbRed: 0.40, green: 0.65, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.78, green: 0.45, blue: 1.00, alpha: 1),
]

func newContext(_ pixelSize: Int) -> (CGContext, NSGraphicsContext) {
    let bytesPerRow = pixelSize * 4
    guard let cgContext = CGContext(
        data: nil, width: pixelSize, height: pixelSize,
        bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError() }
    let nsCtx = NSGraphicsContext(cgContext: cgContext, flipped: false)
    return (cgContext, nsCtx)
}

func encodePNG(_ cg: CGContext) -> Data {
    let cgImage = cg.makeImage()!
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:])!
}

func drawBackground(in rect: NSRect) {
    let cornerRadius = rect.width * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(colors: [bgTop, bgBottom])!.draw(in: rect, angle: -45)
    NSGraphicsContext.restoreGraphicsState()
}

func drawStar(at center: NSPoint, outerRadius: CGFloat, innerRadius: CGFloat, points: Int = 4, color: NSColor, rotation: CGFloat = 0) {
    let path = NSBezierPath()
    let total = points * 2
    for index in 0..<total {
        let angle = (CGFloat(index) / CGFloat(total)) * 2 * .pi + rotation - .pi / 2
        let r = index % 2 == 0 ? outerRadius : innerRadius
        let x = center.x + cos(angle) * r
        let y = center.y + sin(angle) * r
        if index == 0 { path.move(to: NSPoint(x: x, y: y)) }
        else { path.line(to: NSPoint(x: x, y: y)) }
    }
    path.close()
    color.setFill()
    path.fill()
}

func drawWand(from start: NSPoint, to end: NSPoint, in art: NSRect) {
    let strokeWidth = art.width * 0.038
    let dx = end.x - start.x
    let dy = end.y - start.y
    let len = sqrt(dx * dx + dy * dy)
    let ux = dx / len, uy = dy / len
    let tipLen = len * 0.30
    let tipStart = NSPoint(x: end.x - ux * tipLen, y: end.y - uy * tipLen)

    // Shaft (dark)
    let shaft = NSBezierPath()
    shaft.move(to: start)
    shaft.line(to: tipStart)
    shaft.lineWidth = strokeWidth
    shaft.lineCapStyle = .round
    wandDark.setStroke()
    shaft.stroke()

    // Gold tip
    let tip = NSBezierPath()
    tip.move(to: tipStart)
    tip.line(to: end)
    tip.lineWidth = strokeWidth
    tip.lineCapStyle = .round
    goldTip.setStroke()
    tip.stroke()

    // Star burst at end
    drawStar(
        at: NSPoint(x: end.x + ux * art.width * 0.02, y: end.y + uy * art.width * 0.02),
        outerRadius: art.width * 0.12,
        innerRadius: art.width * 0.035,
        points: 4,
        color: goldStar
    )
}

func drawCenteredText(_ text: String, in rect: NSRect, font: NSFont, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: text, attributes: attrs)
    let measured = attributed.size()
    let textRect = NSRect(
        x: rect.minX, y: rect.minY + (rect.height - measured.height) / 2,
        width: rect.width, height: measured.height
    )
    attributed.draw(in: textRect)
}

// E — Wand only with scattered sparkles
func renderVariantE(pixelSize: Int) -> Data {
    let (cg, ns) = newContext(pixelSize)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let canvas = CGFloat(pixelSize)
    let inset = canvas * 0.0977
    let art = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    drawBackground(in: art)

    let wandStart = NSPoint(x: art.minX + art.width * 0.18, y: art.minY + art.height * 0.20)
    let wandEnd   = NSPoint(x: art.maxX - art.width * 0.28, y: art.maxY - art.height * 0.30)
    drawWand(from: wandStart, to: wandEnd, in: art)

    let sparkles: [(CGFloat, CGFloat, CGFloat)] = [
        (art.minX + art.width * 0.50, art.maxY - art.height * 0.82, art.width * 0.050),
        (art.minX + art.width * 0.20, art.maxY - art.height * 0.50, art.width * 0.032),
        (art.minX + art.width * 0.82, art.minY + art.height * 0.30, art.width * 0.045),
        (art.minX + art.width * 0.42, art.minY + art.height * 0.18, art.width * 0.028),
    ]
    for (x, y, r) in sparkles {
        drawStar(at: NSPoint(x: x, y: y), outerRadius: r, innerRadius: r * 0.32, points: 4, color: sparkleC)
    }

    NSGraphicsContext.restoreGraphicsState()
    return encodePNG(cg)
}

// F — Wand touching .ff tile
func renderVariantF(pixelSize: Int) -> Data {
    let (cg, ns) = newContext(pixelSize)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let canvas = CGFloat(pixelSize)
    let inset = canvas * 0.0977
    let art = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    drawBackground(in: art)

    // Tile .ff in lower-left
    let tileSize = art.width * 0.50
    let tileRect = NSRect(
        x: art.minX + art.width * 0.08,
        y: art.minY + art.height * 0.08,
        width: tileSize, height: tileSize
    )
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: tileSize * 0.18, yRadius: tileSize * 0.18)
    NSColor.white.setFill(); tilePath.fill()
    let font = NSFont.monospacedSystemFont(ofSize: tileSize * 0.42, weight: .bold)
    drawCenteredText(".ff", in: tileRect, font: font, color: textFill)

    // Wand from upper-right to tile corner
    let wandStart = NSPoint(x: art.maxX - art.width * 0.08, y: art.maxY - art.height * 0.10)
    let wandEnd   = NSPoint(x: tileRect.maxX - art.width * 0.04, y: tileRect.maxY + art.width * 0.04)
    drawWand(from: wandStart, to: wandEnd, in: art)

    // A couple of sparkles
    drawStar(at: NSPoint(x: art.midX, y: art.maxY - art.height * 0.20), outerRadius: art.width * 0.032, innerRadius: art.width * 0.011, points: 4, color: sparkleC)
    drawStar(at: NSPoint(x: art.maxX - art.width * 0.36, y: art.maxY - art.height * 0.38), outerRadius: art.width * 0.024, innerRadius: art.width * 0.008, points: 4, color: sparkleC)

    NSGraphicsContext.restoreGraphicsState()
    return encodePNG(cg)
}

// G — Big rounded tile .ff, minimal
func renderVariantG(pixelSize: Int) -> Data {
    let (cg, ns) = newContext(pixelSize)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let canvas = CGFloat(pixelSize)
    let inset = canvas * 0.0977
    let art = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    drawBackground(in: art)

    let tileSize = art.width * 0.66
    let tileRect = NSRect(
        x: art.midX - tileSize / 2,
        y: art.midY - tileSize / 2,
        width: tileSize, height: tileSize
    )
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: tileSize * 0.20, yRadius: tileSize * 0.20)
    NSColor.white.setFill(); tilePath.fill()
    let font = NSFont.monospacedSystemFont(ofSize: tileSize * 0.45, weight: .bold)
    drawCenteredText(".ff", in: tileRect, font: font, color: textFill)

    NSGraphicsContext.restoreGraphicsState()
    return encodePNG(cg)
}

// H — .ff tile in center, ring of colored app dots around it, one highlighted (bigger)
func renderVariantH(pixelSize: Int) -> Data {
    let (cg, ns) = newContext(pixelSize)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let canvas = CGFloat(pixelSize)
    let inset = canvas * 0.0977
    let art = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    drawBackground(in: art)

    // Central .ff tile
    let tileSize = art.width * 0.36
    let tileRect = NSRect(
        x: art.midX - tileSize / 2,
        y: art.midY - tileSize / 2,
        width: tileSize, height: tileSize
    )
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: tileSize * 0.22, yRadius: tileSize * 0.22)
    NSColor.white.setFill(); tilePath.fill()
    let font = NSFont.monospacedSystemFont(ofSize: tileSize * 0.46, weight: .bold)
    drawCenteredText(".ff", in: tileRect, font: font, color: textFill)

    // Ring of 6 app dots
    let ringRadius = art.width * 0.34
    let dotBase = art.width * 0.10
    let activeIndex = 1
    for index in 0..<6 {
        let angle = (CGFloat(index) / 6.0) * 2 * .pi - .pi / 2
        let cx = art.midX + cos(angle) * ringRadius
        let cy = art.midY + sin(angle) * ringRadius
        let isActive = index == activeIndex
        let size = isActive ? dotBase * 1.25 : dotBase
        let rect = NSRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.25, yRadius: size * 0.25)
        let color = isActive ? appPalette[index] : appPalette[index].withAlphaComponent(0.55)
        color.setFill()
        path.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return encodePNG(cg)
}

let outputDir = URL(fileURLWithPath: NSString(string: "~/Downloads/ff-icon-mockups").expandingTildeInPath)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

// Wipe previous mockups
if let existing = try? FileManager.default.contentsOfDirectory(at: outputDir, includingPropertiesForKeys: nil) {
    for url in existing where url.pathExtension == "png" {
        try? FileManager.default.removeItem(at: url)
    }
}

let variants: [(String, (Int) -> Data)] = [
    ("E_wand_only",        renderVariantE),
    ("F_wand_taps_ff",     renderVariantF),
    ("G_tile_ff_minimal",  renderVariantG),
    ("H_ff_ring_of_apps",  renderVariantH),
]
for (name, render) in variants {
    let data = render(1024)
    let url = outputDir.appendingPathComponent("\(name).png")
    try! data.write(to: url)
    print("wrote \(url.path)")
}
