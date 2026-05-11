//
//  Force.swift
//  fitbod
//
//  Push / pull / static. Sourced from yuhonas/free-exercise-db at seed time;
//  nullable because the dataset leaves some rows unspecified.
//
//  Persisted as `forceRaw: String?` on `Exercise`
//  (FOUND-03 / PITFALLS #9).
//

import Foundation

public enum Force: String, CaseIterable, Sendable {
    case push
    case pull
    case `static`
}
