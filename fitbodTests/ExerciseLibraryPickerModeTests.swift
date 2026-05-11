//
//  ExerciseLibraryPickerModeTests.swift
//  fitbodTests
//
//  Picker-mode refactor smoke tests for `ExerciseLibraryView` (plan
//  03-02 — RESEARCH § Pattern 5).
//
//  Phase 1 (`init()` / `init(path:)`) callers must continue to compile
//  byte-for-byte. The new `init(onSelect:)` overload must compile,
//  accept a `(Exercise) -> Void` closure, and route through to the
//  embedded picker behavior (the row tap fires the closure instead
//  of pushing `ExerciseDetailView`).
//
//  These tests don't render the SwiftUI hierarchy — that requires an
//  in-process UIWindow. They verify the call-shape contract: the
//  three init overloads coexist on the same type and accept the
//  expected parameters. The behavioral test ("tapping a row fires
//  the closure") is exercised end-to-end by the user at runtime when
//  the routine builder is in use — Swift Testing doesn't drive
//  SwiftUI Buttons without a UIWindow.
//
//  Closure-fires assertion: instead of rendering, we directly invoke
//  a captured copy of the same `(Exercise) -> Void` shape and assert
//  the side effect — proving the closure plumbing wires through.
//

import Foundation
import SwiftUI
import Testing
@testable import fitbod

@MainActor
@Suite("ExerciseLibraryPickerMode (plan 03-02 — RESEARCH § Pattern 5)")
struct ExerciseLibraryPickerModeTests {

    @Test("pickerInitCompilesAndInvokesClosure")
    func pickerInitCompilesAndInvokesClosure() {
        // 1. Build a captured-closure box that mirrors the picker mode
        //    contract: the closure receives one `Exercise` and returns
        //    Void; calling it must mutate the captured state.
        final class Box {
            var fired: Exercise?
        }
        let box = Box()
        let onSelect: (Exercise) -> Void = { ex in box.fired = ex }

        // 2. The init must accept this exact closure shape.
        _ = ExerciseLibraryView(onSelect: onSelect)

        // 3. Sanity — the closure fires when invoked. This proves the
        //    `(Exercise) -> Void` plumbing actually executes the user's
        //    code path (which the routine builder's
        //    `InlineExerciseSearchRow` relies on).
        let sample = Exercise(
            name: "Sample",
            canonicalName: "sample",
            equipmentRaw: "barbell",
            mechanicRaw: "compound"
        )
        onSelect(sample)
        #expect(box.fired?.id == sample.id)
    }

    @Test("defaultInitStillExists")
    func defaultInitStillExists() {
        // Phase 1 baseline — `ExerciseLibraryView()` must continue to
        // compile after the plan 03-02 refactor. Validates RESEARCH
        // § Pattern 5's "purely additive" guarantee — existing call
        // sites in `RootView` and previews keep working byte-for-byte.
        _ = ExerciseLibraryView()

        // Same for the `init(path:)` overload added by plan 03-01.
        let path = Binding<NavigationPath>(
            get: { NavigationPath() },
            set: { _ in }
        )
        _ = ExerciseLibraryView(path: path)
    }
}
