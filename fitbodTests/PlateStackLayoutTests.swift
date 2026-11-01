// PlateStackLayoutTests.swift
// fitbodTests
//
// Ticket T107, finding F200. In the per-side plate stack, no plate covers
// another plate's label: with a 137.5 lb target the 1.25 plate drew over part
// of the 45's "45". A plate's ZStack took its label's unrotated width, so the
// plate's fill stretched over its neighbor; and a rotated label is as wide as
// its digits are tall, wider than the 8pt plates at any text size and than a
// 45 lb plate at AX3. PlateStackViz.Geometry places the plates and the labels'
// ink the way the view draws them, with the real label font, and the view
// draws a plate the same whatever sits beside it.

import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import fitbod

struct PlateStackLayoutTests {

    /// The label's point size at default text, XXXL and AX3: its 12pt
    /// grows like `.caption`.
    static let labelSizes: [CGFloat] = [12, 18, 32]

    /// The calculator's full-size stack and the logger's.
    static let scales: [CGFloat] = [1, 0.6]

    /// 137.5 lb on a 45 lb bar, every lb plate, and every kg plate.
    static let stacks: [[PlateStackViz.PlateDenomination]] = [
        [(45, 1), (1.25, 1)],
        [(45, 2), (35, 1), (25, 1), (10, 1), (5, 1), (2.5, 1), (1.25, 1)],
        [(25, 2), (20, 1), (15, 1), (10, 1), (5, 1), (2.5, 1), (1.25, 1)],
    ]

    /// The renders' pixels per point.
    static let renderScale: CGFloat = 3

    @Test("No label spills out of its plate onto another", arguments: labelSizes, scales)
    func noLabelSpillsOntoAnotherPlate(labelSize: CGFloat, scale: CGFloat) {
        var problems: [String] = []
        for stack in Self.stacks {
            let plates = PlateStackViz.Geometry(platesPerSide: stack, heightScale: scale, labelPointSize: labelSize).plates
            for (index, plate) in plates.enumerated() {
                guard let label = plate.label else { continue }
                let name = "the \(Self.formatted(plate.weight)) plate's label"
                // A neighbor's 1pt separator draws its outer half over a
                // plate's edge.
                if !plate.frame.insetBy(dx: 0.5, dy: 0.5).contains(label) {
                    problems.append("\(name) spills out of its plate: label \(label), plate \(plate.frame)")
                }
                for (otherIndex, other) in plates.enumerated() where otherIndex != index {
                    if Self.overlap(label, other.frame) {
                        problems.append("\(name) and the \(Self.formatted(other.weight)) plate overlap")
                    }
                }
            }
        }
        #expect(problems.isEmpty, "At \(labelSize)pt labels and scale \(scale): \(problems)")
    }

    /// At default text the calculator's 45, 35 and 25 lb plates are wide
    /// enough for their labels; the 8pt plates are not.
    @Test("A label shows wherever it fits")
    func labelsShowWhereTheyFit() {
        let plates = PlateStackViz.Geometry(platesPerSide: Self.stacks[1], heightScale: 1, labelPointSize: 12).plates
        #expect(plates.filter { $0.label != nil }.map(\.weight) == [45, 45, 35, 25])
    }

    /// The 45 lb plate, its label included, draws the same with the 1.25
    /// beside it, 137.5 lb on a 45 lb bar, as alone. Its right edge is left
    /// out: the next plate's 1pt separator draws its outer half there.
    @MainActor // ImageRenderer renders on the main actor.
    @Test("A plate's neighbor never draws over it",
          arguments: [DynamicTypeSize.large, .xxxLarge, .accessibility3], scales)
    func neighborNeverDrawsOverAPlate(textSize: DynamicTypeSize, scale: CGFloat) throws {
        let alone = try #require(Self.render([(45, 1)], scale: scale, textSize: textSize))
        let paired = try #require(Self.render([(45, 1), (1.25, 1)], scale: scale, textSize: textSize))
        #expect(alone.height == paired.height)
        // The plates start after the 30pt sleeve and the stack's 2pt
        // spacing. Only whole pixels inside the plate count.
        let left = ((30 * scale + 2) * Self.renderScale).rounded(.up)
        let right = ((30 * scale + 2 + 18 * scale - 0.5) * Self.renderScale).rounded(.down)
        let pixels = CGRect(x: left, y: 0, width: right - left, height: CGFloat(alone.height))
        let drawnAlone = try #require(Self.bytes(of: alone, in: pixels))
        let drawnPaired = try #require(Self.bytes(of: paired, in: pixels))
        let changed = zip(drawnAlone, drawnPaired).filter { $0 != $1 }.count
        #expect(changed == 0, "At \(textSize) and scale \(scale) the 1.25 changes \(changed / 4) of the 45 plate's pixels")
    }

    // MARK: - Helpers

    /// Rectangles that share more than a sliver of area.
    private static func overlap(_ a: CGRect, _ b: CGRect) -> Bool {
        let shared = a.intersection(b)
        return !shared.isNull && shared.width > 0.01 && shared.height > 0.01
    }

    private static func formatted(_ weight: Double) -> String {
        String(format: "%g", weight)
    }

    /// The stack without its legend, at `textSize`.
    @MainActor
    private static func render(
        _ plates: [PlateStackViz.PlateDenomination], scale: CGFloat, textSize: DynamicTypeSize
    ) -> CGImage? {
        let renderer = ImageRenderer(content: PlateStackViz(
            platesPerSide: plates, barLabel: "45 lb", heightScale: scale, showLegend: false
        ).environment(\.dynamicTypeSize, textSize))
        renderer.scale = renderScale
        return renderer.cgImage
    }

    /// The sRGB bytes of `rect`, in pixels, of `image`: four to a pixel, row
    /// by row from the top.
    private static func bytes(of image: CGImage, in rect: CGRect) -> [UInt8]? {
        guard let cut = image.cropping(to: rect), let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: cut.width * cut.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: cut.width, height: cut.height, bitsPerComponent: 8,
                bytesPerRow: cut.width * 4, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cut, in: CGRect(x: 0, y: 0, width: cut.width, height: cut.height))
            return true
        }
        return drawn ? bytes : nil
    }
}
