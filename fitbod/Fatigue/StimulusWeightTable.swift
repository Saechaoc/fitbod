//
//  StimulusWeightTable.swift
//  fitbod
//
//  Curated stimulus-weighting overrides for the top 51 compound lifts
//  per RESEARCH §6.1. Phase 5 plan 02 wires `StimulusWeightSeeder` to
//  consume this table at first launch + on update, writing onto
//  `ExerciseMuscleStimulus.weight` rows that have `userEditedWeight ==
//  false` (idempotent — never stomps user-tuned values).
//
//  Keys are canonical exercise names (lowercased, space-separated, no
//  diacritics) matching `Exercise.canonicalName` normalization already
//  shipped by the Phase 1 seeder. RESEARCH §6.1 uses snake_case YAML
//  keys (e.g. `barbell_bench_press`) — the conversion to space-separated
//  is exact: underscores → spaces.
//
//  Values: arrays of `(muscleSlug, role, weight)` triples where
//    weight ∈ [0.0, 1.0]
//    role  ∈ {"primary", "secondary"}
//  Non-curated exercises (anything not in this dictionary) keep the
//  Phase 1 seeder defaults (1.0 primary / 0.5 secondary on the
//  free-exercise-db primaryMuscles / secondaryMuscles partition).
//
//  T-05-01: the seeder enforces value clamping to [0.0, 1.0] at write
//  time. This table is authored within range; the clamp is defensive
//  for any future user-editor input route.
//
//  No SwiftData coupling. No @MainActor. Implicitly Sendable.
//

import Foundation

/// Curated stimulus weights for the top-51 compound lifts. Used by
/// `StimulusWeightSeeder` (Phase 5 plan 02) on first launch and on
/// update; rows where `ExerciseMuscleStimulus.userEditedWeight == true`
/// are skipped to preserve user tuning.
public enum StimulusWeightTable {

    /// One row of the curated table.
    public struct Entry: Sendable, Equatable {
        public let muscleSlug: String
        public let role: String
        public let weight: Double

        public init(muscleSlug: String, role: String, weight: Double) {
            self.muscleSlug = muscleSlug
            self.role = role
            self.weight = weight
        }
    }

