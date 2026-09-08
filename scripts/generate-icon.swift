#!/usr/bin/env swift
import AppKit
import Foundation

let size = 1024.0
let dest = URL(fileURLWithPath: CommandLine.argc > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath
        + "/Qota/Assets.xcassets/AppIcon.appiconset/AppIcon.png")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let bg = color(26 / 255, 29 / 255, 36 / 255)
let track = color(54 / 255, 59 / 255, 70 / 255)
let teal = color(45 / 255, 201 / 255, 176 / 255)
let amber = color(240 / 255, 163 / 255, 58 / 255)
let coral = color(232 / 255, 108 / 255, 116 / 255)
let badgeFill = color(20 / 255, 46 / 255, 44 / 255)

func capsule(_ rect: CGRect) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2)
}

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
bg.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

let barH: CGFloat = 96
let gap: CGFloat = 42
let barW: CGFloat = 548
let left: CGFloat = 118
let groupH = barH * 3 + gap * 2
let top = (size - groupH) / 2
let fills: [(NSColor, CGFloat)] = [(teal, 0.70), (amber, 0.46), (coral, 0.84)]

for (i, item) in fills.enumerated() {
    let y = size - top - CGFloat(i + 1) * barH - CGFloat(i) * gap
    track.setFill()
    capsule(CGRect(x: left, y: y, width: barW, height: barH)).fill()
    item.0.setFill()
    capsule(CGRect(x: left, y: y, width: max(barH, barW * item.1), height: barH)).fill()
}

let cx: CGFloat = 778
let cy: CGFloat = size - 548
let r: CGFloat = 168
teal.setFill()
NSBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
badgeFill.setFill()
let inner = r - 26
NSBezierPath(ovalIn: CGRect(x: cx - inner, y: cy - inner, width: inner * 2, height: inner * 2)).fill()

let check = NSBezierPath()
check.lineWidth = 46
check.lineCapStyle = .round
check.lineJoinStyle = .round
check.move(to: NSPoint(x: cx - 78, y: cy - 8))
check.line(to: NSPoint(x: cx - 18, y: cy - 68))
check.line(to: NSPoint(x: cx + 86, y: cy + 58))
teal.setStroke()
check.stroke()

image.unlockFocus()

try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode AppIcon.png\n", stderr)
    exit(1)
}
try png.write(to: dest)
fputs("wrote \(dest.path)\n", stderr)
