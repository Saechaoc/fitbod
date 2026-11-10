import Foundation
import Testing
@testable import fitbod

@Suite("Workout load input")
struct WorkoutLoadInputTests {
    @Test("Localized loads round-trip, including assistance", arguments: ["en_US", "de_DE", "fr_FR", "ar_EG", "sv_SE"])
    func roundTrip(localeID: String) {
        let locale = Locale(identifier: localeID)
        for value in [-12.5, 0, 7.5, 110.001, 1_234_567.89, 1_000_000_000_000] {
            #expect(WorkoutLoadInput.value(WorkoutLoadInput.text(value, locale: locale), locale: locale) == value)
        }
    }

    @Test("Comma decimals and signed assistance use the whole input")
    func commaAndAssistance() {
        let locale = Locale(identifier: "de_DE")
        #expect(WorkoutLoadInput.value("2,5", locale: locale) == 2.5)
        #expect(WorkoutLoadInput.value(" −12,5 ", locale: locale) == -12.5)
        #expect(WorkoutLoadInput.value("+12,5", locale: locale) == 12.5)
        #expect(WorkoutLoadInput.value(",5", locale: locale) == 0.5)
        #expect(WorkoutLoadInput.value("12,", locale: locale) == 12)
        #expect(WorkoutCorrectionInput.weight("-12,5", locale: locale) == nil)
    }

    @Test("Invalid, grouped, nonfinite and out-of-range loads have no parsed prefix", arguments: ["en_US", "de_DE"])
    func rejectsPrefixes(localeID: String) {
        let locale = Locale(identifier: localeID)
        for text in ["", "-", "+", ".", ",", "12oops", "1 2", "1e3", "NaN", "inf", "--2", "1,2.3", "999999999999999999999"] {
            #expect(WorkoutLoadInput.value(text, locale: locale) == nil)
        }
        let wrongSeparator = localeID == "en_US" ? "7,5" : "7.5"
        #expect(WorkoutLoadInput.value(wrongSeparator, locale: locale) == nil)
    }
}
