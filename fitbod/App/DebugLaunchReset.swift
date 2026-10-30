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
//  Add `-fitbod-reset-signal` to let a UI test confirm the reset: the app
//  then puts an invisible accessibility element, `debug.resetSignal`, in
//  its window. Its value is "fresh" when this launch reset the store and
//  left nothing behind, or "not fresh: " and the reason. The launch
//  helpers in fitbodUITests/UITestNavigation.swift pass it every time.
//
//  Compiled out of release builds.
//

import Foundation
#if DEBUG
import UIKit
#endif

enum DebugLaunchReset {
    static let launchArgument = "-fitbod-reset-store"

    #if DEBUG
    static let signalArgument = "-fitbod-reset-signal"
    static let signalIdentifier = "debug.resetSignal"
    #endif

    /// Called from `fitbodApp.init` before `FitbodModelContainer.make()`.
    static func runIfRequested() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let resets = arguments.contains(launchArgument)
        let signals = arguments.contains(signalArgument)
        guard resets || signals, let domain = Bundle.main.bundleIdentifier else { return }
        let storeURL = FitbodModelContainer.defaultStoreURL
        if resets {
            reset(storeURL: storeURL, defaults: .standard, domain: domain)
        }
        if signals {
            publishSignal(freshness(afterReset: resets, storeURL: storeURL, defaults: .standard, domain: domain))
        }
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

    /// What the reset signal reports: "fresh" only when this launch ran the
    /// reset and it left no store file and no saved default behind.
    static func freshness(afterReset didReset: Bool, storeURL: URL, defaults: UserDefaults, domain: String) -> String {
        guard didReset else { return "not fresh: no reset on this launch" }
        let fileManager = FileManager.default
        if FitbodModelContainer.storeFiles(for: storeURL).contains(where: { fileManager.fileExists(atPath: $0.path) }) {
            return "not fresh: store files survived the reset"
        }
        if !(defaults.persistentDomain(forName: domain) ?? [:]).isEmpty {
            return "not fresh: saved defaults survived the reset"
        }
        return "fresh"
    }

    /// Adds the signal to the app's window when it becomes key: a clear
    /// 1pt view that ignores touches and carries `value`.
    private static func publishSignal(_ value: String) {
        _ = NotificationCenter.default.addObserver(
            forName: UIWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { notification in
            let window = notification.object as? UIWindow
            MainActor.assumeIsolated {
                guard let window,
                      !window.subviews.contains(where: { $0.accessibilityIdentifier == signalIdentifier }) else { return }
                let signal = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
                signal.isUserInteractionEnabled = false
                signal.isAccessibilityElement = true
                signal.accessibilityIdentifier = signalIdentifier
                signal.accessibilityLabel = "Reset signal"
                signal.accessibilityValue = value
                window.addSubview(signal)
            }
        }
    }
    #endif
}
