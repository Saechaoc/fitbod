//
//  AppRouter.swift
//  fitbod
//
//  App-wide navigation state: the selected tab, one NavigationPath per tab
//  (re-tapping a tab pops it to root), and the workout presented as a
//  full-screen cover.
//
//  The active workout lives in a cover above the tabs, not inside one tab,
//  so it looks and behaves the same whether it was started from Today, a
//  routine, or restored on relaunch — and logging gets the full screen
//  height. "Minimize" clears `presentedWorkout`; the workout stays active
//  (completedAt == nil) and Today offers Resume.
//

import SwiftUI
import SwiftData

@Observable
@MainActor
public final class AppRouter {
    public enum Tab: Hashable, CaseIterable, Sendable {
        case today
        case routines
        case library
        case history
        case settings
    }

    public var selectedTab: Tab = .today
    public var todayPath = NavigationPath()
    public var routinesPath = NavigationPath()
    public var libraryPath = NavigationPath()
    public var historyPath = NavigationPath()

    /// The workout shown in the full-screen cover (active or just finished).
    public var presentedWorkout: Session?

    /// A workout the user discarded from inside the cover. Deleted in the
    /// cover's `onDismiss`, after the logger has left the screen, so no
    /// view reads a deleted model mid-animation.
    public var pendingDiscard: Session?

    /// Set by any screen that needs the routine builder opened from the
    /// Routines tab (e.g. Today's empty state).
    public var pendingNewRoutine = false

    public init() {}

    /// Re-tap of the selected tab → pop that tab to its root.
    public func select(_ tab: Tab) {
        if tab == selectedTab {
            popToRoot(tab)
        }
        selectedTab = tab
    }

    public func popToRoot(_ tab: Tab) {
        switch tab {
        case .today: todayPath = NavigationPath()
        case .routines: routinesPath = NavigationPath()
        case .library: libraryPath = NavigationPath()
        case .history: historyPath = NavigationPath()
        case .settings: break
        }
    }

    public func present(workout: Session) {
        presentedWorkout = workout
    }

    public func dismissWorkout() {
        presentedWorkout = nil
    }
}

/// Typed destinations pushed inside the tab NavigationStacks.
public enum AppRoute: Hashable {
    case routine(Routine)
    case exercise(Exercise)
    case exerciseHistory(Exercise)
    case workoutSummary(Session)
}

extension View {
    /// Registers the shared `AppRoute` destinations on a NavigationStack.
    func appRouteDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .routine(let routine):
                RoutineDetailView(routine: routine)
            case .exercise(let exercise):
                ExerciseDetailView(exercise: exercise)
            case .exerciseHistory(let exercise):
                ExerciseHistoryView(exercise: exercise)
            case .workoutSummary(let session):
                WorkoutSummaryView(session: session, presentation: .history)
            }
        }
    }
}
