//
//  BlockReviewPRMarkTests.swift
//  fitbodTests
//
//  Ticket T113, finding F235. The block review's e1RM rows showed "★ PR"
//  whenever a lift's e1RM rose during the block, a placeholder rule, so a
//  row could say PR while PRS counted none for its lift, or the other way
//  round. A row now shows the chip only when its lift set a PR during the
//  block by the rule PRS counts, so the chips and the count agree.
//
//  Each test shows the review in a window the small phone's width and
//  reads the lift's row from the screen, because the chip is hidden from
//  VoiceOver.
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
@Suite("BlockReviewPRMark")
struct BlockReviewPRMarkTests {
    private let day: TimeInterval = 86_400
    private let started = Date(timeIntervalSince1970: 1_780_000_000)

    @Test("a lift whose e1RM rose without beating its earlier sets is not marked as a PR")
    func e1RMRiseWithoutAPRIsNotMarked() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let context = container.mainContext
        let bench = makeExercise("Bench Press", in: context)
        let block = makeBlock(in: context)
        // The block's 100 x 5 and 105 x 5 raise the e1RM by 5.8, but
        // neither beats the 110 x 5 the week before the block.
        logWorkout(of: bench, on: started - 7 * day, weight: 110, in: context)
        logWorkout(of: bench, on: started + 7 * day, weight: 100, in: context)
        logWorkout(of: bench, on: started + 14 * day, weight: 105, in: context)
        try context.save()

        let window = try showReview(of: block, in: container)
        defer { window.isHidden = true }

        #expect(prsValue(in: window) == "0", "No set in the block beats the 110 x 5 before it")
        #expect(try !rowShowsPRChip("Bench Press", in: window),
                "Bench Press's row says PR, but PRS counts no PR for it: its e1RM rose without beating the 110 x 5")
    }

    @Test("a lift that set a PR during the block is marked, even when its e1RM fell")
    func prWithAFallingE1RMIsMarked() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let context = container.mainContext
        let squat = makeExercise("Squat", in: context)
        let block = makeBlock(in: context)
        // The block's 110 x 5 beats the 100 x 5 before it; its 105 x 5
        // then lowers the e1RM by 5.8.
        logWorkout(of: squat, on: started - 7 * day, weight: 100, in: context)
        logWorkout(of: squat, on: started + 7 * day, weight: 110, in: context)
        logWorkout(of: squat, on: started + 14 * day, weight: 105, in: context)
        try context.save()

        let window = try showReview(of: block, in: container)
        defer { window.isHidden = true }

        #expect(prsValue(in: window) == "1", "The block's 110 x 5 beats the 100 x 5 before it")
        #expect(try rowShowsPRChip("Squat", in: window),
                "Squat's row shows no PR, but PRS counts its 110 x 5: its e1RM fell after the PR")
    }

    // MARK: - Fixture

    private func makeExercise(_ name: String, in context: ModelContext) -> Exercise {
        let exercise = Exercise(
            name: name,
            canonicalName: name.lowercased(),
            equipmentRaw: Equipment.barbell.rawValue,
            mechanicRaw: Mechanic.compound.rawValue
        )
        context.insert(exercise)
        return exercise
    }

    /// A four-week block that ran from `started`, ended.
    private func makeBlock(in context: ModelContext) -> Block {
        let block = Block()
        context.insert(block)
        block.name = "Peak Block"
        block.startDate = started
        block.endDate = started + 28 * day
        return block
    }

    /// A workout of `exercise` on `date`, finished an hour later, with one
    /// working set of `weight` x 5 logged ten minutes in.
    private func logWorkout(of exercise: Exercise, on date: Date, weight: Double, in context: ModelContext) {
        let session = Session()
        context.insert(session)
        session.startedAt = date
        session.completedAt = date + 3_600

        let sessionExercise = SessionExercise()
        context.insert(sessionExercise)
        sessionExercise.session = session
        sessionExercise.exercise = exercise

        let set = SetEntry()
        context.insert(set)
        set.sessionExercise = sessionExercise
        set.weight = weight
        set.reps = 5
        set.completedAt = date + 600
        set.isComplete = true
        set.setTypeRaw = SetType.working.rawValue
    }

    // MARK: - The review on screen

    /// The review of `block` in a window the small phone's width, once it
    /// shows its PRS value and its e1RM rows.
    private func showReview(of block: Block, in container: ModelContainer) throws -> UIWindow {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIHostingController(
            rootView: BlockReviewView(block: block).modelContainer(container)
        )
        window.isHidden = false
        waitUntil { prsValue(in: window) != nil }
        return window
    }

    /// The PRS stat's value, as VoiceOver reads it: the stat's text
    /// without letters.
    private func prsValue(in window: UIWindow) -> String? {
        guard let stat = elements(under: window).first(where: {
            property("accessibilityIdentifier", of: $0) as? String == "blockReview.stat.prs"
        }) else { return nil }
        return elements(under: stat).compactMap(\.accessibilityLabel).first { !$0.contains(where: \.isLetter) }
    }

    /// Whether `lift`'s e1RM row shows the ★ PR chip, read from the screen
    /// across the row's width at the height of the lift's name.
    private func rowShowsPRChip(_ lift: String, in window: UIWindow) throws -> Bool {
        let name = try #require(elements(under: window).first { $0.accessibilityLabel == lift },
                                "The review shows no e1RM row for \(lift)")
        let screen = try #require(window.windowScene?.screen)
        let frame = window.convert(name.accessibilityFrame, from: screen.coordinateSpace)
        let row = CGRect(x: 0, y: frame.minY - 8, width: window.bounds.width, height: frame.height + 16)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(bounds: row, format: format).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: try #require(image.cgImage)).perform([request])
        let words = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .flatMap { $0.split { !$0.isLetter && !$0.isNumber } }
        // Vision can read the star into the word, as "*PR" or "XPR".
        return words.contains { $0.hasSuffix("PR") }
    }

    /// Every accessibility element and view under `root`, depth first.
    private func elements(under root: NSObject) -> [NSObject] {
        let children = (root.accessibilityElements ?? []) + ((root as? UIView)?.subviews ?? [])
        return children.compactMap { $0 as? NSObject }.flatMap { [$0] + elements(under: $0) }
    }

    /// An accessibility property of `element` by name. SwiftUI's elements
    /// have the properties without declaring the protocols that name them.
    private func property(_ name: String, of element: NSObject) -> Any? {
        element.responds(to: NSSelectorFromString(name)) ? element.value(forKey: name) : nil
    }

    /// Runs the main run loop in 50 ms steps while SwiftUI renders the
    /// review, until `done` holds or ten seconds pass. A ceiling, not a
    /// wait.
    private func waitUntil(_ done: () -> Bool) {
        let deadline = Date.now.addingTimeInterval(10)
        while !done(), Date.now < deadline {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
        }
    }
}
