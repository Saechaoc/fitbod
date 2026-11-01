//
//  BlockReviewHeroLayoutTests.swift
//  fitbodTests
//
//  Ticket T113, finding F237. A TONNAGE of 1,000,000 or more wrapped inside
//  the number on the 390pt phone. The hero's values now shrink to fit on
//  one line, and a value that fits keeps its full size.
//
//  Each test shows the review in a window the small phone's width at one
//  text size and measures TONNAGE on the screen, by the lines Vision reads
//  and by its pixels: the hosted accessibility tree builds only when an
//  earlier test built one (F315).
//

import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
import Vision
@testable import fitbod

/// Main actor, as it shows the review in a UIKit window.
@MainActor
@Suite("BlockReviewHeroLayout")
struct BlockReviewHeroLayoutTests {
    private let started = Date(timeIntervalSince1970: 1_780_000_000)

    /// XXXL leaves TONNAGE the least room in the row, about 160pt beside
    /// the tracked labels, and AX5 the least in the stack.
    @Test("an eight-digit TONNAGE reads whole on one line where it has the least room",
          arguments: [DynamicTypeSize.xxxLarge, .accessibility5])
    func eightDigitTonnageReadsWholeOnOneLine(size: DynamicTypeSize) throws {
        let screen = try reviewScreen(tonnage: 99_999_999, size: size)
        let lines = try textLines(in: screen)
        #expect(lines.contains { digits(in: $0.text).contains("99999999") },
                "99,999,999 must read whole on one line at \(size), but the screen reads \(lines.map(\.text))")
    }

    @Test("a TONNAGE that fits the row keeps the full size of the SESSIONS and PRS values")
    func tonnageThatFitsKeepsItsFullSize() throws {
        let screen = try reviewScreen(tonnage: 1_500, size: .large)
        let line = try #require(try textLines(in: screen).first { digits(in: $0.text).contains("1500") },
                                "The screen must read TONNAGE's 1,500")
        // The values' line across the row: TONNAGE's signal digits beside
        // the paper digits of SESSIONS and PRS, all bottom-aligned.
        let row = CGRect(x: 0, y: line.box.minY - line.box.height / 4,
                         width: CGFloat(screen.width), height: line.box.height * 1.5)
        let tonnage = try #require(screen.extent(of: Self.isSignal, in: row), "No TONNAGE digits in \(row)")
        let values = try #require(screen.extent(of: Self.isPaper, in: row), "No SESSIONS or PRS digits in \(row)")
        // 1,500's comma reaches below the digits, so a full-size TONNAGE is
        // at least as tall as the 1s beside it.
        #expect(tonnage.height >= values.height * 0.95,
                "TONNAGE's 1,500 is \(tonnage.height)px tall, shorter than the \(values.height)px values beside it")
    }

    // MARK: - Fixture

    /// The review of an ended block whose one finished workout logged a
    /// single set of `tonnage` x 1 of the bench press, so SESSIONS and PRS
    /// both read 1, drawn in a window the small phone's width at `size`.
    private func reviewScreen(tonnage: Double, size: DynamicTypeSize) throws -> Screen {
        let container = try FitbodModelContainer.make(inMemory: true)
        let context = container.mainContext
        let bench = Exercise(
            name: "Bench Press",
            canonicalName: "bench press",
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
        context.insert(bench)
        let block = Block()
        context.insert(block)
        block.name = "Peak Block"
        block.startDate = started
        block.endDate = started + 28 * 86_400

        let session = Session()
        context.insert(session)
        session.startedAt = started + 86_400
        session.completedAt = session.startedAt + 3_600
        let sessionExercise = SessionExercise()
        context.insert(sessionExercise)
        sessionExercise.session = session
        sessionExercise.exercise = bench
        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = sessionExercise
        set.weight = tonnage
        set.reps = 1
        set.completedAt = session.startedAt + 600
        set.isComplete = true
        set.setTypeRaw = SetType.working.rawValue
        try context.save()

        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        // Tall enough for TONNAGE's stat at AX5, and light whatever the
        // phone's appearance: in dark mode paper and ink swap.
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 1_200)
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = UIHostingController(
            rootView: BlockReviewView(block: block)
                .modelContainer(container)
                .environment(\.dynamicTypeSize, size)
        )
        window.isHidden = false
        defer { window.isHidden = true }

        // Draws the window until TONNAGE's signal digits show above the
        // action bar, whose Start next is signal too, running the main run
        // loop in 50 ms steps while SwiftUI renders. A ceiling, not a wait.
        let hero = CGRect(x: 0, y: 0, width: 390 * Self.scale, height: (1_200 - 200) * Self.scale)
        let deadline = Date.now.addingTimeInterval(5)
        var screen = try draw(window)
        while !screen.contains(Self.isSignal, in: hero), Date.now < deadline {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
            screen = try draw(window)
        }
        return screen
    }

    /// Pixels per point of the drawn screen: one reads the hero's numbers
    /// and keeps Vision and the pixel scans quick.
    private static let scale: CGFloat = 1

    private func draw(_ window: UIWindow) throws -> Screen {
        let format = UIGraphicsImageRendererFormat()
        format.scale = Self.scale
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        return try Screen(try #require(image.cgImage))
    }

    // MARK: - Reading the screen

    /// The lines of text Vision reads on `screen`, each with its box in
    /// the screen's pixels, from the top.
    private func textLines(in screen: Screen) throws -> [(text: String, box: CGRect)] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: screen.image).perform([request])
        let (width, height) = (CGFloat(screen.width), CGFloat(screen.height))
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let box = observation.boundingBox
            return (text, CGRect(x: box.minX * width, y: (1 - box.maxY) * height,
                                 width: box.width * width, height: box.height * height))
        }
        .sorted { $0.box.minY < $1.box.minY }
    }

    /// The digits of `text`. Vision can read a 0 as the letter O.
    private func digits(in text: String) -> String {
        String(text.compactMap { character -> Character? in
            switch character {
            case "O", "o": "0"
            default: character.isNumber ? character : nil
            }
        })
    }

    /// The signal color of TONNAGE's value: a saturated orange.
    private static func isSignal(_ red: Double, _ green: Double, _ blue: Double) -> Bool {
        red > 0.7 && red - blue > 0.4 && green < 0.6
    }

    /// The paper color of the SESSIONS and PRS values, brighter than the
    /// labels' paper at 60% over the ink band.
    private static func isPaper(_ red: Double, _ green: Double, _ blue: Double) -> Bool {
        min(red, green, blue) > 0.85
    }
}

