//
//  WeightCellSeedingTests.swift
//  fitbodTests
//
//  A weight field that appears holding 0 fills in the prescription only for
//  an open set the lifter has not changed. A logged 0, such as weighted dips
//  done with no added load, and a 0 the lifter typed both stay 0: before
//  RM-024's weight guidance, a logged 0 turned into the prescription each
//  time its row appeared, and the next save stored it.
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

    @Test("Only an untouched open set takes the prescription when its field appears")
    func seedsOnlyUntouchedOpenSets() throws {
        let container = try InMemoryContainer.makeCurrent()
        // The control: an open set nobody changed fills in the prescription,
        // which shows the fields appeared.
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
        window.rootViewController = UIHostingController(rootView: VStack {
            cell(for: untouched)
            cell(for: logged)
            cell(for: typed)
        })
        window.isHidden = false
        defer { window.isHidden = true }

        // SwiftUI runs the three fields' onAppear in one pass, so once the
        // control has filled in, the other two have had their turn.
        HostedAccessibility.waitUntil { untouched.weight == 25 }
        #expect(untouched.weight == 25)
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
            unitLabel: "lb",
            wasManualOverride: set.wasManualOverride,
            isComplete: entry.isComplete
        )
    }
}
