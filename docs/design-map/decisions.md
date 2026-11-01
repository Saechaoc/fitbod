# Review decisions

The user reviewed the design map on 2026-11-01 and made the decisions below.
They sort the [audit](audit.md) into the stages of the [development guide](../DEVELOPMENT.md), approve the four [mock-ups](mockups/), adopt nine of the [patterns](audit.md) as fixes, and choose which [missing screens](missing-screens.md) to build now.
Where this file and the audit differ on what to do next, this file wins; the audit still describes each problem.

## Mock-ups

All four mock-ups are approved as the design to build:

- [history-editing](mockups/history-editing.html)
- [stalled-exercises](mockups/stalled-exercises.html)
- [all-recaps](mockups/all-recaps.html)
- [pr-workout-detail](mockups/pr-workout-detail.html)

## Audit stages

Every row takes the stage that this rule suggests:

1. **Fix now:** a blocker, a row that an open data or wrong-result ticket covers (T40, T41, T110, T113, T114, T116), or a failed save that is silent or breaks later saves (D-08, D-20, D-59, D-153, D-155).
2. **When stable:** a row in pattern [P-4](audit.md) or [P-5](audit.md), or one that is only about AX3, VoiceOver, Dynamic Type or dark mode.
3. **Polish later:** any other `polish` row.
4. **With the redesign:** every other row.

Seven rows mention AX3 or VoiceOver, or sit in P-1 or P-5, but are about the default-size experience or wording, so they go with the redesign by hand: D-12, D-16, D-29, D-189, D-216, D-231 and D-292.

The review's first draft moved D-01 to D-03 to "With the redesign" and D-04 to "When stable".
The user then kept all four as Fix now, because the development guide never defers data loss or failed saves, and D-04 is built with the approved history-editing screen.

| Stage | Rows | When the work happens |
|---|---|---|
| Fix now | 13 | Next, before more prototype work on the screens they touch |
| With the redesign | 141 | When the screen's workflow is rebuilt |
| When stable | 67 | When the workflow is stable, as the development guide defines it |
| Polish later | 144 | When the screen's design is approved |

- **Fix now (13):** D-01 to D-04, D-08, D-18, D-20, D-59, D-68, D-153, D-155, D-203, D-358.
- **With the redesign (141):** D-05 to D-06, D-09, D-11 to D-16, D-19, D-21 to D-22, D-24 to D-29, D-31 to D-35, D-37 to D-40, D-43, D-45, D-47 to D-48, D-51 to D-57, D-60 to D-64, D-66 to D-67, D-69 to D-72, D-74 to D-76, D-79 to D-81, D-83 to D-86, D-89 to D-91, D-93 to D-94, D-96 to D-97, D-99 to D-100, D-102 to D-112, D-115 to D-127, D-130 to D-132, D-134 to D-136, D-138 to D-142, D-144 to D-152, D-154, D-156, D-158, D-160 to D-166, D-168 to D-170, D-172, D-174 to D-177, D-179, D-181, D-183 to D-185, D-187 to D-189, D-216, D-231, D-292.
- **When stable (67):** D-07, D-10, D-17, D-23, D-30, D-36, D-41 to D-42, D-44, D-46, D-49 to D-50, D-58, D-65, D-73, D-77 to D-78, D-82, D-87 to D-88, D-92, D-95, D-98, D-101, D-113 to D-114, D-128 to D-129, D-133, D-137, D-143, D-157, D-159, D-167, D-171, D-173, D-178, D-180, D-182, D-186, D-194, D-198 to D-199, D-206, D-209, D-211 to D-212, D-225 to D-226, D-238, D-243, D-256, D-266, D-268 to D-269, D-285, D-287, D-295, D-311, D-317 to D-318, D-322, D-329, D-340, D-342, D-345, D-351.
- **Polish later (144):** D-190 to D-193, D-195 to D-197, D-200 to D-202, D-204 to D-205, D-207 to D-208, D-210, D-213 to D-215, D-217 to D-224, D-227 to D-230, D-232 to D-237, D-239 to D-242, D-244 to D-255, D-257 to D-265, D-267, D-270 to D-284, D-286, D-288 to D-291, D-293 to D-294, D-296 to D-310, D-312 to D-316, D-319 to D-321, D-323 to D-328, D-330 to D-339, D-341, D-343 to D-344, D-346 to D-350, D-352 to D-357, D-359 to D-365.

## Pattern fixes

Each adopted pattern is fixed once, in shared code or as a rule, rather than row by row.

| Pattern | Adopted | When |
|---|---|---|
| [P-1](audit.md) A failed save or load is silent or unreadable | Yes | Now, with the Fix now rows |
| [P-2](audit.md) Touch targets under 44 pt | Yes | Once, in the shared BRU components |
| [P-3](audit.md) Logged workouts and sessions called by the wrong word | Yes | With the redesign |
| P-4 Text breaks inside words or numbers at large text | No | When stable |
| P-5 Fixed sheet heights and fixed bars hide content at AX3 | No | When stable |
| [P-6](audit.md) Bright signal fill used as small text | Yes | Once, as a token rule |
| P-7 More than one signal element on a screen | No | Polish later |
| [P-8](audit.md) Sheets with no close control, or closed different ways | Yes | With the redesign |
| [P-9](audit.md) Confirmations that do not follow the confirmation rule | Yes | With the redesign |
| [P-10](audit.md) System controls where BRU has its own | Yes | Once, in the shared BRU components |
| [P-11](audit.md) Static text styled as a control | Yes | With the redesign |
| [P-12](audit.md) Empty states without a headline or a fixing action | Yes | With the redesign |

## Missing screens

Build now: 40 of the 41 rows in [missing-screens.md](missing-screens.md), the four must-haves first, from their mock-ups.
"Build now" means these screens are in scope for the redesign; it does not order them.

Later: [restore-relaunch-notice](missing-screens.md).
