#!/usr/bin/env swift
//
//  generate_app_icon.swift
//  fitbod — BRU app icon generator
//
//  Generates the original BRU identity: a paper surface, ink training slab,
//  orange bracket and condensed wordmark. Vector drawing keeps this asset
//  reproducible without an image-generation dependency.
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

let paper = CGColor(colorSpace: colorSpace, components: [250 / 255.0, 250 / 255.0, 247 / 255.0, 1])!
let ink = CGColor(colorSpace: colorSpace, components: [10 / 255.0, 10 / 255.0, 10 / 255.0, 1])!
let signal = CGColor(colorSpace: colorSpace, components: [1, 92 / 255.0, 26 / 255.0, 1])!
ctx.setFillColor(paper)
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

// Deliberate square panel; iOS supplies the outer icon mask.
ctx.setFillColor(ink)
ctx.fill(CGRect(x: 108, y: 108, width: 808, height: 808))
ctx.setFillColor(signal)
ctx.fill(CGRect(x: 158, y: 202, width: 26, height: 620))
ctx.fill(CGRect(x: 158, y: 796, width: 120, height: 26))
ctx.fill(CGRect(x: 158, y: 202, width: 120, height: 26))

// Compact barbell motif above the wordmark; two plates per side.
ctx.setFillColor(paper)
ctx.fill(CGRect(x: 354, y: 692, width: 414, height: 24))
ctx.fill(CGRect(x: 358, y: 656, width: 24, height: 96))
ctx.fill(CGRect(x: 394, y: 636, width: 32, height: 136))
ctx.fill(CGRect(x: 696, y: 636, width: 32, height: 136))
ctx.fill(CGRect(x: 740, y: 656, width: 24, height: 96))

let fontURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("fitbod/Resources/Fonts/BebasNeue-Regular.ttf")
guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil) else {
    FileHandle.standardError.write(Data("Run from the repository root so the bundled Bebas Neue font is available.\n".utf8))
    exit(2)
}
let fontSize: CGFloat = 390
let font = CTFontCreateWithName("BebasNeue-Regular" as CFString, fontSize, nil)
let attrs: [CFString: Any] = [
    kCTFontAttributeName: font,
    kCTForegroundColorAttributeName: paper,
]
let attrString = CFAttributedStringCreate(
    kCFAllocatorDefault,
    "BRU" as CFString,
    attrs as CFDictionary
)!
let line = CTLineCreateWithAttributedString(attrString)

let bounds = CTLineGetBoundsWithOptions(line, [.useGlyphPathBounds])
let originX = 570 - bounds.width / 2 - bounds.origin.x
let originY = 400 - bounds.height / 2 - bounds.origin.y

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
