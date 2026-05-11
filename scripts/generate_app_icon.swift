#!/usr/bin/env swift
//
//  generate_app_icon.swift
//  fitbod — placeholder icon generator (Plan 01/00-02)
//
//  Generates a 1024x1024 PNG with a white capital "F" centered on the
//  AccentColor teal background (#0E7C86, sRGB 0.055/0.486/0.525).
//
//  Usage:
//      swift scripts/generate_app_icon.swift \
//          fitbod/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
//
//  Output PNG dimensions are validated separately via:
//      sips -g pixelWidth -g pixelHeight <path>
//

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: generate_app_icon.swift <output.png>\n".utf8))
    exit(1)
}
let outputPath = args[1]
let outputURL = URL(fileURLWithPath: outputPath)

let size: CGFloat = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    FileHandle.standardError.write(Data("failed to create CGContext\n".utf8))
    exit(2)
}

let accent = CGColor(colorSpace: colorSpace, components: [0.055, 0.486, 0.525, 1.0])!
ctx.setFillColor(accent)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

let fontSize: CGFloat = 640
let font = CTFontCreateWithName("SFProDisplay-Semibold" as CFString, fontSize, nil)
let white = CGColor(colorSpace: colorSpace, components: [1.0, 1.0, 1.0, 1.0])!
let attrs: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: white,
]
let attrString = CFAttributedStringCreate(
    kCFAllocatorDefault,
    "F" as CFString,
    attrs as CFDictionary
)!
let line = CTLineCreateWithAttributedString(attrString)

let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
let originX = (size - bounds.width) / 2.0 - bounds.origin.x
let originY = (size - bounds.height) / 2.0 - bounds.origin.y

ctx.textPosition = CGPoint(x: originX, y: originY)
CTLineDraw(line, ctx)

guard let cgImage = ctx.makeImage() else {
    FileHandle.standardError.write(Data("failed to make CGImage\n".utf8))
    exit(3)
}

guard let dest = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    FileHandle.standardError.write(Data("failed to create image destination\n".utf8))
    exit(4)
}

CGImageDestinationAddImage(dest, cgImage, nil)
guard CGImageDestinationFinalize(dest) else {
    FileHandle.standardError.write(Data("failed to finalize PNG\n".utf8))
    exit(5)
}

print("wrote \(outputPath) (\(Int(size))x\(Int(size)))")