    /// Canonical-name → curated `(muscleSlug, role, weight)` triples.
    /// 51 lifts (RESEARCH §6.1). Anything not in this dictionary uses
    /// Phase 1's 1.0-primary / 0.5-secondary defaults.
    public static let overrides: [String: [Entry]] = [

        // ─────────────────── HORIZONTAL PUSH ───────────────────
        "barbell bench press": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "dumbbell bench press": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.4),
        ],
        "incline bench press": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.6),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.4),
        ],
        "decline bench press": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.3),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "dumbbell fly": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.3),
        ],
        "cable crossover": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.3),
        ],
        "push up": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "dip": [
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
        ],

        // ─────────────────── VERTICAL PUSH ───────────────────
        "overhead press": [
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
            Entry(muscleSlug: "traps",     role: "secondary", weight: 0.4),
        ],
        "push press": [
            Entry(muscleSlug: "shoulders",  role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",    role: "secondary", weight: 0.5),
            Entry(muscleSlug: "quadriceps", role: "secondary", weight: 0.3),
        ],
        "seated dumbbell press": [
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "arnold press": [
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.4),
            Entry(muscleSlug: "chest",     role: "secondary", weight: 0.3),
        ],

        // ─────────────────── HORIZONTAL PULL ───────────────────
        "barbell row": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.4),
            Entry(muscleSlug: "lower back",  role: "secondary", weight: 0.3),
        ],
        "pendlay row": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.5),
        ],
        "dumbbell row": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.4),
        ],
        "seated cable row": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
        ],
        "chest supported row": [
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.5),
        ],
        "inverted row": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
        ],
        "face pull": [
            Entry(muscleSlug: "shoulders",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "traps",       role: "secondary", weight: 0.4),
        ],

        // ─────────────────── VERTICAL PULL ───────────────────
        "pull up": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.4),
        ],
        "chin up": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.6),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.3),
        ],
        "lat pulldown": [
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.4),
        ],
        "neutral grip pulldown": [
            Entry(muscleSlug: "lats",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps", role: "secondary", weight: 0.5),
        ],
        "straight arm pulldown": [
            Entry(muscleSlug: "lats",    role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps", role: "secondary", weight: 0.3),
        ],

        // ─────────────────── SQUAT ───────────────────
        "back squat": [
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.4),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "abdominals", role: "secondary", weight: 0.3),
        ],
        "front squat": [
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.6),
            Entry(muscleSlug: "abdominals", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.4),
        ],
        "goblet squat": [
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
            Entry(muscleSlug: "abdominals", role: "secondary", weight: 0.3),
        ],
        "bulgarian split squat": [
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.4),
        ],
        "lunge": [
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.5),
        ],
        "leg press": [
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.3),
        ],
        "hack squat": [
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.4),
        ],

        // ─────────────────── HINGE ───────────────────
        "conventional deadlift": [
            Entry(muscleSlug: "lower back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lats",       role: "secondary", weight: 0.3),
            Entry(muscleSlug: "traps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.5),
        ],
        "sumo deadlift": [
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.6),
            Entry(muscleSlug: "traps",      role: "secondary", weight: 0.4),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.5),
        ],
        "romanian deadlift": [
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.4),
        ],
        "stiff legged deadlift": [
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.6),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
        ],
        "good morning": [
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
        ],
        "hip thrust": [
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.4),
            Entry(muscleSlug: "quadriceps", role: "secondary", weight: 0.2),
        ],

        // ─────────────────── SHOULDER ISOLATION ───────────────────
        "lateral raise": [
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "traps",     role: "secondary", weight: 0.3),
        ],
        "rear delt fly": [
            Entry(muscleSlug: "shoulders",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.4),
        ],
        "front raise": [
            Entry(muscleSlug: "shoulders", role: "primary", weight: 1.0),
        ],
        "shrug": [
            Entry(muscleSlug: "traps",    role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms", role: "secondary", weight: 0.4),
        ],

        // ─────────────────── ARM ISOLATION ───────────────────
        "barbell curl": [
            Entry(muscleSlug: "biceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms", role: "secondary", weight: 0.4),
        ],
        "dumbbell curl": [
            Entry(muscleSlug: "biceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms", role: "secondary", weight: 0.4),
        ],
        "hammer curl": [
            Entry(muscleSlug: "biceps",   role: "primary", weight: 1.0),
            Entry(muscleSlug: "forearms", role: "primary", weight: 1.0),
        ],
        "preacher curl": [
            Entry(muscleSlug: "biceps", role: "primary", weight: 1.0),
        ],
        "incline dumbbell curl": [
            Entry(muscleSlug: "biceps", role: "primary", weight: 1.0),
        ],
        "tricep pushdown": [
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],
        "overhead tricep extension": [
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],
        "skullcrusher": [
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],
        "close grip bench press": [
            Entry(muscleSlug: "triceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "chest",     role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.4),
        ],
        "dumbbell kickback": [
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],

        // ─────────────────── ABS / CORE ───────────────────
        "hanging leg raise": [
            Entry(muscleSlug: "abdominals", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.3),
        ],
        "crunch": [
            Entry(muscleSlug: "abdominals", role: "primary", weight: 1.0),
        ],
        "plank": [
            Entry(muscleSlug: "abdominals", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.3),
        ],
        "ab wheel": [
            Entry(muscleSlug: "abdominals", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lats",       role: "secondary", weight: 0.3),
        ],

        // ─────────────────── CALVES ───────────────────
        "standing calf raise": [
            Entry(muscleSlug: "calves", role: "primary", weight: 1.0),
        ],
        "seated calf raise": [
            Entry(muscleSlug: "calves", role: "primary", weight: 1.0),
        ],
    ]
}
