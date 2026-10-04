//
//  WorkoutLauncher.swift
//  fitbod
//
//  One entry point for "Start workout" (Today quick-start, routine detail,
//  routine row) so every surface enforces the same rules:
//
//    - One active workout at a time (RESEARCH §6 Pitfall 7). A conflict
//      offers to resume the open workout instead of silently failing.
//    - Empty routines cannot start.
//    - On success the new session (a snapshot of the routine) is presented
//      full-screen.
//

import SwiftUI
import SwiftData

public enum WorkoutStartFailure {
    case activeWorkoutExists(Session)
    case noExercises
    case couldNotSave(String)
}

@MainActor
public enum WorkoutLauncher {
    /// Starts `routine` and presents it. Returns a failure to show, or nil.
    @discardableResult
    public static func start(_ routine: Routine, context: ModelContext, router: AppRouter) -> WorkoutStartFailure? {
        if let active = SessionFactory.active(in: context) {
            return .activeWorkoutExists(active)
        }
        do {
            let session = try SessionFactory.start(routine: routine, on: .now, context: context)
            router.present(workout: session)
            return nil
        } catch SessionFactoryError.activeSessionAlreadyExists {
            if let active = SessionFactory.active(in: context) {
                return .activeWorkoutExists(active)
            }
            return .couldNotSave("Another workout is already open.")
        } catch SessionFactoryError.routineHasNoExercises {
            return .noExercises
        } catch {
            return .couldNotSave(error.localizedDescription)
        }
    }
}

private struct WorkoutStartAlert: ViewModifier {
    @Binding var failure: WorkoutStartFailure?
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.alert(
            title,
            isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            ),
            presenting: failure
        ) { failure in
            switch failure {
            case .activeWorkoutExists(let session):
                Button("Resume workout") {
                    router.present(workout: session)
                }
                Button("Cancel", role: .cancel) {}
            case .noExercises, .couldNotSave:
                Button("OK", role: .cancel) {}
            }
        } message: { failure in
            switch failure {
            case .activeWorkoutExists(let session):
                Text("Finish or discard \(session.routineSnapshotName.isEmpty ? "the open workout" : session.routineSnapshotName) before starting another.")
            case .noExercises:
                Text("Add at least one exercise to this routine first.")
            case .couldNotSave(let reason):
                Text(reason)
            }
        }
    }

    private var title: String {
        switch failure {
        case .activeWorkoutExists: return "Workout in progress"
        case .noExercises: return "Routine is empty"
        case .couldNotSave: return "Couldn't start workout"
        case nil: return ""
        }
    }
}

extension View {
    /// Presents the right alert for a failed workout start.
    func workoutStartAlert(_ failure: Binding<WorkoutStartFailure?>) -> some View {
        modifier(WorkoutStartAlert(failure: failure))
    }
}
