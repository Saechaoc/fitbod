//
//  SchedulingMode.swift
//  fitbod
//
//  The scheduling mode for a Block — controls how daily slot assignment
//  works within a running block. Persisted as `schedulingModeRaw: String`
//  on `Block` (FOUND-03 / PITFALLS #9 — *Raw: String convention).
//  The field will be added to Block in a later plan (07-02).
//
//  .rotation (default): the block advances to the next slot each time
//  a session is completed, regardless of calendar day.
//  .fixedWeekly: slots are pinned to specific Calendar weekday numbers
//  stored in Block.trainingDays; a day not in trainingDays is a rest day.
//

import Foundation

public enum SchedulingMode: String, CaseIterable, Sendable {
    case rotation
    case fixedWeekly

    public static let `default`: SchedulingMode = .rotation
}
