//
//  DebugLaunchReset.swift
//  fitbod
//
//  DEBUG-only E2E hook. Launch with `-fitbod-reset-store` to start as a
//  fresh install: the store files are deleted and the app's UserDefaults
//  domain (seed stamps, rest timer deadline) is cleared before the
//  container is built, so the exercise library re-seeds into an empty
//  store. UI tests pass it on the first launch and drop it to relaunch:
//
//    app.launchArguments = [DebugLaunchReset.launchArgument]
//    app.launch()
//    ...
//    app.terminate()
//    app.launchArguments = []
//    app.launch()   // same data, now read back from disk
//
//  Compiled out of release builds.
//

import Foundation

enum DebugLaunchReset {
    static let launchArgument = "-fitbod-reset-store"

    /// Called from `fitbodApp.init` before `FitbodModelContainer.make()`.
    static func runIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains(launchArgument),
              let domain = Bundle.main.bundleIdentifier else { return }
        reset(storeURL: FitbodModelContainer.defaultStoreURL, defaults: .standard, domain: domain)
        #endif
    }

    #if DEBUG
    /// Deletes the store files at `storeURL` and every value in `domain`.
    static func reset(storeURL: URL, defaults: UserDefaults, domain: String) {
        for file in FitbodModelContainer.storeFiles(for: storeURL) {
            // A missing file is the normal case on a first launch.
            try? FileManager.default.removeItem(at: file)
        }
        defaults.removePersistentDomain(forName: domain)
    }
    #endif
}
