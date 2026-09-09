/*
 Artifact-Version: 2.0.0
 Release-Date: 2026-09-06
 Stability: Stable
 Change-Summary: Rename the deterministic icon generator for OLK2MBOX 2.0.0.
 SPDX-FileCopyrightText: 2026 igp76
 SPDX-License-Identifier: GPL-3.0-or-later
 */

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: GenerateOLK2MBOXIcon.swift OUTPUT_ICONSET\n".utf8))
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

let specifications: [(points: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

func drawIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "OLK2MBOX.Icon", code: 1)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let size = CGFloat(pixels)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let background = NSBezierPath(
        roundedRect: NSRect(x: size * 0.04, y: size * 0.04, width: size * 0.92, height: size * 0.92),
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.10, green: 0.48, blue: 0.96, alpha: 1),
            NSColor(calibratedRed: 0.23, green: 0.16, blue: 0.65, alpha: 1),
        ]
    )
    gradient?.draw(in: background, angle: -55)

    let envelopeRect = NSRect(
        x: size * 0.17,
        y: size * 0.27,
        width: size * 0.66,
        height: size * 0.46
    )
    let envelope = NSBezierPath(
        roundedRect: envelopeRect,
        xRadius: size * 0.055,
        yRadius: size * 0.055
    )
    NSColor.white.withAlphaComponent(0.96).setFill()
    envelope.fill()

    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: envelopeRect.minX + size * 0.03, y: envelopeRect.maxY - size * 0.035))
    fold.line(to: NSPoint(x: envelopeRect.midX, y: envelopeRect.midY - size * 0.015))
    fold.line(to: NSPoint(x: envelopeRect.maxX - size * 0.03, y: envelopeRect.maxY - size * 0.035))
    fold.lineWidth = max(1, size * 0.025)
    fold.lineCapStyle = .round
    fold.lineJoinStyle = .round
    NSColor(calibratedRed: 0.16, green: 0.35, blue: 0.75, alpha: 0.78).setStroke()
    fold.stroke()

    let badgeRect = NSRect(x: size * 0.58, y: size * 0.12, width: size * 0.30, height: size * 0.30)
    NSColor(calibratedRed: 0.20, green: 0.76, blue: 0.48, alpha: 1).setFill()
    NSBezierPath(ovalIn: badgeRect).fill()

    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: badgeRect.minX + size * 0.075, y: badgeRect.midY + size * 0.015))
    arrow.line(to: NSPoint(x: badgeRect.midX - size * 0.01, y: badgeRect.minY + size * 0.075))
    arrow.line(to: NSPoint(x: badgeRect.maxX - size * 0.065, y: badgeRect.maxY - size * 0.065))
    arrow.lineWidth = max(1, size * 0.032)
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    NSColor.white.setStroke()
    arrow.stroke()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "OLK2MBOX.Icon", code: 2)
    }
    return data
}

for specification in specifications {
    let pixels = specification.points * specification.scale
    let suffix = specification.scale == 2 ? "@2x" : ""
    let filename = "icon_\(specification.points)x\(specification.points)\(suffix).png"
    try drawIcon(pixels: pixels).write(to: outputDirectory.appendingPathComponent(filename))
}
