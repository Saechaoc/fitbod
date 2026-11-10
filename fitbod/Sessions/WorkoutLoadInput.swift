import Foundation

/// Workout loads also allow signed assistance; history corrections keep their stricter rules.
enum WorkoutLoadInput {
    static func value(_ text: String, locale: Locale) -> Double? {
        // Number formatting can put directional marks around a sign.
        var number = text.filter { !"\u{061c}\u{200e}\u{200f}".contains($0) }
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let negative = number.first == "-" || number.first == "−"
        if negative || number.first == "+" { number.removeFirst() }
        let separator = locale.decimalSeparator ?? "."
        guard !number.isEmpty, number != separator else { return nil }
        if number.hasPrefix(separator) { number = "0" + number }
        if number.hasSuffix(separator) { number += "0" }
        guard let magnitude = WorkoutCorrectionInput.weight(number, locale: locale) else { return nil }
        return negative ? -magnitude : magnitude
    }

    static func text(_ value: Double, locale: Locale) -> String {
        WorkoutCorrectionInput.weightText(value, locale: locale)
    }
}
