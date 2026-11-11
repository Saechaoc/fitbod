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
//  and in kilometers when it is kg.
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
    /// "1:30", "20:00 · 2.5 mi", "20:00 · level 8", "1:00 · 50 lb".
    /// Compact, for chips and the Last time column: "100×5", "-20×8",
    /// "20:00 2.5mi", "20:00 L8".
    static func result(
        weight: Double, reps: Int,
        durationSeconds: Int?, distanceMeters: Double?, level: Double?,
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
            parts.append(compact ? "L\(NumberText.weight(level))" : "level \(NumberText.weight(level))")
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
            unit: unit
        )
    }
}
