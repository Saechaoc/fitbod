//
//  StimulusWeightTable.swift
//  fitbod
//
//  Curated stimulus-weighting overrides for 57 common lifts
//  per RESEARCH §6.1. Phase 5 plan 02 wires `StimulusWeightSeeder` to
//  consume this table at first launch + on update, writing onto
//  `ExerciseMuscleStimulus.weight` rows that have `userEditedWeight ==
//  false` (idempotent — never stomps user-tuned values).
//
//  Keys are catalog IDs (`Exercise.externalID`), which a rename never
//  changes (RM-022); the comment after each names the lift RESEARCH §6.1
//  curates.
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

/// Curated stimulus weights for 57 common lifts. Used by
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

    /// Catalog ID → curated `(muscleSlug, role, weight)` triples
    /// (RESEARCH §6.1). Anything not in this dictionary uses Phase 1's
    /// 1.0-primary / 0.5-secondary defaults.
    public static let overrides: [String: [Entry]] = [

        // ─────────────────── HORIZONTAL PUSH ───────────────────
        "Barbell_Bench_Press_-_Medium_Grip": [ // barbell bench press
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "Dumbbell_Bench_Press": [ // dumbbell bench press
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.4),
        ],
        "Barbell_Incline_Bench_Press_-_Medium_Grip": [ // incline bench press
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.6),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.4),
        ],
        "Decline_Barbell_Bench_Press": [ // decline bench press
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.3),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "Dumbbell_Flyes": [ // dumbbell fly
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.3),
        ],
        "Cable_Crossover": [ // cable crossover
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.3),
        ],
        "Pushups": [ // push up
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "Parallel_Bar_Dip": [ // dip
            Entry(muscleSlug: "chest",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.5),
        ],

        // ─────────────────── VERTICAL PUSH ───────────────────
        "Standing_Military_Press": [ // overhead press
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
            Entry(muscleSlug: "traps",     role: "secondary", weight: 0.4),
        ],
        "Push_Press": [ // push press
            Entry(muscleSlug: "shoulders",  role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",    role: "secondary", weight: 0.5),
            Entry(muscleSlug: "quadriceps", role: "secondary", weight: 0.3),
        ],
        "Dumbbell_Shoulder_Press": [ // seated dumbbell press
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.5),
        ],
        "Arnold_Dumbbell_Press": [ // arnold press
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps",   role: "secondary", weight: 0.4),
            Entry(muscleSlug: "chest",     role: "secondary", weight: 0.3),
        ],

        // ─────────────────── HORIZONTAL PULL ───────────────────
        "Bent_Over_Barbell_Row": [ // barbell row
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.4),
            Entry(muscleSlug: "lower back",  role: "secondary", weight: 0.3),
        ],
        "local:pendlay-row": [ // pendlay row
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.5),
        ],
        "One-Arm_Dumbbell_Row": [ // dumbbell row
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.4),
        ],
        "Seated_Cable_Rows": [ // seated cable row
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
        ],
        "Dumbbell_Incline_Row": [ // chest supported row
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders",   role: "secondary", weight: 0.5),
        ],
        "Inverted_Row": [ // inverted row
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
        ],
        "Face_Pull": [ // face pull
            Entry(muscleSlug: "shoulders",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "traps",       role: "secondary", weight: 0.4),
        ],

        // ─────────────────── VERTICAL PULL ───────────────────
        "Pullups": [ // pull up
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.4),
        ],
        "Chin-Up": [ // chin up
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.6),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.3),
        ],
        "Wide-Grip_Lat_Pulldown": [ // lat pulldown
            Entry(muscleSlug: "lats",        role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.4),
        ],
        "V-Bar_Pulldown": [ // neutral grip pulldown
            Entry(muscleSlug: "lats",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "biceps", role: "secondary", weight: 0.5),
        ],
        "Straight-Arm_Pulldown": [ // straight arm pulldown
            Entry(muscleSlug: "lats",    role: "primary",   weight: 1.0),
            Entry(muscleSlug: "triceps", role: "secondary", weight: 0.3),
        ],

        // ─────────────────── SQUAT ───────────────────
        "Barbell_Squat": [ // back squat
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.4),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "abdominals", role: "secondary", weight: 0.3),
        ],
        "Front_Barbell_Squat": [ // front squat
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.6),
            Entry(muscleSlug: "abdominals", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.4),
        ],
        "Goblet_Squat": [ // goblet squat
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
            Entry(muscleSlug: "abdominals", role: "secondary", weight: 0.3),
        ],
        "One_Leg_Barbell_Squat": [ // bulgarian split squat
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.4),
        ],
        "Dumbbell_Lunges": [ // lunge
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.5),
        ],
        "Leg_Press": [ // leg press
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.3),
        ],
        "Hack_Squat": [ // hack squat
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.4),
        ],

        // ─────────────────── HINGE ───────────────────
        "Barbell_Deadlift": [ // conventional deadlift
            Entry(muscleSlug: "lower back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lats",       role: "secondary", weight: 0.3),
            Entry(muscleSlug: "traps",      role: "secondary", weight: 0.5),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.5),
        ],
        "Sumo_Deadlift": [ // sumo deadlift
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "quadriceps", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.6),
            Entry(muscleSlug: "traps",      role: "secondary", weight: 0.4),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.5),
        ],
        "Romanian_Deadlift": [ // romanian deadlift
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.5),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.4),
        ],
        "Stiff-Legged_Barbell_Deadlift": [ // stiff legged deadlift
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.6),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
        ],
        "Good_Morning": [ // good morning
            Entry(muscleSlug: "hamstrings", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "glutes",     role: "secondary", weight: 0.5),
        ],
        "Barbell_Hip_Thrust": [ // hip thrust
            Entry(muscleSlug: "glutes",     role: "primary",   weight: 1.0),
            Entry(muscleSlug: "hamstrings", role: "secondary", weight: 0.4),
            Entry(muscleSlug: "quadriceps", role: "secondary", weight: 0.2),
        ],

        // ─────────────────── SHOULDER ISOLATION ───────────────────
        "Side_Lateral_Raise": [ // lateral raise
            Entry(muscleSlug: "shoulders", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "traps",     role: "secondary", weight: 0.3),
        ],
        "Bent_Over_Dumbbell_Rear_Delt_Raise_With_Head_On_Bench": [ // rear delt fly
            Entry(muscleSlug: "shoulders",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "middle back", role: "secondary", weight: 0.4),
        ],
        "Front_Dumbbell_Raise": [ // front raise
            Entry(muscleSlug: "shoulders", role: "primary", weight: 1.0),
        ],
        "Barbell_Shrug": [ // shrug
            Entry(muscleSlug: "traps",    role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms", role: "secondary", weight: 0.4),
        ],

        // ─────────────────── ARM ISOLATION ───────────────────
        "Barbell_Curl": [ // barbell curl
            Entry(muscleSlug: "biceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms", role: "secondary", weight: 0.4),
        ],
        "Dumbbell_Bicep_Curl": [ // dumbbell curl
            Entry(muscleSlug: "biceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms", role: "secondary", weight: 0.4),
        ],
        "Hammer_Curls": [ // hammer curl
            Entry(muscleSlug: "biceps",   role: "primary", weight: 1.0),
            Entry(muscleSlug: "forearms", role: "primary", weight: 1.0),
        ],
        "Preacher_Curl": [ // preacher curl
            Entry(muscleSlug: "biceps", role: "primary", weight: 1.0),
        ],
        "Incline_Dumbbell_Curl": [ // incline dumbbell curl
            Entry(muscleSlug: "biceps", role: "primary", weight: 1.0),
        ],
        "Triceps_Pushdown": [ // tricep pushdown
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],
        "Cable_Rope_Overhead_Triceps_Extension": [ // overhead tricep extension
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],
        "EZ-Bar_Skullcrusher": [ // skullcrusher
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],
        "Close-Grip_Barbell_Bench_Press": [ // close grip bench press
            Entry(muscleSlug: "triceps",   role: "primary",   weight: 1.0),
            Entry(muscleSlug: "chest",     role: "secondary", weight: 0.5),
            Entry(muscleSlug: "shoulders", role: "secondary", weight: 0.4),
        ],
        "Tricep_Dumbbell_Kickback": [ // dumbbell kickback
            Entry(muscleSlug: "triceps", role: "primary", weight: 1.0),
        ],

        // ─────────────────── ABS / CORE ───────────────────
        "Hanging_Leg_Raise": [ // hanging leg raise
            Entry(muscleSlug: "abdominals", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "forearms",   role: "secondary", weight: 0.3),
        ],
        "Crunches": [ // crunch
            Entry(muscleSlug: "abdominals", role: "primary", weight: 1.0),
        ],
        "Plank": [ // plank
            Entry(muscleSlug: "abdominals", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lower back", role: "secondary", weight: 0.3),
        ],
        "Ab_Roller": [ // ab wheel
            Entry(muscleSlug: "abdominals", role: "primary",   weight: 1.0),
            Entry(muscleSlug: "lats",       role: "secondary", weight: 0.3),
        ],

        // ─────────────────── CALVES ───────────────────
        "Standing_Calf_Raises": [ // standing calf raise
            Entry(muscleSlug: "calves", role: "primary", weight: 1.0),
        ],
        "Seated_Calf_Raise": [ // seated calf raise
            Entry(muscleSlug: "calves", role: "primary", weight: 1.0),
        ],
    ]
}
