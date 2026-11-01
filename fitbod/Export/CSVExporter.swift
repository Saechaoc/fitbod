//
//  CSVExporter.swift
//  fitbod
//
//  Wave-4 plan 06-09b — one-row-per-`SetEntry` CSV emitter (EXP-01 +
//  CONTEXT D-25..D-27).
//
//  ## Output shape
//
//  - UTF-8 with BOM (`EF BB BF`) — Excel opens UTF-8 CSVs correctly
//    only when the BOM is present (Microsoft docs + Apple Numbers
//    parity).
//  - 23 columns in CONTEXT D-25 verbatim order (see headerColumns
//    below).
//  - RFC 4180 quoting: fields containing `,` `"` `\r` `\n` are wrapped
//    in double quotes; embedded `"` is escaped as `""`. Line terminator
//    is `\r\n` per RFC 4180.
//  - Dates emitted as ISO-8601 UTC with trailing `Z`.
//  - Booleans emit as `true`/`false`. Optionals emit as the literal
//    empty string (NOT the word "nil").
//
//  ## Schema field mapping (RESEARCH §"Schema reality vs CONTEXT")
//
//  | CSV column         | Real field |
//  | session_id         | sessionExercise.session?.id?.uuidString |
//  | session_started_at | sessionExercise.session?.startedAt (ISO-8601 UTC) |
//  | session_completed_at | sessionExercise.session?.completedAt (ISO-8601 UTC, "" if nil) |
//  | session_intent     | sessionExercise.session?.intentRaw |
//  | routine_id         | sessionExercise.session?.sourceRoutineID?.uuidString ("" if nil) |
//  | routine_name       | sessionExercise.session?.routineSnapshotName |
//  | exercise_id        | sessionExercise.exercise?.id?.uuidString ("" if nil) |
//  | exercise_name      | sessionExercise.displayName (snapshot before live name) |
//  | set_index          | setEntry.orderIndex |
//  | set_kind           | setEntry.setTypeRaw |
//  | target_weight      | sessionExercise.prescribedWeight ("" if nil) |
//  | target_reps        | "{repsLow}-{repsHigh}" composite |
//  | target_rpe         | sessionExercise.targetRPE ("" if nil) |
//  | actual_weight      | setEntry.weight |
//  | actual_reps        | setEntry.reps |
//  | actual_rpe         | setEntry.rpe ("" if nil) |
//  | was_manual_override| setEntry.wasManualOverride (true/false) |
//  | partial_reps       | setEntry.partialReps ("" if nil) |
//  | tempo              | setEntry.tempoActual ("" if nil) |
//  | rest_taken_sec     | setEntry.restAfterSeconds ("" if nil) |
//  | e1rm               | OneRepMax.estimate(weight:reps:) ("" if nil per PROG-02) |
//  | set_note           | setEntry.notes ("" if nil) |
//  | unit               | UserSettings.unitsRaw ("kg" / "lb") |
//
//  [CITED: CONTEXT D-25/D-26 + RESEARCH §Don't Hand-Roll RFC 4180 +
//   Pitfall 8 ISO-8601 timezone defaults]
//

import Foundation
import SwiftData

public enum CSVExporter {

    // MARK: - Constants

    /// Column order per CONTEXT D-25 — verbatim.
    public static let headerColumns: [String] = [
        "session_id", "session_started_at", "session_completed_at",
        "session_intent", "routine_id", "routine_name",
        "exercise_id", "exercise_name", "set_index", "set_kind",
        "target_weight", "target_reps", "target_rpe",
        "actual_weight", "actual_reps", "actual_rpe",
        "was_manual_override", "partial_reps", "tempo",
        "rest_taken_sec", "e1rm", "set_note", "unit",
    ]

    /// UTF-8 BOM bytes — emitted at the very start of every CSV.
    public static let utf8BOM: [UInt8] = [0xEF, 0xBB, 0xBF]

    // MARK: - Public API

