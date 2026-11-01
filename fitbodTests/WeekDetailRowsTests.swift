//
//  WeekDetailRowsTests.swift
//  fitbodTests
//
//  Ticket T118, finding F245. Each row in a Weekly Tonnage week's detail
//  drew a "›", but a tap on it opened nothing. A workout's row now opens
//  its summary, and VoiceOver reads it as a button. The row that gathers
//  the week's sets that belong to no workout has nothing to open: it is
//  text, not a button, and draws no "›".
//
//  The test shows the week in a window the small phone's width, finds the
//  rows as VoiceOver does, and reads each row's "›" from the screen,
//  because the glyph is hidden from VoiceOver. No seed or UI path logs
//  sets that belong to no workout, so WeeklyTonnageUITests cannot reach
//  that row.
//

import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import fitbod

/// Main actor, as it shows the week in a UIKit window.
@MainActor
@Suite("WeekDetailRows")
struct WeekDetailRowsTests {
    private let hour: TimeInterval = 3_600
    private let day: TimeInterval = 86_400

    @Test("a workout's row is a button with a ›, and the row of sets with no workout is text without one")
    func onlyAWorkoutsRowOpens() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = WeeklyTonnageAggregator.weekCalendar(weekStartsMonday: true)
        let weekStart = try #require(
            calendar.dateInterval(of: .weekOfYear, for: Date(timeIntervalSince1970: 1_780_000_000))?.start
        )
        // The workout on the week's Tuesday, the set with no workout on its
        // Monday, so the workout's row comes first.
        logWorkout(named: "Push A", at: weekStart + day + 9 * hour, in: context)
        logSetOfNoWorkout(at: weekStart + 9 * hour, in: context)
        try context.save()

        let window = try showWeek(from: weekStart, in: container)
        defer { window.isHidden = true }

        let workout = try #require(
            row(named: "Push A", in: window),
            "VoiceOver reads no row for Push A as one element, by its name, day and tonnage"
        )
        let noWorkout = try #require(
            row(named: "Unnamed workout", in: window),
            "VoiceOver reads no row for the set that belongs to no workout as one element, by its name, day and tonnage"
        )
        #expect(workout.accessibilityTraits.contains(.button), "VoiceOver must read Push A's row as a button")
        #expect(
            !noWorkout.accessibilityTraits.contains(.button),
            "The row of sets with no workout opens nothing, so VoiceOver must not read it as a button"
        )
        #expect(try drawsChevron(workout, in: window), "Push A's row opens its workout, so it must draw a ›")
        #expect(
            try !drawsChevron(noWorkout, in: window),
            "The row of sets with no workout opens nothing, so it must draw no ›"
        )
    }

    // MARK: - Fixture

    /// A workout named `name`, finished an hour after `date`, with two
    /// working sets of 100 x 5, the first done at `date`.
    private func logWorkout(named name: String, at date: Date, in context: ModelContext) {
        let session = Session()
        context.insert(session)
        session.startedAt = date
        session.completedAt = date + hour
        session.routineSnapshotName = name

        let sessionExercise = SessionExercise()
        context.insert(sessionExercise)
        sessionExercise.session = session

        for index in 0..<2 {
            let set = SetEntry()
            context.insert(set)
            set.sessionExercise = sessionExercise
            set.weight = 100
            set.reps = 5
            set.isComplete = true
            set.setTypeRaw = SetType.working.rawValue
            set.completedAt = date + Double(index) * 180
        }
    }

    /// A working set of 50 x 5 done at `date` that belongs to no workout.
    private func logSetOfNoWorkout(at date: Date, in context: ModelContext) {
        let set = SetEntry()
        context.insert(set)
        set.weight = 50
        set.reps = 5
        set.isComplete = true
        set.setTypeRaw = SetType.working.rawValue
        set.completedAt = date
    }

    // MARK: - The week on screen

    /// The week from `weekStart` in a window the small phone's width, in a
    /// navigation stack as on the Progress tab, once it shows both rows.
    private func showWeek(from weekStart: Date, in container: ModelContainer) throws -> UIWindow {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIHostingController(
            rootView: NavigationStack {
                WeekDetailView(weekStart: weekStart, weekStartsMonday: true)
            }
            .modelContainer(container)
        )
        window.isHidden = false
        waitUntil {
            row(named: "Push A", in: window) != nil && row(named: "Unnamed workout", in: window) != nil
        }
        return window
    }

    /// The row VoiceOver reads as one element: `name`, then its day and
    /// tonnage, such as "Push A, Tue, May 26 · 1,000 lb". Its frame is the
    /// whole row.
    private func row(named name: String, in window: UIWindow) -> NSObject? {
        elements(under: window).first { element in
            guard let label = element.accessibilityLabel else { return false }
            return label.hasPrefix("\(name), ") && label.contains(" · ")
        }
    }

    /// Whether `row` draws anything in the screen's trailing 40pt along it,
    /// where a row that opens draws its "›" and nothing else is drawn: a
    /// pixel there that differs from the paper at the area's bottom
    /// trailing corner, which lies in the row's padding.
    private func drawsChevron(_ row: NSObject, in window: UIWindow) throws -> Bool {
        let screen = try #require(window.windowScene?.screen)
        let frame = window.convert(row.accessibilityFrame, from: screen.coordinateSpace)
        let area = CGRect(x: window.bounds.maxX - 40, y: frame.minY + 4, width: 40, height: frame.height - 8)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: area, format: format).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let pixels = try sRGBPixels(of: try #require(image.cgImage))
        let paper = try #require(pixels.last)
        return pixels.contains { pixel in
            zip(pixel, paper).contains { abs(Int($0) - Int($1)) > 48 }
        }
    }

    /// `image`'s pixels, each its sRGB red, green and blue, row by row from
    /// the top.
    private func sRGBPixels(of image: CGImage) throws -> [[UInt8]] {
        let sRGB = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        try #require(drawn, "Cannot read the screen's pixels")
        return stride(from: 0, to: bytes.count, by: 4).map { Array(bytes[$0..<$0 + 3]) }
    }

    /// Every accessibility element and view under `root`, depth first.
    private func elements(under root: NSObject) -> [NSObject] {
        let children = (root.accessibilityElements ?? []) + ((root as? UIView)?.subviews ?? [])
        return children.compactMap { $0 as? NSObject }.flatMap { [$0] + elements(under: $0) }
    }

    /// Runs the main run loop in 50 ms steps while SwiftUI renders the
    /// week, until `done` holds or ten seconds pass. A ceiling, not a wait.
    private func waitUntil(_ done: () -> Bool) {
        let deadline = Date.now.addingTimeInterval(10)
        while !done(), Date.now < deadline {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
        }
    }
}
