//
//  fitbodApp.swift
//  fitbod
//
//  App entry point. Single shared `ModelContainer` built by
//  `FitbodModelContainer.make()` from the baseline schema (`SchemaV7`)
//  with no migration plan: additive changes migrate automatically, and an
//  incompatible on-disk store is moved aside into
//  `IncompatibleStores/<timestamp>/` before a fresh store is created.
//
//  The container is constructed synchronously in `init()`. `make()` only
//  throws when even the fresh store cannot be built, which is unrecoverable,
//  so a `fatalError` is correct rather than silently routing the app to a
//  degraded in-memory mode.
//
//  Views consume the container via `.modelContainer(_)` environment
//  injection, then use `@Query` / `@Bindable` directly against the schema
//  (MV-VM-lite per FOUND-06).
//

import SwiftUI
import SwiftData

@main
struct fitbodApp: App {
    let container: ModelContainer

    init() {
        DebugLaunchReset.runIfRequested()
        do {
            container = try FitbodModelContainer.make()
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
            .modelContainer(container)
    }
}
