// ResumeWorkoutRequest.swift
// fitbod
//
// A tap on the rest timer's Live Activity opens `fitbod://session/active`
// (FitbodWidgets/RestTimerLiveActivity.swift). RootView switches to Today
// and marks the request pending; Today pushes the logger of the workout in
// progress and clears it, also on a launch the tap started.

import Foundation
import Observation

@MainActor
@Observable
public final class ResumeWorkoutRequest {
    public var isPending = false

    public init() {}

    /// The Live Activity's link.
    public static func isResumeLink(_ url: URL) -> Bool {
        url.scheme == "fitbod" && url.host() == "session" && url.path() == "/active"
    }
}
