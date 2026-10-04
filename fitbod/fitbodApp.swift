//
//  fitbodApp.swift
//  fitbod
//
//  App entry point. Single shared `ModelContainer` wired with the
//  versioned schema (SchemaV3) and `FitbodSchemaMigrationPlan`
//  (FOUND-01 / PITFALLS #2). Views consume the container via
//  `.modelContainer(_)` and use `@Query` / `@Bindable` directly
//  (MV-VM-lite per FOUND-06).
//
//  Milestone 1 additions:
//    - `ChalkAppearance.apply()` styles system chrome (navigation titles,
//      segmented controls) with the Chalkline tokens.
//    - `-reset-store` (UI tests only) deletes the on-disk store and the
//      app's defaults before the container opens, giving each journey test
//      a fresh install. See `LaunchConfiguration`.
//    - `-ui-testing` disables animations so XCUITests are deterministic.
//
//  The container is constructed synchronously in `init()` per Apple's
//  recommended pattern: failing here means the on-disk store is unusable,
//  which is unrecoverable — so `fatalError` is correct rather than silently
//  routing the app to a degraded in-memory mode.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct fitbodApp: App {
    let container: ModelContainer

    init() {
        let launch = LaunchConfiguration.current
        let schema = Schema(SchemaV3.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if launch.resetStore {
            Self.resetPersistentState(storeURL: config.url)
        }
        if launch.isUITesting {
            UIView.setAnimationsEnabled(false)
        }

        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: FitbodSchemaMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        ChalkAppearance.apply()
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(container)
    }

    /// Deletes the SQLite store (+ WAL/SHM siblings) and this app's
    /// UserDefaults domain. UI tests only.
    private static func resetPersistentState(storeURL: URL) {
        let fm = FileManager.default
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            try? fm.removeItem(at: url)
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
    }
}
