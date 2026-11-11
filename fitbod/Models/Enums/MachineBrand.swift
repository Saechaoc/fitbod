//
//  MachineBrand.swift
//  fitbod
//
//  The machine brands a lifter can tag an exercise with, stored as
//  `Exercise.brand` (RM-022). A brand machine is its own exercise row, so its
//  history and its increment, bar and unit settings stay its own.
//

import Foundation

public enum MachineBrand: String, CaseIterable, Sendable {
    case hammerStrength = "Hammer Strength"
    case lifeFitness = "Life Fitness"
    case cybex = "Cybex"
    case precor = "Precor"
    case nautilus = "Nautilus"
    case matrix = "Matrix"
    case hoist = "HOIST"
    case freemotion = "Freemotion"
    case technogym = "Technogym"
    case arsenalStrength = "Arsenal Strength"
    case panatta = "Panatta"
}
