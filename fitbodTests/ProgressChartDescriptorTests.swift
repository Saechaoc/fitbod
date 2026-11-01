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
    @Test("The chart on screen hands VoiceOver its own descriptor")
    func chartOnScreenUsesItsOwnDescriptor() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let bench = try logBenchPress(in: container.mainContext)
        let window = try showProgress(of: bench, in: container)
        defer { window.isHidden = true }

        waitUntil { chartDescriptor(under: window) != nil }
        let descriptor = try #require(chartDescriptor(under: window), "The chart hands VoiceOver no audio graph")
        #expect(descriptor.yAxis?.valueDescriptionProvider(112.5) == "113 lb")
        #expect(descriptor.series.map(\.name) == ["TOP SET", "ALL-SET AVG"])
    }

    /// SwiftUI keeps the descriptor it first made and updates it, so one
    /// that ignored updates kept reading lb. Main actor, as it hosts the
    /// screen in a UIKit window.
    @MainActor
    @Test("The chart on screen reads a new unit once the exercise is labeled kg")
    func chartOnScreenReadsANewUnit() throws {
        let container = try FitbodModelContainer.make(inMemory: true)
        let bench = try logBenchPress(in: container.mainContext)
        let window = try showProgress(of: bench, in: container)
        defer { window.isHidden = true }
        waitUntil { yAxisReading(of: 112.5, under: window) != nil }
        try #require(yAxisReading(of: 112.5, under: window) == "113 lb")

        bench.unitOverride = .kg
        waitUntil { yAxisReading(of: 112.5, under: window) == "113 kg" }
        #expect(yAxisReading(of: 112.5, under: window) == "113 kg")
    }

    // MARK: - Helpers

    /// `bench`'s progress screen in a window the small phone's width.
    @MainActor
    private func showProgress(of bench: Exercise, in container: ModelContainer) throws -> UIWindow {
        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = UIHostingController(
            rootView: ExerciseProgressView(exercise: bench).modelContainer(container)
        )
        window.isHidden = false
        return window
    }

    /// A point on an e1RM chip, as the chart draws an `E1RMSeriesPoint`.
    private func e1RMPoint(week: Int, value: Double, kind: SeriesKind) -> ChartPoint {
        ChartPoint(
            id: "\(week)-\(kind.rawValue)",
            date: firstDay.addingTimeInterval(Double(week) * 7 * 24 * 3600),
            value: value,
            series: kind.displayLabel,
            isPrimary: kind == .topSet,
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
            isPrimary: intent == .hypertrophy,
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

    /// Two finished workouts of the bench press, a week apart: 100 x 5 and
    /// 95 x 5, a top set of 112.5 e1RM, then 105 x 5.
    @MainActor
    private func logBenchPress(in context: ModelContext) throws -> Exercise {
        let bench = Exercise(
            name: "Bench Press", canonicalName: "bench press",
            equipmentRaw: "barbell", mechanicRaw: "compound"
        )
        context.insert(bench)
        for (week, weights) in [[100.0, 95.0], [105.0]].enumerated() {
            let start = firstDay.addingTimeInterval(Double(week) * 7 * 24 * 3600)
            let workout = Session()
            context.insert(workout)
            workout.startedAt = start
            workout.completedAt = start.addingTimeInterval(3600)
            workout.intentRaw = Intent.strength.rawValue
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
        if property("accessibilityIdentifier", of: root) as? String == "progress.chart" {
            return property("accessibilityChartDescriptor", of: root) as? AXChartDescriptor
        }
        let children = (root.accessibilityElements ?? []) + ((root as? UIView)?.subviews ?? [])
        for case let child as NSObject in children {
            if let descriptor = chartDescriptor(under: child) {
                return descriptor
            }
        }
        return nil
    }

    /// An accessibility property of `element` by name. SwiftUI's elements
    /// have the properties without declaring the protocols that name them.
    @MainActor
    private func property(_ name: String, of element: NSObject) -> Any? {
        element.responds(to: NSSelectorFromString(name)) ? element.value(forKey: name) : nil
    }

    /// How the y axis of the chart under `root` reads `value`.
    @MainActor
    private func yAxisReading(of value: Double, under root: NSObject) -> String? {
        chartDescriptor(under: root)?.yAxis?.valueDescriptionProvider(value)
    }

    /// Runs the main run loop in 50 ms steps while SwiftUI renders the
    /// screen, until `done` holds or two seconds pass.
    @MainActor
    private func waitUntil(_ done: () -> Bool) {
        let deadline = Date.now.addingTimeInterval(2)
        while !done(), Date.now < deadline {
            RunLoop.main.run(until: Date.now.addingTimeInterval(0.05))
        }
    }
}
