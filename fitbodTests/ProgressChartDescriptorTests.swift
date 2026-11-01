//
//  ProgressChartDescriptorTests.swift
//  fitbodTests
//
//  Ticket T98, finding F140. Since T82, VoiceOver reads each point on the
//  progress chart by itself, with its rounded value ("113 lb"). The chart's
//  audio graph came from Swift Charts, whose y axis read 112.5 as "112.5",
//  with no unit. The chart now hands VoiceOver its own descriptor:
//
//    - the y axis reads values the way each point does, through
//      spokenValue: "113 lb", "2,140 lb" or "RPE 7.6";
//    - the x axis reads dates; and
//    - each drawn line is a series, named as the legend names it.
//
//  Ticket T129, finding F297. VOLUME and AVG RPE draw a line per intent,
//  but the legend named only HYPERTROPHY and STRENGTH, and a power line
//  was drawn like strength's. The legend now names every intent drawn,
//  as in POWER · 1 SESSION, in the order the audio graph reads them.
//

import Accessibility
import Foundation
import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import fitbod

@Suite("Progress chart audio graph")
struct ProgressChartDescriptorTests {

    private let firstDay = Date(timeIntervalSinceReferenceDate: 815_000_000)

    // MARK: - The descriptor

    @Test("An e1RM chart's y axis reads a 112.5 lb top set as 113 lb, by TOP SET and ALL-SET AVG")
    func e1RMChartReadsRoundedWeightsByLegendName() {
        let points = [(0, 112.5, 109.69), (1, 118.13, 118.13)].flatMap { week, topSet, average in
            [
                e1RMPoint(week: week, value: topSet, kind: .topSet),
                e1RMPoint(week: week, value: average, kind: .allSetAvg),
            ]
        }
        let descriptor = ProgressChartDescriptor(metric: .e1RM, points: points, unit: .lb).makeChartDescriptor()

        #expect(descriptor.yAxis?.valueDescriptionProvider(112.5) == "113 lb")
        #expect(descriptor.series.map(\.name) == ["TOP SET", "ALL-SET AVG"])
    }

    @Test("The y axis reads each chip's values as its points do")
    func yAxisReadsLikeThePoints() {
        #expect(reading(112.5, on: .topSet, in: .kg) == "113 kg")
        #expect(reading(2140, on: .volume, in: .lb) == "2,140 lb")
        #expect(reading(7.63, on: .averageRPE, in: .lb) == "RPE 7.6")
    }

    @Test("VOLUME reads a line per intent, named as the legend names it, along an x axis of dates")
    func volumeChartReadsALinePerIntentByDate() throws {
        let points = [
            workoutPoint(week: 0, value: 2140, intent: .hypertrophy),
            workoutPoint(week: 1, value: 2300, intent: .strength),
            workoutPoint(week: 2, value: 2450, intent: .strength),
        ]
        let descriptor = ProgressChartDescriptor(metric: .volume, points: points, unit: .lb).makeChartDescriptor()

        #expect(descriptor.series.map(\.name) == ["HYPERTROPHY · 1 SESSION", "STRENGTH · 2 SESSIONS"])
        #expect(descriptor.series.map(\.dataPoints.count) == [1, 2])
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(
            xAxis.valueDescriptionProvider(firstDay.timeIntervalSinceReferenceDate)
                == firstDay.formatted(date: .abbreviated, time: .omitted)
        )
    }

    // MARK: - The chart on screen

    /// Main actor, as it hosts the screen in a UIKit window.
    @MainActor
    @Test("The chart on screen hands VoiceOver its own descriptor", .hostedAccessibility)
    func chartOnScreenUsesItsOwnDescriptor() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let bench = try logBenchPress(in: container.mainContext)
        let window = try showProgress(of: bench, in: container)
        defer { window.isHidden = true }

