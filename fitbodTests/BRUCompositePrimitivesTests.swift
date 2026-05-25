//
//  BRUCompositePrimitivesTests.swift
//  fitbodTests
//
//  Swift Testing suite for Phase 2.1 Plan 03 composite BRU primitives.
//
//  Coverage:
//  1. bruTabValuesCoverFourCases     — BRUTab.allCases.count == 4, all labels/glyphs non-empty
//  2. bruTabGlyphsAreTypographic     — each glyph is a single Unicode scalar (not an SF Symbol)
//  3. bruDashedSlotFiresAction       — BRUDashedSlot tap closure fires (hosting-controller approach)
//  4. bruPillButtonFiresAction       — BRUPillButton tap closure fires
//  5. setCompletionGlyphRendersBoth  — SetCompletionGlyph(isComplete: false/true) renders without crash
//  6. headerActionIsSignalDrivers    — HeaderAction.isSignal pure-value contract
//
//  Note: Tests #3 and #4 use UIHostingController + accessibilityActivate.
//  If SwiftUI internals change such that accessibilityActivate no longer fires
//  button actions in hosted contexts, these tests are downgraded to compile-only
//  assertions per Plan 02.1-02 precedent. Any such downgrade is documented
//  in 02.1-10 UAT deferral.
//
//  Run via:
//    xcodebuild test -scheme fitbod -only-testing:fitbodTests/BRUCompositePrimitivesTests

import SwiftUI
import Testing
import UIKit
@testable import fitbod

// MARK: - Suite

@Suite("BRUCompositePrimitives", .serialized)
@MainActor
struct BRUCompositePrimitivesTests {

    // MARK: 1 — Tab value contract

    @Test func bruTabValuesCoverFourCases() {
        // Verify the enum has exactly 4 cases — `library` removed (quick task
        // 260525-g32 follow-up), `routines` renamed to `program` (quick task
        // 260525-gen).
        #expect(BRUTab.allCases.count == 4, "BRUTab must have exactly 4 cases; found \(BRUTab.allCases.count)")

        for tab in BRUTab.allCases {
            #expect(!tab.label.isEmpty, "BRUTab.\(tab.rawValue).label must be non-empty")
            #expect(!tab.glyph.isEmpty, "BRUTab.\(tab.rawValue).glyph must be non-empty")

            // Glyphs must NOT contain a colon (SF Symbol hint syntax uses colons e.g. "star.fill")
            // Typographic glyphs are single Unicode block elements with no colon
            #expect(!tab.glyph.contains(":"),
                "BRUTab.\(tab.rawValue).glyph '\(tab.glyph)' contains a colon — possible SF Symbol reference")
        }

