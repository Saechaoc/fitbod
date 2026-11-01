# Fitbod design map

This is a record of every screen in the app, how the lifter moves between them, the lifter's workflows and their dead ends, the screens that are missing, BRU mock-ups for the missing screens that matter most, and a design audit.
It is the input to the Milestone 2 design.

As of 2026-11-01: the app at commit `61353088` on `main`, captured on iOS 26.5 simulators on 2026-10-31 and 2026-11-01.
Status: complete; [changelog.md](changelog.md) records each stage.

| Read this | When you need |
|---|---|
| [assumptions.md](assumptions.md) | what the map takes as given: the commit, phones, seeds and the states it could not capture |
| [conventions.md](conventions.md) | the names, templates and diagram rules, and what the checks check |
| [navigation.md](navigation.md) | one map of how every screen is reached |
| [screens/](screens/) | one file per screen, sheet, dialog and system sheet, with its screenshots |
| [workflows/](workflows/) | one file per lifter job, step by step, with its dead ends |
| [missing-screens.md](missing-screens.md) | the screens and states the workflows need that the app does not have |
| [mockups/](mockups/) | BRU mock-ups of the must-have missing screens |
| [audit.md](audit.md) | every design problem found, sorted by severity, and the patterns behind them |
| [tools/](tools/) | the screenshot tour, its exporter and the checks |
| [plan.md](plan.md) | how the map was planned and made |
| [changelog.md](changelog.md) | what changed and why |

## Summary

The [audit](audit.md) lists 365 problems: 4 blockers, 26 major, 158 minor and 177 polish.
The worst is that no screen corrects a finished workout, so a mistyped set stays in every record, trend and progression ([D-04](audit.md#d-04)).
Removing a session from a routine fails, and later saves keep failing until the app restarts ([D-01](audit.md#d-01), [D-02](audit.md#d-02)).
A restored backup brings back no routines ([D-03](audit.md#d-03)).
Today starts a workout only from a session in a routine, so on a fresh install the lifter must first build both, 11 taps over six screens ([D-24](audit.md#d-24)).
The plate stack under a set never opens, and the plate calculator opens only from Settings, so the plates for a 225 lb set take 39 taps from Today ([D-11](audit.md#d-11), [D-12](audit.md#d-12)).
In Progress, a record row opens a placeholder with no back control, a closed weekly recap cannot be opened again, and stalls show only inside a running workout ([D-15](audit.md#d-15), [D-27](audit.md#d-27), [D-21](audit.md#d-21)).
Of the 41 [missing screens and states](missing-screens.md), the four must-haves have [mock-ups](mockups/): editing a finished workout, stalled exercises outside a workout, past weekly recaps, and the workout a record came from.
The largest patterns are workouts and sessions called by the wrong word (23 rows), touch targets under 44 pt (18 rows), and text that breaks or is hidden at AX3 (24 rows).
The signal color is used as small text or as a second accent on 22 rows, and 9 rows show a failed save or load silently or as unreadable system text.
