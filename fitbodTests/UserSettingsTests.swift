//
//  UserSettingsTests.swift
//  fitbodTests
//
//  Anchors SET-01 — the lb ↔ kg units toggle is persisted via
//  `UserSettings.unitsRaw: String` and round-trips correctly through
//  insert + save + fetch.
//
//  Also covers `defaultProgressionKindRaw` round-trip (same shape) so
//  the two read/write computed accessors on `UserSettings` are both
//  proven before Phase 3 starts wiring them into the Settings UI.
//
//  Uses `UserSettings.default()` factory (not the no-arg `init()`) to
//  prove the factory returns a row in the lb default. Then mutates
//  via the computed `weightUnit` setter (which is the same code path
//  the `@Bindable` Toggle in `SettingsView` will hit in Wave 3).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("UserSettings")
struct UserSettingsTests {

    // MARK: - SET-01 anchor: lb → kg toggle round-trips

    @Test("default() returns lb, and the kg toggle round-trips (SET-01)")
    func unitsToggle() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()

        // Initial state: lb (default factory).
        var fetched = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.unitsRaw == "lb")
        #expect(fetched.first?.weightUnit == .lb)

        // Toggle to kg via the computed setter (the SettingsView path).
        fetched.first?.weightUnit = .kg
        try ctx.save()

        let after = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(after.first?.unitsRaw == "kg")
        #expect(after.first?.weightUnit == .kg)
    }

    // MARK: - default progression kind toggle round-trips

    @Test("defaultProgressionKind toggle round-trips")
    func defaultProgressionKindToggle() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()

        // Initial state from the default() factory: `double`.
        var fetched = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(fetched.first?.defaultProgressionKindRaw == "double")
        #expect(fetched.first?.defaultProgressionKind == .double)

        // Toggle to rpe via the computed setter.
        fetched.first?.defaultProgressionKind = .rpe
        try ctx.save()

        let after = try ctx.fetch(FetchDescriptor<UserSettings>())
        #expect(after.first?.defaultProgressionKindRaw == "rpe")
        #expect(after.first?.defaultProgressionKind == .rpe)
    }

    // MARK: - default() factory sets sensible v1 defaults

    @Test("default() factory ships lb units and double progression")
    func factoryDefaults() {
        let settings = UserSettings.default()
        #expect(settings.weightUnit == .lb)
        #expect(settings.defaultProgressionKind == .double)
        // Other fields keep their @Model-declared defaults — sanity
        // check a representative subset.
        #expect(settings.plateauWindowSessions == 4)
        #expect(settings.deloadAlertEnabled == true)
        #expect(settings.weekStartsMonday == true)
    }
}
