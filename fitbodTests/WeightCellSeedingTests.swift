//
//  WeightCellSeedingTests.swift
//  fitbodTests
//
//  Rendering a suggested weight keeps the saved draft and actual values intact.
//

import SwiftData
import SwiftUI
import Testing
import UIKit
@testable import fitbod

/// Main actor, as it shows the fields in a UIKit window so their onAppear runs.
@MainActor
@Suite("WeightCellSeeding")
struct WeightCellSeedingTests {

    @Test("An open field shows its offer without seeding a stored weight")
    func seedsOnlyUntouchedOpenSets() throws {
        let container = try InMemoryContainer.makeCurrent()
        let untouched = entry(in: container)
        // A logged set keeps the 0 it logged.
        let logged = entry(in: container, isComplete: true)
        // An open set keeps a 0 the lifter typed.
        let typed = entry(in: container, wasManualOverride: true)

        let scene = try #require(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        var appeared = false
        window.rootViewController = UIHostingController(rootView: VStack {
            cell(for: untouched)
            cell(for: logged)
            cell(for: typed)
        }.onAppear { appeared = true })
        window.isHidden = false
        defer { window.isHidden = true }

        HostedAccessibility.waitUntil { appeared }
        #expect(appeared)
        #expect(cell(for: untouched).accessibilityValueText == "25 lb")
        #expect(untouched.weight == 0)
        #expect(logged.weight == 0)
        #expect(typed.weight == 0)
    }

    /// A set holding 0 lb, inserted before its fields are set.
    private func entry(
        in container: ModelContainer,
        isComplete: Bool = false,
        wasManualOverride: Bool = false
    ) -> SetEntry {
        let entry = SetEntry()
        container.mainContext.insert(entry)
        entry.weight = 0
        entry.isComplete = isComplete
        entry.wasManualOverride = wasManualOverride
        return entry
    }

    /// The set's weight field as SetRow builds it, with 25 lb prescribed.
    private func cell(for entry: SetEntry) -> PrescriptionWeightCell {
        let set = Bindable(entry)
        return PrescriptionWeightCell(
            weight: set.weight,
            prescribed: 25,
            range: nil,
            offeredWeight: 25,
            unitLabel: "lb",
            wasManualOverride: set.wasManualOverride,
            isComplete: entry.isComplete
        )
    }
}
