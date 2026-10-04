//
//  LaunchConfiguration.swift
//  fitbod
//
//  Launch-argument switches used by XCUITests (and handy for manual QA).
//  None of them are set in a normal launch from Xcode or the Home Screen.
//
//    -ui-testing           Hermetic side effects: no notification
//                          permission prompt, no Live Activities, no
//                          animations.
//    -reset-store          Delete the SwiftData store and app defaults
//                          before the container opens (fresh install).
//    -seed-demo-history    After the exercise seed, insert two demo
//                          routines and three weeks of finished workouts
//                          (only when the store has no routines yet).
//
//  The rest timer and the active workout still persist normally under
//  -ui-testing, which is what lets the journey test terminate and
//  relaunch the app to prove resume works.
//

import Foundation

public struct LaunchConfiguration: Sendable {
    public let isUITesting: Bool
    public let resetStore: Bool
    public let seedDemoHistory: Bool

    public init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        isUITesting = arguments.contains("-ui-testing")
        resetStore = arguments.contains("-reset-store")
        seedDemoHistory = arguments.contains("-seed-demo-history")
    }

    public static let current = LaunchConfiguration()
}
