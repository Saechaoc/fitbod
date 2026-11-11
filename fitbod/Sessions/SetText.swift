//
//  SetText.swift
//  fitbod
//
//  How a set's time and distance are typed and shown, and how a logged set
//  reads outside the logger.
//
//  A logged set is described from its own stored values, never from what its
//  exercise tracks now: a row curation later retags keeps its old history
//  exactly as it was logged.
//
//  Distance is stored in meters and shown in miles when the weight unit is lb
//  and in kilometers when it is kg. A treadmill's speed is stored in km/h and
//  shown in mph or km/h the same way; a stair machine's speed is a plain
//  number, stored as a level.
//

import Foundation

enum SetText {

    // MARK: - Time

    /// "1:30", "20:00", "1:05:00".
    static func duration(_ seconds: Int) -> String {
        let (hours, minutes, rest) = (seconds / 3600, seconds % 3600 / 60, seconds % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, rest)
            : String(format: "%d:%02d", minutes, rest)
    }

    /// The seconds a typed time stands for. Digits are read from the right
    /// as seconds, minutes and hours, the way a number pad types a time:
    /// "130" is 1:30, "2000" is 20:00, "90" is 1:30, "13000" is 1:30:00.
    /// Colons are ignored. Nil for no digits, anything else, or zero.
    static func seconds(fromTyped text: String) -> Int? {
        guard let digits = Self.digits(in: text), !digits.isEmpty, digits.count <= 6,
              let number = Int(digits) else { return nil }
        let total = number / 10_000 * 3600 + number / 100 % 100 * 60 + number % 100
        return total > 0 ? total : nil
    }

    /// The ASCII digits of `text`, with its colons dropped; nil when it holds
    /// anything else.
    private static func digits(in text: String) -> String? {
        var result = ""
        for character in text where character != ":" {
            guard let digit = character.wholeNumberValue else { return nil }
            result.append(String(digit))
        }
        return result
    }

    // MARK: - Distance

    static func distanceUnit(_ unit: WeightUnit) -> String {
        unit == .lb ? "mi" : "km"
    }

    private static func metersPerUnit(_ unit: WeightUnit) -> Double {
        unit == .lb ? 1609.344 : 1000
    }

    /// Meters as miles or kilometers, with at most two decimals: "2.5".
    static func distance(_ meters: Double, unit: WeightUnit) -> String {
        NumberText.weight(distanceValue(meters, unit: unit))
    }

    private static func distanceValue(_ meters: Double, unit: WeightUnit) -> Double {
        (meters / metersPerUnit(unit) * 100).rounded() / 100
    }

    /// A distance or a level as its field shows it: in the locale it is
    /// typed in, as loads are (`WorkoutLoadInput`), so "2,5" stays "2,5".
    static func entry(distance meters: Double, unit: WeightUnit, locale: Locale) -> String {
        WorkoutLoadInput.text(distanceValue(meters, unit: unit), locale: locale)
    }

    static func entry(level: Double, locale: Locale) -> String {
        WorkoutLoadInput.text(level, locale: locale)
    }

    /// The meters a typed distance in miles or kilometers stands for.
    static func meters(fromTyped text: String, unit: WeightUnit, locale: Locale) -> Double? {
        number(fromTyped: text, locale: locale).map { $0 * metersPerUnit(unit) }
    }

    // MARK: - Speed

    /// "mph" or "km/h", following the distance unit.
    static func speedUnit(_ unit: WeightUnit) -> String {
        unit == .lb ? "mph" : "km/h"
    }

    private static func kmhPerUnit(_ unit: WeightUnit) -> Double {
        unit == .lb ? 1.609344 : 1
    }

    /// km/h as mph or km/h, with at most two decimals: "3.5".
    static func speed(_ kmh: Double, unit: WeightUnit) -> String {
        NumberText.weight(speedValue(kmh, unit: unit))
    }

    private static func speedValue(_ kmh: Double, unit: WeightUnit) -> Double {
        (kmh / kmhPerUnit(unit) * 100).rounded() / 100
    }

    /// A speed as its field shows it, in the locale it is typed in.
    static func entry(speed kmh: Double, unit: WeightUnit, locale: Locale) -> String {
        WorkoutLoadInput.text(speedValue(kmh, unit: unit), locale: locale)
    }

    /// The km/h a typed speed in mph or km/h stands for.
    static func kmh(fromTyped text: String, unit: WeightUnit, locale: Locale) -> Double? {
        number(fromTyped: text, locale: locale).map { $0 * kmhPerUnit(unit) }
    }

    /// The meters covered at `kmh` for `seconds`: a treadmill's distance,
    /// worked out from its speed and time.
    static func meters(kmh: Double, seconds: Int) -> Double {
        kmh * Double(seconds) / 3.6
    }