    /// Render the given `[SetEntry]` to a UTF-8 BOM + RFC 4180 CSV byte
    /// stream. `userSettings` provides the `unit` column value (the app
    /// default when nil); an exercise's own unit wins for its rows.
    public static func render(setEntries: [SetEntry], userSettings: UserSettings?) -> Data {
        let unit = userSettings?.unitsRaw ?? WeightUnit.default.rawValue
        var lines: [String] = []
        lines.append(headerColumns.map(rfc4180Quote).joined(separator: ","))
        for entry in setEntries {
            let rowUnit = entry.sessionExercise?.exercise?.unitOverride?.rawValue ?? unit
            lines.append(rowFor(entry: entry, unit: rowUnit))
        }
        let body = lines.joined(separator: "\r\n") + "\r\n"
        var data = Data(utf8BOM)
        if let utf8 = body.data(using: .utf8) {
            data.append(utf8)
        }
        return data
    }

    // MARK: - Row building

    private static func rowFor(entry: SetEntry, unit: String) -> String {
        let se = entry.sessionExercise
        let session = se?.session

        let sessionID = session?.id.uuidString ?? ""
        let startedAt = session.map { formatISO($0.startedAt) } ?? ""
        let completedAt = session?.completedAt.map(formatISO) ?? ""
        let sessionIntent = session?.intentRaw ?? ""
        let routineID = session?.sourceRoutineID?.uuidString ?? ""
        let routineName = session?.routineSnapshotName ?? ""
        let exerciseID = se?.exercise?.id.uuidString ?? ""
        let exerciseName = se?.displayName ?? ""

        let setIndex = String(entry.orderIndex)
        let setKind = entry.setTypeRaw

        let targetWeight = se?.prescribedWeight.map(formatDouble) ?? ""
        let targetReps: String
        if let lo = se?.targetRepsLow, let hi = se?.targetRepsHigh {
            targetReps = "\(lo)-\(hi)"
        } else {
            targetReps = ""
        }
        let targetRPE = se?.targetRPE.map(formatDouble) ?? ""

        let actualWeight = formatDouble(entry.weight)
        let actualReps = String(entry.reps)
        let actualRPE = entry.rpe.map(formatDouble) ?? ""

        let wasManualOverride = entry.wasManualOverride ? "true" : "false"
        let partialReps = entry.partialReps.map(String.init) ?? ""
        let tempo = entry.tempoActual ?? ""
        let restTaken = entry.restAfterSeconds.map(String.init) ?? ""

        let e1rm: String
        if let estimate = OneRepMax.estimate(weight: entry.weight, reps: entry.reps) {
            e1rm = formatDouble(estimate)
        } else {
            e1rm = ""
        }

        let setNote = entry.notes ?? ""

        let columns: [String] = [
            sessionID, startedAt, completedAt,
            sessionIntent, routineID, routineName,
            exerciseID, exerciseName, setIndex, setKind,
            targetWeight, targetReps, targetRPE,
            actualWeight, actualReps, actualRPE,
            wasManualOverride, partialReps, tempo,
            restTaken, e1rm, setNote, unit,
        ]
        return columns.map(rfc4180Quote).joined(separator: ",")
    }

    // MARK: - Helpers

    /// Wraps any field containing a delimiter, quote, or newline in
    /// double quotes; escapes embedded double quotes as `""`.
    static func rfc4180Quote(_ value: String) -> String {
        let needsQuoting = value.contains(",")
            || value.contains("\"")
            || value.contains("\r")
            || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    /// ISO-8601 UTC formatter — Foundation's `.iso8601` format style
    /// emits `YYYY-MM-DDTHH:MM:SSZ` with explicit UTC `Z` suffix by
    /// default. Verified against `Date(timeIntervalSince1970: 1_700_000_000)`
    /// → "2023-11-14T22:13:20Z" (Apple platforms 2026-05-23).
    static func formatISO(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    /// `Double` formatter — emits compact representation; integer
    /// values render without a fractional component, decimals render
    /// the natural precision via `%g`.
    static func formatDouble(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }
}
