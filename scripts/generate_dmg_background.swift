#!/usr/bin/env swift
import AppKit

// Generate DMG background image with arrow pointing from app to Applications
let width: CGFloat = 660
let height: CGFloat = 440

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Light background gradient
let bgGradient = NSGradient(colors: [
    NSColor(red: 245/255, green: 245/255, blue: 247/255, alpha: 1),
    NSColor(red: 235/255, green: 235/255, blue: 240/255, alpha: 1),
])!
bgGradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

// Arrow settings
let arrowY: CGFloat = height / 2 + 15
let arrowStartX: CGFloat = 255
let arrowEndX: CGFloat = 405
let arrowColor = NSColor(white: 0.0, alpha: 0.18)

// Draw dashed arrow shaft
let shaft = NSBezierPath()
shaft.move(to: NSPoint(x: arrowStartX, y: arrowY))
shaft.line(to: NSPoint(x: arrowEndX - 10, y: arrowY))
arrowColor.setStroke()
shaft.lineWidth = 1.5
shaft.setLineDash([6, 5], count: 2, phase: 0)
shaft.lineCapStyle = .round
shaft.stroke()

// Draw arrow head (chevron ">")
let headSize: CGFloat = 7
let head = NSBezierPath()
head.move(to: NSPoint(x: arrowEndX - headSize, y: arrowY + headSize))
head.line(to: NSPoint(x: arrowEndX, y: arrowY))
head.line(to: NSPoint(x: arrowEndX - headSize, y: arrowY - headSize))
head.lineWidth = 1.5
head.lineCapStyle = .round
head.lineJoinStyle = .round
arrowColor.setStroke()
head.stroke()

// "Drag to install" text
let text = "Drag to Applications to install"
let textAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor(white: 0.0, alpha: 0.4),
]
let textSize = text.size(withAttributes: textAttrs)
let textX = (width - textSize.width) / 2
text.draw(at: NSPoint(x: textX, y: arrowY - 32), withAttributes: textAttrs)

// Gatekeeper note at bottom
let noteLines = [
    "If macOS blocks the app:",
    "System Settings \u{2192} Privacy & Security \u{2192} Scroll to Security \u{2192} Click \"Open Anyway\"",
]

for (i, line) in noteLines.enumerated() {
    let isHeader = i == 0
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: isHeader ? 11.5 : 11, weight: isHeader ? .medium : .regular),
        .foregroundColor: NSColor(white: 0.0, alpha: isHeader ? 0.4 : 0.25),
    ]
    let sz = line.size(withAttributes: attrs)
    let x = (width - sz.width) / 2
    let y: CGFloat = 70 - CGFloat(i) * 20
    line.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

image.unlockFocus()

// Save as PNG
guard let tiffData = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiffData),
      let pngData = rep.representation(using: .png, properties: [:]) else {
    print("Failed to generate background")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg_background.png"
try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Generated \(outputPath)")