    /// A typed distance or level: a whole or decimal number, zero or more.
    /// The decimal mark is the locale's or a point, since values show with a
    /// point. "2." reads as 2 and ".5" as 0.5, so a half-typed value is kept.
    static func number(fromTyped text: String, locale: Locale) -> Double? {
        var text = text.replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
        if text.hasPrefix(".") { text = "0" + text }
        if text.hasSuffix(".") { text.removeLast() }
        return WorkoutCorrectionInput.weight(text, locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: - A logged set

    /// What a set recorded. In full: "100 lb × 5", "20 lb assist × 8",
    /// "1:30", "20:00 · 2.5 mi", "20:00 · level 8", "20:00 · speed 8",
    /// "30:00 · 3.5 mph · 12% incline · ~1.75 mi", "1:00 · 50 lb".
    /// Compact, for chips and the Last time column: "100×5", "-20×8",
    /// "20:00 2.5mi", "20:00 L8", "20:00 spd8", "30:00 3.5mph 12%".
    /// `tracking` is the exercise's, when known: a stair machine's level is
    /// named speed. A treadmill set's distance is worked out from its speed
    /// and time unless one was logged.
    static func result(
        weight: Double, reps: Int,
        durationSeconds: Int?, distanceMeters: Double?, level: Double?,
        speedKmh: Double? = nil, incline: Double? = nil, tracking: Tracking? = nil,
        unit: WeightUnit, compact: Bool = false
    ) -> String {
        guard reps == 0, let durationSeconds, durationSeconds > 0 else {
            if compact { return "\(NumberText.weight(weight))×\(reps)" }
            return weight < 0
                ? "\(NumberText.weight(-weight)) \(unit.rawValue) assist × \(reps)"
                : "\(NumberText.weight(weight)) \(unit.rawValue) × \(reps)"
        }
        var parts = [duration(durationSeconds)]
        if let distanceMeters, distanceMeters > 0 {
            let value = distance(distanceMeters, unit: unit)
            parts.append(compact ? value + distanceUnit(unit) : "\(value) \(distanceUnit(unit))")
        }
        if let level {
            let isSpeed = tracking == .durationStepSpeed
            parts.append(compact
                ? "\(isSpeed ? "spd" : "L")\(NumberText.weight(level))"
                : "\(isSpeed ? "speed" : "level") \(NumberText.weight(level))")
        }
        if let speedKmh, speedKmh > 0 {
            let value = speed(speedKmh, unit: unit)
            parts.append(compact ? value + speedUnit(unit) : "\(value) \(speedUnit(unit))")
        }
        if let incline {
            let value = NumberText.weight(incline)
            parts.append(compact ? "\(value)%" : "\(value)% incline")
        }
        if !compact, (distanceMeters ?? 0) <= 0, let speedKmh, speedKmh > 0 {
            let value = distance(meters(kmh: speedKmh, seconds: durationSeconds), unit: unit)
            parts.append("~\(value) \(distanceUnit(unit))")
        }
        if weight > 0 {
            parts.append(compact ? NumberText.weight(weight) : "\(NumberText.weight(weight)) \(unit.rawValue)")
        }
        return parts.joined(separator: compact ? " " : " · ")
    }
}

extension SetEntry {
    /// The set as `SetText.result` reads it.
    func resultText(unit: WeightUnit, compact: Bool = false) -> String {
        SetText.result(
            weight: weight, reps: reps,
            durationSeconds: durationSeconds, distanceMeters: distanceMeters, level: level,
            speedKmh: speedKmh, incline: incline, tracking: sessionExercise?.exercise?.tracking,
            unit: unit, compact: compact
        )
    }
}

extension SessionSummary.LoggedSet {
    /// The set as `SetText.result` reads it.
    func resultText(unit: WeightUnit) -> String {
        SetText.result(
            weight: weight, reps: reps,
            durationSeconds: durationSeconds, distanceMeters: distanceMeters, level: level,
            speedKmh: speedKmh, incline: incline, tracking: tracking,
            unit: unit
        )
    }
}

// MARK: - A cardio plan

/// A cardio exercise's plan (RM-062): one bout of a time, at a level or a
/// stair speed, or a treadmill's speed and incline. A routine row, its draft
/// and a logged exercise each hold one.
protocol CardioPlan: AnyObject {
    var targetDurationSeconds: Int? { get }
    var targetLevel: Double? { get }
    var targetSpeedKmh: Double? { get }
    var targetIncline: Double? { get }
}

extension CardioPlan {
    /// The plan in one line, "20 min · speed 8" or "30 min · 3.5 mph ·
    /// 12% incline", or nil when nothing is planned.
    func planText(tracking: Tracking?, unit: WeightUnit) -> String? {
        let parts = planParts(tracking: tracking, unit: unit)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The plan's values, each as it reads on its own: "20 min", "speed 8".
    func planParts(tracking: Tracking?, unit: WeightUnit) -> [String] {
        var parts: [String] = []
        if let seconds = targetDurationSeconds, seconds > 0 {
            parts.append(seconds % 60 == 0 ? "\(seconds / 60) min" : SetText.duration(seconds))
        }
        if let level = targetLevel {
            parts.append("\(tracking?.levelName ?? "level") \(NumberText.weight(level))")
        }
        if let speed = targetSpeedKmh, speed > 0 {
            parts.append("\(SetText.speed(speed, unit: unit)) \(SetText.speedUnit(unit))")
        }
        if let incline = targetIncline {
            parts.append("\(NumberText.weight(incline))% incline")
        }
        return parts
    }

    /// The planned time in seconds, for a session's estimated length.
    var plannedSeconds: Int { max(0, targetDurationSeconds ?? 0) }
}

extension SessionExerciseTemplate: CardioPlan {}
extension SessionExercise: CardioPlan {}
extension RoutineExerciseDraft: CardioPlan {}
