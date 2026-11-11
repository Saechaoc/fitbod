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
//  The container is opened synchronously in `init()`. When `make()` throws,
//  the store files are still on the phone, so the app shows
//  `StoreOpenFailedView` instead of crashing or running on an empty store.
//  Its "Try again" button calls `make()` again, and a retry that works
//  shows the app with the same workouts.
//
//  Views consume the container via `.modelContainer(_)` environment
//  injection, then use `@Query` / `@Bindable` directly against the schema
//  (MV-VM-lite per FOUND-06).
//

import SwiftUI
import SwiftData
import MetricKit

@main
struct fitbodApp: App {
    /// The open store, or why it did not open.
    @State private var store: Result<ModelContainer, any Error>

    init() {
        DebugLaunchReset.runIfRequested()
        MXMetricManager.shared.add(DiagnosticsStore.shared)
        _store = State(initialValue: Self.openStore())
    }

    var body: some Scene {
        WindowGroup {
            switch store {
            case .success(let container):
                RootView().modelContainer(container)
            case .failure(let error):
                StoreOpenFailedView(error: error) { store = Self.openStore() }
            }
        }
    }

    private static func openStore() -> Result<ModelContainer, any Error> {
        Result { try FitbodModelContainer.make() }
    }
}
