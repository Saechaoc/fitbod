//
//  NumberText.swift
//  fitbod
//
//  How the app prints a lifter's numbers: weights as they were typed, and
//  clock times for rests and workouts. Shared with the widget extension.
//

import Foundation

enum NumberText {
    /// A weight as the lifter typed it: "100", "102.5", "101.25". Whole
    /// numbers drop the decimal point; others keep only the digits they
    /// need.
    static func weight(_ value: Double) -> String {
        if let whole = Int(exactly: value) { return String(whole) }
        return String(format: "%g", value)
    }

    /// Minutes and seconds, such as "3:00" for 180 seconds, the way the
    /// rest timer counts. Minutes run past 59.
    static func minutesSeconds(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// A workout's running time: minutes and seconds below an hour
    /// ("14:32"), hours and minutes from an hour on ("1:05").
    static func elapsed(_ seconds: Int) -> String {
        seconds < 3600
            ? minutesSeconds(seconds)
            : String(format: "%d:%02d", seconds / 3600, (seconds % 3600) / 60)
    }
}
