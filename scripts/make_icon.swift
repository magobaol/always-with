#!/usr/bin/env swift

import AppKit
import CoreGraphics

let bgTop    = NSColor(srgbRed: 0.42, green: 0.22, blue: 0.88, alpha: 1)
let bgBottom = NSColor(srgbRed: 0.20, green: 0.50, blue: 0.97, alpha: 1)
let textFill = NSColor(srgbRed: 0.13, green: 0.13, blue: 0.22, alpha: 1)
let appPalette: [NSColor] = [
    NSColor(srgbRed: 1.00, green: 0.66, blue: 0.18, alpha: 1),
    NSColor(srgbRed: 0.95, green: 0.30, blue: 0.45, alpha: 1),
    NSColor(srgbRed: 0.25, green: 0.82, blue: 0.62, alpha: 1),
    NSColor(srgbRed: 0.95, green: 0.85, blue: 0.30, alpha: 1),
    NSColor(srgbRed: 0.40, green: 0.65, blue: 1.00, alpha: 1),
    NSColor(srgbRed: 0.78, green: 0.45, blue: 1.00, alpha: 1),
]
let activeAppIndex = 1

func renderIcon(pixelSize: Int) -> Data {
    let canvas = CGFloat(pixelSize)
    let bytesPerRow = pixelSize * 4
    guard let cgContext = CGContext(
        data: nil, width: pixelSize, height: pixelSize,
        bitsPerComponent: 8, bytesPerRow: bytesPerRow,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("CGContext failed") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)

    // macOS production icon grid: art inscribed in 824x824 of 1024x1024 canvas.
    let artInset = canvas * 0.0977
    let artSize = canvas - 2 * artInset
    let art = NSRect(x: artInset, y: artInset, width: artSize, height: artSize)

    // Background
    let cornerRadius = artSize * 0.22
    let bgPath = NSBezierPath(roundedRect: art, xRadius: cornerRadius, yRadius: cornerRadius)
    NSGraphicsContext.saveGraphicsState()
    bgPath.addClip()
    NSGradient(colors: [bgTop, bgBottom])!.draw(in: art, angle: -45)
    NSGraphicsContext.restoreGraphicsState()

    // Central .ff tile
    let tileSize = artSize * 0.36
    let tileRect = NSRect(
        x: art.midX - tileSize / 2,
        y: art.midY - tileSize / 2,
        width: tileSize, height: tileSize
    )
    let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: tileSize * 0.22, yRadius: tileSize * 0.22)
    NSColor.white.setFill()
    tilePath.fill()

    let font = NSFont.monospacedSystemFont(ofSize: tileSize * 0.46, weight: .bold)
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font, .foregroundColor: textFill, .paragraphStyle: paragraph,
    ]
    let attributed = NSAttributedString(string: ".ff", attributes: attrs)
    let measured = attributed.size()
    let textRect = NSRect(
        x: tileRect.minX, y: tileRect.minY + (tileRect.height - measured.height) / 2,
        width: tileRect.width, height: measured.height
    )
    attributed.draw(in: textRect)

    // Ring of 6 app dots, one active (larger + opaque)
    let ringRadius = artSize * 0.34
    let dotBase = artSize * 0.10
    for index in 0..<6 {
        let angle = (CGFloat(index) / 6.0) * 2 * .pi - .pi / 2
        let cx = art.midX + cos(angle) * ringRadius
        let cy = art.midY + sin(angle) * ringRadius
        let isActive = index == activeAppIndex
        let size = isActive ? dotBase * 1.25 : dotBase
        let rect = NSRect(x: cx - size / 2, y: cy - size / 2, width: size, height: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.25, yRadius: size * 0.25)
        let color = isActive ? appPalette[index] : appPalette[index].withAlphaComponent(0.55)
        color.setFill()
        path.fill()
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = cgContext.makeImage() else { fatalError("makeImage failed") }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png encode failed") }
    return data
}

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write("usage: make_icon.swift <output_dir>\n".data(using: .utf8)!)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

let outputs: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (pixelSize, filename) in outputs {
    let data = renderIcon(pixelSize: pixelSize)
    let url = outputDir.appendingPathComponent(filename)
    try! data.write(to: url)
    print("wrote \(filename) (\(pixelSize)x\(pixelSize))")
}
