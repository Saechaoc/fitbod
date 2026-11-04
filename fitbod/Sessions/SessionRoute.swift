//
//  SessionRoute.swift
//  fitbod
//
//  Typed navigation route to the workout logger, used by the Today and
//  Program stacks.
//

import Foundation

public enum SessionRoute: Hashable {
    case logger(Session)
}
