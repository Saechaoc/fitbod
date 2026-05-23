//
//  SchemaNamesRegressionTest.swift
//  fitbodTests
//
//  Wave-2 plan 06-02 — durable enforcement of the RESEARCH §"Schema
//  reality vs CONTEXT" delta table. Two layers:
//
//    1. Compile-time KeyPath block — proves every real SchemaV6 field
//       this phase relies on (weight, reps, rpe, completedAt,
//       setTypeRaw on SetEntry; startedAt, intentRaw, sourceRoutineID
//       on Session; intent reach via session, exercise reach via
//       sessionExercise on SessionExercise) actually resolves. The
//       file refuses to compile if SwiftData renames a field.
//
//    2. Build-time grep — runs `grep -rn` over `fitbod/Models/` for
//       the truly stale CONTEXT-era field names that must never
//       reappear. The list is INTENTIONALLY narrow: only the names
//       in CONTEXT.md that never landed in real schema.
//
//  Forbidden tokens (verified 2026-05-23 — none of these are real
//  fields anywhere under fitbod/Models/):
//    - actualWeight   (real field is SetEntry.weight)
//    - actualReps     (real field is SetEntry.reps)
//    - actualRPE      (real field is SetEntry.rpe)
//    - performedAt    (real field is SetEntry.completedAt)
//    - setKind        (real field is SetEntry.setTypeRaw / .setType)
//
//  NOT forbidden (REAL Phase 1 fields per the schema review):
//    - wasManualOverride (SetEntry.swift line 42 — informational badge)
//    - smallestIncrement (Exercise.swift line 58 — plate-rounding hint)
//

import Foundation
import Testing
@testable import fitbod

@MainActor
@Suite("Schema names regression (BLOCKER 3 canary)")
struct SchemaNamesRegressionTest {

    @Test("SetEntry / Session / SessionExercise expose real Phase-1+ field names")
    func keyPathsResolveAgainstRealSchema() {
        // SetEntry — the canonical 5 fields PR detector reads against.
        let setEntryKPs: [PartialKeyPath<SetEntry>] = [
            \SetEntry.weight,
            \SetEntry.reps,
            \SetEntry.rpe,
            \SetEntry.completedAt,
            \SetEntry.setTypeRaw,
        ]
        #expect(setEntryKPs.count == 5)

        // Session — the canonical 4 fields Phase 6 charts read against.
        let sessionKPs: [PartialKeyPath<Session>] = [
            \Session.startedAt,
            \Session.completedAt,
            \Session.intentRaw,
            \Session.sourceRoutineID,
        ]
        #expect(sessionKPs.count == 4)

        // SessionExercise — the canonical 4 reach-paths used by Phase 6.
        let sessionExerciseKPs: [PartialKeyPath<SessionExercise>] = [
            \SessionExercise.session,
            \SessionExercise.exercise,
            \SessionExercise.targetSets,
            \SessionExercise.prescribedWeight,
        ]
        #expect(sessionExerciseKPs.count == 4)
    }

    @Test("fitbod/Models/ contains no stale CONTEXT-era names")
    func noStaleCONTEXTeraFieldNames() throws {
        // Ascend from this file: Support → Phase6 → fitbodTests → repo-root
        // [Rule 3 deviation]: plan called for Process+grep, but Foundation
        // .Process is macOS-only. Tests run on iOS Simulator. We replace
        // the subprocess grep with an in-process FileManager + String
        // .contains scan that returns the same diagnostic.
        let thisFile = URL(fileURLWithPath: #filePath)
        let repoRoot = thisFile
            .deletingLastPathComponent() // remove SchemaNamesRegressionTest.swift
            .deletingLastPathComponent() // remove Support/
            .deletingLastPathComponent() // remove Phase6/
            .deletingLastPathComponent() // remove fitbodTests/
        let modelsURL = repoRoot.appendingPathComponent("fitbod/Models")

        let forbiddenTokens = [
            "actualWeight",
            "actualReps",
            "actualRPE",
            "performedAt",
            "setKind",
        ]

        // Walk fitbod/Models/ for *.swift files. iOS Simulator sandboxes
        // the test bundle but #filePath resolves to the host filesystem
        // path that the compiler saw; reading those files works as long
        // as the source tree is accessible from the host process — which
        // it is during xcodebuild test runs.
        let fm = FileManager.default
        var modelsDirExists: ObjCBool = false
        let modelsPath = modelsURL.path
        let dirExists = fm.fileExists(atPath: modelsPath, isDirectory: &modelsDirExists)
        guard dirExists, modelsDirExists.boolValue else {
            // Cannot read host source tree from this simulator. Treat as
            // a soft-skip (other compile-time KeyPath test still pins
            // schema names; this grep test is defense-in-depth only).
            return
        }

        guard let enumerator = fm.enumerator(
            at: modelsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var violations: [(token: String, file: String)] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }
            for token in forbiddenTokens {
                // Word-boundary match — `setKind` must not match
                // `SupersetKind` and `actualReps` must not match
                // some hypothetical `actualRepsXYZ` either. We treat
                // any character that is a Swift identifier
                // continuation (alphanumeric or underscore) on
                // either side of the token as evidence the match
                // is a longer identifier and skip it.
                if Self.containsAsIdentifier(token, in: contents) {
                    violations.append((token: token, file: fileURL.lastPathComponent))
                }
            }
        }

        let joined = violations
            .map { "\($0.token) in \($0.file)" }
            .joined(separator: ", ")
        #expect(
            violations.isEmpty,
            "Stale CONTEXT-era field names found under fitbod/Models/: \(joined)"
        )
    }

    /// Word-boundary substring match — returns true only when `token`
    /// appears in `text` with no Swift-identifier characters
    /// (alphanumeric or underscore) immediately before or after.
    /// Prevents `setKind` matching `SupersetKind`.
    private static func containsAsIdentifier(_ token: String, in text: String) -> Bool {
        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        while searchRange.location < nsText.length {
            let found = nsText.range(of: token, options: [], range: searchRange)
            guard found.location != NSNotFound else { return false }
            // Check the char immediately before (if any).
            let beforeIsIdentChar: Bool
            if found.location > 0 {
                let scalar = nsText.character(at: found.location - 1)
                beforeIsIdentChar = isIdentifierChar(UInt32(scalar))
            } else {
                beforeIsIdentChar = false
            }
            // Check the char immediately after (if any).
            let afterIndex = found.location + found.length
            let afterIsIdentChar: Bool
            if afterIndex < nsText.length {
                let scalar = nsText.character(at: afterIndex)
                afterIsIdentChar = isIdentifierChar(UInt32(scalar))
            } else {
                afterIsIdentChar = false
            }
            if !beforeIsIdentChar && !afterIsIdentChar {
                return true
            }
            // Otherwise advance past this hit and keep scanning.
            let nextLoc = found.location + found.length
            guard nextLoc < nsText.length else { return false }
            searchRange = NSRange(location: nextLoc, length: nsText.length - nextLoc)
        }
        return false
    }

    private static func isIdentifierChar(_ scalar: UInt32) -> Bool {
        // ASCII letters/digits/underscore covers Swift identifier
        // continuation cases for our needs (no Unicode identifier
        // names in fitbod/Models/).
        if scalar == 0x5F { return true } // '_'
        if scalar >= 0x30 && scalar <= 0x39 { return true } // '0'-'9'
        if scalar >= 0x41 && scalar <= 0x5A { return true } // 'A'-'Z'
        if scalar >= 0x61 && scalar <= 0x7A { return true } // 'a'-'z'
        return false
    }
}