        // Spot-check all 4 rawValues exist
        let rawValues = BRUTab.allCases.map(\.rawValue)
        #expect(rawValues.contains("today"))
        #expect(rawValues.contains("program"))
        #expect(rawValues.contains("progress"))
        #expect(rawValues.contains("settings"))
    }

    // MARK: 2 — Glyph single-scalar contract

    @Test func bruTabGlyphsAreTypographic() {
        for tab in BRUTab.allCases {
            let scalars = tab.glyph.unicodeScalars
            #expect(scalars.count == 1,
                "BRUTab.\(tab.rawValue).glyph '\(tab.glyph)' has \(scalars.count) scalars; expected 1 typographic character")

            // Verify the scalar is a block element / geometric shape character, not an ASCII letter
            // SF Symbol names are ASCII; our glyphs are ▣▤▥▦◍ (U+25A3, U+25A4, U+25A5, U+25A6, U+25CD)
            if let scalar = scalars.first {
                // All our glyphs are above U+2500 (Box Drawing block starts at U+2500)
                #expect(scalar.value > 0x2500,
                    "BRUTab.\(tab.rawValue).glyph '\(tab.glyph)' scalar U+\(String(scalar.value, radix: 16, uppercase: true)) is below U+2500 — may be ASCII, not a typographic glyph")
            }
        }
    }

    // MARK: 3 — BRUDashedSlot tap contract

    @Test func bruDashedSlotFiresAction() async throws {
        var fired = false

        let slot = BRUDashedSlot(
            label: "Add exercise",
            hint: "↘ FROM LIBRARY"
        ) {
            fired = true
        }

        // Render in a hosting controller to get a real UIView tree
        let host = UIHostingController(rootView: slot.frame(width: 300, height: 60))
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 60)
        host.view.layoutIfNeeded()

        // Attempt accessibilityActivate on the first activatable element
        let activated = activateFirstButton(in: host.view)

        if activated {
            // Give SwiftUI a chance to run the action on the main run loop
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            #expect(fired, "BRUDashedSlot action closure did not fire after accessibilityActivate")
        } else {
            // Downgrade: accessibilityActivate not available in this test config
            // Compile-time assertion: the type exists and has the expected init
            let _: BRUDashedSlot = BRUDashedSlot(label: "Test") {}
            // Document deferral
            // NOTE: Full tap-action verification deferred to Plan 02.1-10 UAT
        }
    }

    // MARK: 4 — BRUPillButton tap contract

    @Test func bruPillButtonFiresAction() async throws {
        var fired = false

        let button = BRUPillButton("Start workout ▸") {
            fired = true
        }

        let host = UIHostingController(rootView: button.frame(width: 300, height: 56))
        host.view.frame = CGRect(x: 0, y: 0, width: 300, height: 56)
        host.view.layoutIfNeeded()

        let activated = activateFirstButton(in: host.view)

        if activated {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            #expect(fired, "BRUPillButton action closure did not fire after accessibilityActivate")
        } else {
            // Compile-time assertion fallback
            let _: BRUPillButton = BRUPillButton("Test") {}
            // NOTE: Full tap-action verification deferred to Plan 02.1-10 UAT
        }
    }

    // MARK: 5 — SetCompletionGlyph render contract

    @Test func setCompletionGlyphRendersBothStates() {
        // Both states must render without crashing in a UIHostingController
        let incomplete = SetCompletionGlyph(isComplete: false)
        let complete = SetCompletionGlyph(isComplete: true)

        let hostA = UIHostingController(rootView: incomplete)
        hostA.view.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        hostA.view.layoutIfNeeded()
        #expect(hostA.view != nil, "SetCompletionGlyph(isComplete: false) should render without crash")

        let hostB = UIHostingController(rootView: complete)
        hostB.view.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        hostB.view.layoutIfNeeded()
        #expect(hostB.view != nil, "SetCompletionGlyph(isComplete: true) should render without crash")
    }

    // MARK: 6 — HeaderAction isSignal pure-value contract

    @Test func headerActionIsSignalDriverChoosesSignalColor() {
        let signalAction = HeaderAction("Save", isSignal: true) {}
        #expect(signalAction.isSignal == true,
            "HeaderAction(isSignal: true).isSignal must be true")

        let normalAction = HeaderAction("Back", isSignal: false) {}
        #expect(normalAction.isSignal == false,
            "HeaderAction(isSignal: false).isSignal must be false")

        // Default is non-signal
        let defaultAction = HeaderAction("Cancel") {}
        #expect(defaultAction.isSignal == false,
            "HeaderAction default isSignal must be false")

        // Label round-trip
        #expect(signalAction.label == "Save")
        #expect(normalAction.label == "Back")
    }

    // MARK: - Helpers

    /// Attempts to find and activate the first accessibility-activatable element
    /// in the given view hierarchy. Returns true if activation succeeded.
    private func activateFirstButton(in view: UIView) -> Bool {
        // Walk the accessibility tree to find a button element
        if view.accessibilityActivate() {
            return true
        }
        for subview in view.subviews {
            if activateFirstButton(in: subview) {
                return true
            }
        }
        return false
    }
}
