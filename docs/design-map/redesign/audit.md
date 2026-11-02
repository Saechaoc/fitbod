# Screenshot audit

Each item names the screenshot, the problem, and what it costs the lifter.
Screenshots are the 17e default-size light captures in `docs/design-map/screens/img/`, written here without that prefix.
`D-nn` points at `docs/design-map/audit.md`; `P-n` at its pattern list.
Items are grouped by screenshot and numbered A-01 to A-32 so the other leaves can cite them.

## Today with a block running

`today.png`, `today--scheduled.png`, `today--streak.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-01 | Three status bands come before the action: the stat strip (DAY STREAK 0, SESSIONS 0 ›, W1 / 4 with a dash where the phase label goes in the capture; main now shows the phase's short label, "ACCUM"), the block band (BLOCK chip, the block's name in caps, "LIVE BLOCK" in the capture, an orange ACCUMULATION chip, W1 to W4 cells), then the NEXT slab. | The first things read are a row of zeros and the block's bookkeeping. START WORKOUT ▸ is the fourth element on the page, so the five-second test fails for "what do I do now". | D-159, D-341 |
| A-02 | One fact, three forms: "W1 / 4" in the strip, the ACCUMULATION chip and the lit W1 cell in the band, "DAY 01 / 28" on the slab. | The lifter reconciles week, phase and day counters instead of reading one line. Past the plan the three no longer disagree, because 91b6b6ed made them all read PLAN COMPLETE or go blank; the three forms remain. | D-161 (fixed), D-166 |
| A-03 | The strip mixes scopes and only one cell is a control: DAY STREAK (all-time habit), SESSIONS › (all-time, opens history), W1 / 4 (this block). | Nothing marks which cell taps. "SESSIONS" names logged workouts, which the app calls workouts everywhere else. The streak counts consecutive calendar days with a workout, ending today or yesterday (`TodayView.swift:472-499`), so one rest day between workouts starts it over; a lifter who rests between training days reads 1 on most days and 0 after two rest days. | D-341, P-11 |
| A-04 | The signal colour is used five times on `today.png`: the ACCUMULATION chip in the band, START WORKOUT ▸, the COMPOUND chip's border and text in the lift list, the "±0" delta on the volume slab, and the MRV cell of the legend (`FatigueSurfaceView.swift:238`); `today--scheduled.png` adds the strip's trend arrow and the DL badge, seven. | The one accent no longer marks the one action. | P-7 |
| A-05 | The block band is tappable but gives no cue: no chevron, not a button. | The only route from Today to the block's actions (edit, end, start) is invisible, and VoiceOver finds loose text. | D-159 |
| A-06 | The slab says "NEXT" and "DAY 01 / 28". | "NEXT" reads like a queue when the lifter wants today. The day counter is a number nobody trains by; past the plan it disappears (91b6b6ed), so the slab's label changes form again. | D-161 (fixed) |
| A-07 | LIFT LIST repeats the slab's "1 EXERCISE · 3 SETS" as "1 LIFT" and decorates every row with a bordered COMPOUND or WORK chip. | Bordered chips look like controls and do nothing. The count is said twice. | P-11 |
| A-08 | While a session is scheduled, Today hides the session picker. | Another session costs four taps through Program, Routine and Session, and that workout does not move the rotation. | D-163, D-165 |
| A-09 | There is no "done for today" state. | After a finished workout a weekday block offers the same START WORKOUT ▸ again, and a rotation block shows the next session at once. The lifter cannot tell the day is done and can log the session twice. | D-164 |

## Today, lower half

`today--active-block-lower.png`, `today--volume.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-10 | Weekly volume analytics sit under the workout: a black WORKING SETS slab, a legend, 17 muscle rows (name, N SETS, a bar with MEV, MAV and MRV ticks, a zone chip, a "MEV 6 · MAV 14 · MRV 20" caption) and two body heatmaps. | Today is about four screens long. The analytics never change the next action, and the muscle detail the lifter wants is a long scroll away. Progress, the tab for analysis, has no entry to it. | D-131 |
| A-11 | Early in the week every row carries an amber UNDER MEV chip or reads NOT TRAINED. | Seventeen warnings the lifter cannot act on yet, repeated each week. | brief principle 6 |
| A-12 | The heatmap head shows the calendar week as "W44 / 53", the same form as the block week "W1 / 4" above it. | Two different "W" numbers on one screen. | D-344 |
| A-13 | Heatmap muscles are 27 × 13pt targets. | Hard to hit; moves with the surface, not fixed here. | D-160 |

## Today with no block

