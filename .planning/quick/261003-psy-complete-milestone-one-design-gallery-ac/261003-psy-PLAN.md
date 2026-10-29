# Milestone 1 companion: design and delivery

Continues the authorized GSD milestone task `261003-9k8`. Claude PID 35790 is
working in this checkout on the workout logger and its UI tests. Preserve that
work; do not edit the logger, RootView, rest overlay, or logger test file while
that work is active. No branch changes, blanket staging, or destructive cleanup.

Final coordination note: Claude reached a session limit and its terminal became
idle before the shared logger follow-ups. Codex then made scoped completion,
accessibility and test-selector fixes, preserving Claude's other changes.

## Scope

1. Implement the missing DEBUG component gallery and expose it from Settings.
   Use real BRU components, meaningful sample data, interactive controls, and
   normal plus accessibility-size previews.
2. Finish the accessibility foundation: distinguish signal fills from readable
   signal text, correct contrast pairs and touch targets, document actual tokens.
   Run GitNexus upstream impact before editing existing symbols and report risk.
3. Deliver setup, core-screen interaction specifications, assumptions, catalog
   provenance/import guidance, and a prioritized roadmap. Existing Claude Design
   assets and native SwiftUI are authoritative; avoid inventing another identity.
4. Build and run focused native checks in a separate DerivedData directory and
   simulator. Add whole-journey verification where it does not overlap Claude's
   logger tests. Record actual results and screenshots; never infer a pass.
5. Audit every original requirement against current files and runtime evidence.
   Keep the thread goal active until native build, complete workout journey,
   relaunch persistence, device-size and accessibility checks are proven.

## Verification

- Xcode 26.5 / iOS 26.5 Simulator, scheme `fitbod`.
- Separate simulator(s) and `/private/tmp/fitbod-codex-m1` DerivedData.
- Focused persistence, snapshot, rest-recovery and component checks.
- Small/large phone and accessibility text layouts with screenshots.
- Design token contrast checker in light and dark appearances.

## Collaboration boundary

This plan and subsequent evidence describe Codex's work only. Existing dirty
files are user/Claude work. Docs and gallery may be completed independently;
merge current authoritative changes before the final completion audit.
