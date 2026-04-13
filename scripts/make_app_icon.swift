#!/usr/bin/env swift
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("usage: make_app_icon.swift <source.png> <output.png>\n", stderr)
    exit(1)
}

let srcPath = arguments[1]
let dstPath = arguments[2]

guard let image = NSImage(contentsOfFile: srcPath) else {
    fputs("failed to load image\n", stderr)
    exit(1)
}

guard let srcRep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first else {
    fputs("no bitmap representation\n", stderr)
    exit(1)
}

let sw = srcRep.pixelsWide
let sh = srcRep.pixelsHigh
let canvas = 1024
let x = (canvas - sw) / 2

guard let destRep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("failed to create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: destRep)
NSColor.white.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: canvas, height: canvas)).fill()
image.draw(
    in: NSRect(x: x, y: 0, width: sw, height: sh),
    from: NSRect.zero,
    operation: .copy,
    fraction: 1.0
)
NSGraphicsContext.restoreGraphicsState()

guard let png = destRep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode PNG\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: dstPath))
} catch {
    fputs("\(error)\n", stderr)
    exit(1)
}