`today--empty.png`, `today--block-ended.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-14 | Fresh store: three zeros (DAY STREAK, SESSIONS, THIS WEEK), a START A WORKOUT head, the BUILD YOUR FIRST ROUTINE hero with its orange + NEW ROUTINE, then "NO ACTIVE BLOCK." with a second orange START A BLOCK, then a WORKING SETS slab reading 0 and ±0, the legend, and a VOLUME THIS WEEK list in which every muscle with a seeded MEV target is a zero row. | Two orange calls on one screen. The second opens New block, whose routine picker is blank until a routine exists. A screen of zeros surrounds the one useful action. "No sets logged this week" shows only when no muscle has a MEV target, which the seeded targets rule out. | D-24, D-162, P-7, P-12 |
| A-15 | After a block ends, Today returns to the picker plus "No active block. START A BLOCK", which opens a new blank block even when a READY block is waiting. | The planned next block cannot be started from Today. A lifter who taps the link creates a second, empty block. | D-25 |
| A-16 | Nothing on Today marks a finished block or reopens its review. | The review slides up by itself on every visit until the lifter taps "Start next ▸", because closing it any other way saves nothing (`TodayView.swift:374`, `BlockReviewView.swift:393`). Once acknowledged, the block's result is unreachable from Today and from its overview. | D-27, D-40 |
| A-17 | The picker puts an orange START ▸ on every session row. | With a four-session routine there are four signal buttons and none of them is "today's". | P-7 |
| A-18 | A rest day on a weekday block reads "No workout scheduled. Build a routine or pick one from your library." with + NEW ROUTINE. | A rest day tells the lifter to build a routine. The next training day is not named. | D-165 |

## Today, resume

`today--resume.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-19 | The RESUME slab is right: one slab, one orange button, DISCARD as a ghost. The volume analytics still follow it. | Keep the slab. The scroll below stays the A-10 problem. | - |

## Today, deload week

`today--deload-week.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-20 | Deload is said three times: a full-width "▲ DELOAD WEEK" banner whose tagline "recover, don't load." hangs off an em dash, the DELOAD chip, and a DL badge that hangs into the gutter. | Three alarms for a planned, calm week. The em dash breaks the house style. | D-343 |
| A-21 | The CONSIDER DELOAD advisory can stack under the deload week banner (`TodayView.swift:102-108`). | Two banners above the strip, styled alike, though only the advisory is dismissible and opens the signals sheet. | - |

## Today, plan complete

`today--plan-complete.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-22 | The capture shows PLAN COMPLETE on the band chip beside "W1 / 4" with a trend arrow in the strip and "DAY 08 / 28" on the slab; main (91b6b6ed) reads PLAN COMPLETE in the strip cell and the chip and drops the day counter. Either way no week is lit and nothing on the screen ends the block. | The block stays active for ever and the review never comes unless the lifter finds END BLOCK in the overview. | D-161, D-166 |

## Program

`program.png`, `program--states.png`, `program--draft.png`, `program--block-done.png`, `program--long-name.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-23 | The page answers "what exists", not "what am I running". The active card shows a chip, a name and "Week 1 of 4 · Accumulation"; it does not name its routine or today's session. | The block to routine relationship shows only as a chip on the routine row, and with an active block and a planned one on the same routine the routine row stacks chips (`UsageTagFlow` lists every block that is not completed, `ProgramView.swift:663-667`). | brief principle 7 |
| A-24 | Status chips come in three styles: ACTIVE filled orange, READY outlined orange, DRAFT and DONE outlined ink. Done blocks share the list with current work, and ALL HISTORY ▸ appears only from the fourth done block. | READY competes with ACTIVE for the accent. Drafts and finished blocks are not separated from the one that matters. | P-7 |
| A-25 | Block creation moves: a + DEFINE BLOCK ▶ row under BLOCKS until the first block exists, then only the header's + NEW popover. | The path to a new block changes after the first one. | D-125 |
| A-26 | Routine rows end with "›" while block cards have no chevron; the header rule and the BLOCKS rule stack. ("1 sessions" was fixed by d227a1cb; `BRUCountLabel` is singular now.) | Two tappable lists that look different, plus small noise. | D-298 (fixed), D-299 |
| A-27 | An empty ROUTINES section is a lone "+ NEW ROUTINE" with no line saying there are none. | The section looks broken rather than empty. | D-300, P-12 |
| A-28 | The header is a one-off chrome (left title, + NEW, top rule) unlike the BRUHeaderBar on Today, Progress and Library. | Program looks like a different app from the other tabs. | brief principle 5 |
| A-29 | Two blocks with the same name, status and displayed week and phase show identical cards. | Nothing tells them apart. | D-127 |

## Program, empty and resume

`program--empty.png`, `program--resume-banner.png`

| # | Problem | Effect on the lifter | Refs |
| --- | --- | --- | --- |
| A-30 | The first-run screen sells periodization before the lifter has a routine: ACTIVE BLOCK · NONE, a 68pt NO PROGRAM, a paragraph with an em dash and four phase names, a 71pt orange + DEFINE BLOCK ▶, four bordered chips that do nothing, then OR START FROM A TEMPLATE rows with "ACCUM 5 · INTNS 2 · DELOAD 1". | The one thing the lifter must do first, a routine, is only in the popover. + DEFINE BLOCK ▶ leads to a blank routine picker. The chips and abbreviations add reading for no choice. | D-162, D-301, D-302, D-303, D-304, P-12 |
| A-31 | With a workout in progress the resume banner adds a second orange RESUME ▸ above + DEFINE BLOCK ▶. | Two signal buttons. | D-126 |
| A-32 | The resume banner's Discard is a long-press context menu, while Today's DISCARD is a visible ghost button. | An invisible gesture for a destructive action, and two ways to do one thing. | D-56, D-57 |

## Where Today's band leads

`block-overview.png` uses the signal colour six times (D-43).
That screen is out of scope here, but the proposal moves the week cells off Today and leaves the overview as the one place for the block's week strip, scheduling and actions.