/// A drawn screen and its sRGB pixels, four bytes to a pixel, row by row
/// from the top.
private struct Screen {
    let image: CGImage
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: CGImage) throws {
        self.image = image
        (width, height) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(
                      data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                      bytesPerRow: image.width * 4, space: space,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        try #require(drawn, "Cannot read the screen's pixels")
        self.bytes = bytes
    }

    /// Whether any pixel in `rect` has a color that `matches`.
    func contains(_ matches: (Double, Double, Double) -> Bool, in rect: CGRect) -> Bool {
        let area = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !area.isEmpty else { return false }
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) {
                let (red, green, blue) = color(x, y)
                if matches(red, green, blue) { return true }
            }
        }
        return false
    }

    /// The smallest box, in pixels, around the pixels in `rect` whose
    /// color `matches`, or nil when none does.
    func extent(of matches: (Double, Double, Double) -> Bool, in rect: CGRect) -> CGRect? {
        let area = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !area.isEmpty else { return nil }
        var (minX, minY, maxX, maxY) = (Int.max, Int.max, Int.min, Int.min)
        for y in Int(area.minY)..<Int(area.maxY) {
            for x in Int(area.minX)..<Int(area.maxX) {
                let (red, green, blue) = color(x, y)
                guard matches(red, green, blue) else { continue }
                (minX, minY, maxX, maxY) = (min(minX, x), min(minY, y), max(maxX, x), max(maxY, y))
            }
        }
        guard minX <= maxX else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    /// The red, green and blue of the pixel at `x`, `y`, from 0 to 1.
    private func color(_ x: Int, _ y: Int) -> (Double, Double, Double) {
        let offset = (y * width + x) * 4
        return (Double(bytes[offset]) / 255, Double(bytes[offset + 1]) / 255, Double(bytes[offset + 2]) / 255)
    }
}
