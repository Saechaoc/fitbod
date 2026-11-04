// ResumeWorkoutRequest.swift
// fitbod
//
// A tap on the rest timer's Live Activity opens `fitbod://session/active`
// (FitbodWidgets/RestTimerLiveActivity.swift). RootView switches to Today
// and marks the request pending; Today pushes the logger of the workout in
// progress and clears it, also on a launch the tap started. While a logger
// is open, on any tab, the link is ignored: the app reopens on that logger,
// and a second logger would outlive the workout's finish.

import Foundation
import Observation

@MainActor
@Observable
public final class ResumeWorkoutRequest {
    public var isPending = false
    /// A logger is on screen. It presents sheets but never pushes a screen,
    /// so its appearing and disappearing say whether one is open.
    public var loggerIsOpen = false

    public init() {}

    /// The Live Activity's link.
    public static func isResumeLink(_ url: URL) -> Bool {
        url.scheme == "fitbod" && url.host() == "session" && url.path() == "/active"
    }
}
