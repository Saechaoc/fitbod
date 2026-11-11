//
//  Equipment.swift
//  fitbod
//
//  LIB-06 anchor: the equipment facet for the exercise library filter.
//  Declaration order is the order the filter and the custom editor list.
//
//  Persisted as `equipmentRaw: String` on `Exercise`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum Equipment: String, CaseIterable, Sendable {
    case barbell
    case ezBar = "ez_bar"
    case trapBar = "trap_bar"
    case dumbbell
    case kettlebell
    /// A weight plate held on its own, as in a plate front raise.
    case plate
    case machine
    case smithMachine = "smith_machine"
    case cable
    case bands
    case bodyweight
    case weightedBodyweight = "weighted_bodyweight"
    case suspension
    case medicineBall = "medicine_ball"
    case sled
    case cardioMachine = "cardio_machine"
    case other

    public static let `default`: Equipment = .other

    /// The name every screen shows, such as "Weighted Bodyweight".
    public var displayName: String {
        self == .ezBar ? "EZ Bar" : rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    /// Equipment whose maker and model change the load (RM-066), so a
    /// logged exercise on it can name its machine.
    public var takesMachine: Bool {
        [.machine, .smithMachine, .cable, .cardioMachine].contains(self)
    }
}
