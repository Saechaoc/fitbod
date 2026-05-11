//
//  SettingsUnitsIntegrationTests.swift
//  fitbodTests
//
//  Wave-4 plan 04-01 — SET-01 integration anchor. Proves the lb → kg
//  toggle persists across a re-fetched `ModelContext` so the
//  `SettingsView`'s `@Bindable` Toggle write-through actually survives
//  an app relaunch.
//
//  The `UserSettingsTests` suite (plan 01-03) already covers the
//  in-memory round-trip via the computed `weightUnit` setter — this
//  test adds the cross-context fetch step (mimicking the "close the
//  app, reopen, the setting is still kg" flow that's load-bearing
//  for SET-01's user-visible contract).
//

import Foundation
import SwiftData
import Testing
@testable import fitbod

@Suite("SettingsView units toggle (SET-01 integration)")
struct SettingsUnitsIntegrationTests {

    /// Flipping `weightUnit` on `UserSettings` and saving the context
    /// persists the change across a fresh `ModelContext` (same
    /// `ModelContainer`, different context — the closest in-process
    /// analog to "relaunch the app and the setting is still kg").
    @Test("Flipping weightUnit on UserSettings persists across re-fetched ModelContext (SET-01)")
    func unitsTogglePersists() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        // Seed the singleton row via the production factory.
        let settings = UserSettings.default()
        ctx.insert(settings)
        try ctx.save()

        // Initial state: lb (factory default).
        #expect(settings.weightUnit == .lb)
        #expect(settings.unitsRaw == "lb")

        // Flip to kg — this is the same code path `SettingsView`'s
        // Toggle setter invokes (`s.weightUnit = newValue ? .kg : .lb`).
        settings.weightUnit = .kg
        try ctx.save()

        // Re-fetch from a fresh ModelContext (same container) — the
        // analog of "relaunch the app, read the setting again".
        let fresh = ModelContext(container)
        let fetched = try fresh.fetch(FetchDescriptor<UserSettings>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.weightUnit == .kg)
        #expect(fetched.first?.unitsRaw == "kg")
    }

    /// And back again — flipping kg → lb persists. Ensures the
    /// Binding's set closure works in both directions, not just the
    /// forward (lb → kg) case.
    @Test("Flipping weightUnit kg → lb also persists across re-fetched ModelContext")
    func unitsToggleReversePersists() throws {
        let container = try InMemoryContainer.makeEmpty()
        let ctx = ModelContext(container)

        let settings = UserSettings.default()
        settings.weightUnit = .kg
        ctx.insert(settings)
        try ctx.save()
        #expect(settings.weightUnit == .kg)

        // Toggle back to lb.
        settings.weightUnit = .lb
        try ctx.save()

        let fresh = ModelContext(container)
        let fetched = try fresh.fetch(FetchDescriptor<UserSettings>())
        #expect(fetched.first?.weightUnit == .lb)
        #expect(fetched.first?.unitsRaw == "lb")
    }
}