        HostedAccessibility.waitUntil { chartDescriptor(under: window) != nil }
        let descriptor = try #require(chartDescriptor(under: window), "The chart hands VoiceOver no audio graph")
        #expect(descriptor.yAxis?.valueDescriptionProvider(112.5) == "113 lb")
        #expect(descriptor.series.map(\.name) == ["TOP SET", "ALL-SET AVG"])
    }

    /// SwiftUI keeps the descriptor it first made and updates it, so one
    /// that ignored updates kept reading lb. Main actor, as it hosts the
    /// screen in a UIKit window.
    @MainActor
    @Test("The chart on screen reads a new unit once the exercise is labeled kg", .hostedAccessibility)
    func chartOnScreenReadsANewUnit() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let bench = try logBenchPress(in: container.mainContext)
        let window = try showProgress(of: bench, in: container)
        defer { window.isHidden = true }
        HostedAccessibility.waitUntil { yAxisReading(of: 112.5, under: window) != nil }
        try #require(yAxisReading(of: 112.5, under: window) == "113 lb")

        bench.unitOverride = .kg
        HostedAccessibility.waitUntil { yAxisReading(of: 112.5, under: window) == "113 kg" }
        #expect(yAxisReading(of: 112.5, under: window) == "113 kg")
    }

    // MARK: - The legend

    @Test("Each intent draws its line, and its legend swatch, in a color and dash of its own")
    func eachIntentHasAStyleOfItsOwn() {
        let styles = Intent.allCases.map(ChartLineStyle.init(intent:))
        #expect(Set(styles.map(\.color)).count == styles.count)
        #expect(Set(styles.map(\.dash)).count == styles.count)
        #expect(Set(styles.map(\.swatchDash)).count == styles.count)
    }

    /// Two, three and four workouts in three intents, so each line is
    /// drawn and each key's count is its own. Main actor, as it hosts the
    /// screen in a UIKit window.
    @MainActor
    @Test("VOLUME's legend names every intent it draws, as its audio graph does", .hostedAccessibility)
    func volumeLegendNamesEveryIntentItDraws() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let bench = try logBenchPress(in: container.mainContext, workouts: [
            (.hypertrophy, [80]), (.strength, [100]), (.power, [60]),
            (.hypertrophy, [90]), (.strength, [105]), (.power, [65]),
            (.strength, [110]), (.power, [70]), (.power, [75]),
        ])
        let window = try showProgress(of: bench, in: container)
        defer { window.isHidden = true }
        HostedAccessibility.waitUntil { button(labeled: "VOLUME", under: window) != nil }
        let volume = try #require(button(labeled: "VOLUME", under: window), "The VOLUME chip is not on screen")

        volume.accessibilityActivate()
        HostedAccessibility.waitUntil {
            chartDescriptor(under: window)?.title == "Volume chart" && !intentKeys(under: window).isEmpty
        }
        // Lets the chip's 0.18 s chart transition finish before the screenshot.
        RunLoop.main.run(until: Date.now.addingTimeInterval(0.3))
        attachScreen(of: window, named: "T129-chart-volume")

        let legend = intentKeys(under: window)
        #expect(legend == ["HYPERTROPHY · 2 SESSIONS", "STRENGTH · 3 SESSIONS", "POWER · 4 SESSIONS"])
        #expect(
            chartDescriptor(under: window)?.series.compactMap(\.name) == legend,
            "The audio graph must name each line as the legend does, in its order"
        )
    }

    // MARK: - Helpers

    /// `bench`'s progress screen in a window the small phone's width.
    @MainActor
    private func showProgress(of bench: Exercise, in container: ModelContainer) throws -> UIWindow {
        try HostedAccessibility.show(ExerciseProgressView(exercise: bench).modelContainer(container))
    }

    /// A point on an e1RM chip, as the chart draws an `E1RMSeriesPoint`.
    private func e1RMPoint(week: Int, value: Double, kind: SeriesKind) -> ChartPoint {
        ChartPoint(
            id: "\(week)-\(kind.rawValue)",
            date: firstDay.addingTimeInterval(Double(week) * 7 * 24 * 3600),
            value: value,
            series: kind.displayLabel,
            style: kind == .topSet ? .ink : .signal,
            intent: .strength
        )
    }

    /// A point on VOLUME or AVG RPE, as the chart draws a `WorkoutSeriesPoint`.
    private func workoutPoint(week: Int, value: Double, intent: Intent) -> ChartPoint {
        ChartPoint(
            id: "\(week)",
            date: firstDay.addingTimeInterval(Double(week) * 7 * 24 * 3600),
            value: value,
            series: intent.rawValue.capitalized,
            style: ChartLineStyle(intent: intent),
            intent: intent
        )
    }

    /// How the y axis of `metric`'s chart reads `value` in `unit`.
    private func reading(_ value: Double, on metric: ProgressChartMetric, in unit: WeightUnit) -> String? {
        ProgressChartDescriptor(metric: metric, points: [], unit: unit)
            .makeChartDescriptor()
            .yAxis?
            .valueDescriptionProvider(value)
    }

    /// Finished workouts of the bench press, a week apart, each in its
    /// intent with a set of 5 at each of its weights. By default two
    /// strength workouts: 100 x 5 and 95 x 5, a top set of 112.5 e1RM,
    /// then 105 x 5.
    @MainActor
    private func logBenchPress(
        in context: ModelContext,
        workouts: [(intent: Intent, weights: [Double])] = [(.strength, [100, 95]), (.strength, [105])]
    ) throws -> Exercise {
        let bench = Exercise(
            name: "Bench Press", canonicalName: "bench press",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        context.insert(bench)
        for (week, logged) in workouts.enumerated() {
            let (intent, weights) = logged
            let start = firstDay.addingTimeInterval(Double(week) * 7 * 24 * 3600)
            let workout = Session()
            context.insert(workout)
            workout.startedAt = start
            workout.completedAt = start.addingTimeInterval(3600)
            workout.intentRaw = intent.rawValue
            let entry = SessionExercise()
            context.insert(entry)
            entry.session = workout
            entry.exercise = bench
            for (index, weight) in weights.enumerated() {
                let set = SetEntry()
                context.insert(set)
                set.sessionExercise = entry
                set.orderIndex = index
                set.weight = weight
                set.reps = 5
                set.isComplete = true
                set.completedAt = start.addingTimeInterval(Double(index) * 180)
            }
        }
        try context.save()
        return bench
    }

    /// The audio graph of the element identified as the progress chart,
    /// found depth first among the accessibility elements under `root`.
    @MainActor
    private func chartDescriptor(under root: NSObject) -> AXChartDescriptor? {
        HostedAccessibility.elements(under: root)
            .first { HostedAccessibility.property("accessibilityIdentifier", of: $0) as? String == "progress.chart" }
            .flatMap { HostedAccessibility.property("accessibilityChartDescriptor", of: $0) as? AXChartDescriptor }
    }

    /// The button labeled `label` among the accessibility elements under `root`.
    @MainActor
    private func button(labeled label: String, under root: NSObject) -> NSObject? {
        HostedAccessibility.elements(under: root).first {
            $0.accessibilityLabel == label && $0.accessibilityTraits.contains(.button)
        }
    }

    /// The legend's keys for intents under `root`, in the order VoiceOver
    /// reads them, such as HYPERTROPHY · 2 SESSIONS.
    @MainActor
    private func intentKeys(under root: NSObject) -> [String] {
        let names = Intent.allCases.map { "\($0.rawValue.uppercased()) · " }
        return HostedAccessibility.elements(under: root)
            .compactMap { $0.accessibilityLabel?.uppercased() }
            .filter { label in names.contains { label.hasPrefix($0) } }
    }

    /// Attaches what `window` shows, as a PNG, for a person to look at.
    @MainActor
    private func attachScreen(of window: UIWindow, named name: String) {
        let png = UIGraphicsImageRenderer(bounds: window.bounds).pngData { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        Attachment.record(png, named: "\(name).png")
    }

    /// How the y axis of the chart under `root` reads `value`.
    @MainActor
    private func yAxisReading(of value: Double, under root: NSObject) -> String? {
        chartDescriptor(under: root)?.yAxis?.valueDescriptionProvider(value)
    }
}
