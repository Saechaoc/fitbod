//
//  SessionRoute.swift
//  fitbod
//
//  Typed navigation route to the workout logger. Only Today's stack pushes
//  it: every other way into the workout in progress goes through
//  ResumeWorkoutRequest, so ‹ always lands on Today (FT-02).
//

import Foundation

public enum SessionRoute: Hashable {
    case logger(Session)
}
