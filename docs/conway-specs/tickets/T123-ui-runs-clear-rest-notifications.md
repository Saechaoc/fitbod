---
id: T123
title: A reset launch clears leftover rest notifications
phase: 4
items: []
depends_on: [T101]
size: S
sim: small
owns: [fitbod/App/DebugLaunchReset.swift]
---

# T123: A reset launch clears leftover rest notifications

Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket.

## Problem

This is finding F266, which T101's worker found.
Its journey and self-test items (F267, F270) moved to T119 or went with the suites T143 deleted.

- "Rest complete" notification banners appear during UI runs, from rest timers that earlier tests or launches started.
  In one of T101's runs a banner slid over the top of the screen just as a test swiped a sheet down, so the swipe pulled down Notification Center instead, and the test failed.

## Target

- The DEBUG launch reset in `fitbod/App/DebugLaunchReset.swift`.

## Change

1. A launch with the reset flag removes the app's pending and delivered rest notifications, so no banner from an earlier test or launch shows during a run.

## Constraints

- Change only DEBUG launch behavior; a release build, and a launch without the reset flag, behave as today.
- Commit no new UI test: the user asked for fewer UI tests (T143), and this guards test runs, not the lifter's data.

## Ownership

You may edit the files in `owns`.
Ask before you edit anything else, such as the rest timer's scheduler.

## Repro first

- On the small phone, with a throwaway check you do not commit: start a rest timer in one launch, end the app before it completes, relaunch with the reset flag after its time is up, and look for a "Rest complete" banner or delivered notification.
  Record in `notes.md` what remains today.

## Observable acceptance

- The same check finds no banner and no delivered notification after the change; `notes.md` records both runs.
- `WorkoutLoggerJourneyUITests` passes on the small phone.
- `fitbodTests` passes, and the app and the widget build.

## Hints

- T101's notes in `docs/conway-specs/evidence/T101/notes.md` describe the banner, with screenshots of it and of the Notification Center it opened.
- `RestTimerNotificationScheduler.swift` wraps `UNUserNotificationCenter`; `removeAllPendingNotificationRequests()` and `removeAllDeliveredNotifications()` clear both kinds.
- `DebugLaunchReset.swift` already handles `-fitbod-reset-store` and the `debug.resetSignal` element that `UITestNavigation.launch` waits for.
