# Fitbod playtest and roadmap reconciliation

November 8, 2026 · 21 findings from the gym session

Compared the playtest notes and nine screenshots with the product roadmap, the design audit, and the Swift code on `main`. The Today and Program redesign changelog records steps 1.1 and 1.2 as landed. The exact build installed on the phone is unknown. Findings that depend on device behavior are marked for reproduction. [Product roadmap][roadmap] · [Design audit][audit] · [Redesign plan][plan] · [Changelog][changelog]

**Suggested order.** P1 covers core logging friction and the physical-device Live Activity failures. P2 covers the next workflow, catalog, and volume passes. P3 covers presentation polish. These are playtest priorities. The roadmap's own priorities are identified where they matter.

## Active workout controls and exercise picker

| ID | What went wrong | Done when | Roadmap reconciliation |
| --- | --- | --- | --- |
| FT-01 · P1 | **Discard disappears after logging a set.** You had to leave the workout and use Discard on Today. The logger's menu only shows it while `loggedSetCount == 0`. Today shows the existing fallback in `IMG_5429.png`. | Discard is reachable inside the logger with and without logged sets. When sets would be lost, the confirmation names the consequence and Keep logging preserves the workout. | **Existing D-64.** Step 1.6 makes Discard visible on Program's resume banner. Include the logger entry separately and align its confirmation with D-56. [Audit D-64][d64] · [Logger menu][logger-menu] · [Redesign steps 1.3 and 1.6][plan-state] |
| FT-02 · P1 | **Back has an unpredictable destination.** You reported landing on a previous tab when leaving the workout. The logger calls `dismiss()`, so its destination depends on the route that opened it. | Define the destination for the chevron and swipe Back from Today, Program, and a Live Activity. The user can predict where they will land and resume the same open workout from there. | **Add to logger navigation.** Step 1.3 describes the Today-start route. Extend the acceptance to other ways into the logger. [Logger Back action][logger-menu] · [Today exit behavior][today-back] |
| FT-03 · P1 | **Removing an accidentally added exercise is hard to discover.** On `main`, long-pressing the exercise name opens **Remove from workout**. The exercise header gives no visible hint. | A visible exercise-level action lets the user remove the exercise mid-workout. If it has logged sets, the confirmation says those sets will be removed from this workout. | **Existing D-90.** Improve access to the existing action. Phase 2's add/swap work is adjacent. [Audit D-90][d90] · [Exercise actions][exercise-menu] |
| FT-04 · P2 | **Add Exercise has two headers.** The picker stacks two copies of Cancel and Add Exercise. Only one contains + New. `IMG_5426.png`. | The in-workout picker has one header with Cancel, Add Exercise, and + New. Search, filters, and add still work from that entry. | **Existing D-84.** The logger wraps a library picker that already supplies its own header. [Audit D-84][d84] · [Logger picker wrapper][picker] |
| FT-05 · P2 | **Single-Leg Kneeling Leg Curl is missing.** You couldn't find it and the checked-in 900-entry seed has no exercise under that name or a named kneeling leg-curl variant. | Find and add the correct unilateral kneeling machine variant by a natural search term, with hamstrings and machine filters matching it. Existing exercise IDs and history survive the import. | **Add to P1 Catalog curation and safe import.** Track this specific exercise within the existing catalog work. [Product roadmap][roadmap-priorities] · [Catalog seed][catalog] |

## Set logging

| ID | What went wrong | Done when | Roadmap reconciliation |
| --- | --- | --- | --- |
| FT-06 · P1 | **The next set doesn't pick up what you just did.** Planned rows seed weight from earlier matching-intent history and start with empty reps. + Add Set can seed a weight from a row in the current exercise. Completing a set doesn't carry its values into the next planned row. | After logging a working set, the next eligible untouched working set on that lift offers its weight and reps. + Add Set follows the same rule. Manual edits and explicit planned targets take precedence. RPE stays a fresh effort entry under this proposal. | **Add same-workout carry-forward to SESS-03.** The written requirement is about prefill from an earlier workout. Give the new behavior separate acceptance. [SESS-03][sess] · [Planned rows][planned-sets] · [Add Set][add-set] |
| FT-07 · P1 | **Previous is ambiguous and shows a dash in the playtest.** It looks like it might mean the last set just logged. On `main` it uses the top working set from the most recent eligible finished workout for this exercise and intent. `IMG_5430.png`, `IMG_5431.png`, `IMG_5433.png`. | Label the reference clearly, such as **Last workout**, and explain the same-intent filter. Show the historical weight, reps, and RPE when available, and a clear empty state when there is no matching history. Verify with known same-intent history before treating every dash as a lookup bug. | **Clarify and verify SESS-03.** The existing history lookup and the new same-workout prefill solve separate problems. [SESS-03][sess] · [Previous column][previous] · [History selector][history-selector] |
| FT-08 · P1 | **The 6–10 squares don't read as RPE.** They are the set's effort controls, but the RPE heading is over the upper data row while the unlabeled squares are below it. They repeat at full size for every set. `IMG_5430.png`, `IMG_5431.png`, `IMG_5433.png`. | The effort control is labeled where the user taps it. The selected RPE is readable on the set, including after completion. Whole and decimal RPE remain usable in a compact row. | **Extend P2 Logger density and SESS-02.** The audit's earlier T36 work on the RPE chips is marked done. This playtest adds a label, placement, and readability check. [Product roadmap][roadmap-priorities] · [Audit D-87][d87] · [RPE controls][rpe] |
| FT-09 · P2 | **WHY has no visible context and disappears on completion.** It opens the recommended-weight explanation. The row shows it when an explanation exists and hides it after the set is marked complete. `IMG_5430.png`, `IMG_5431.png`. | Use a specific label such as **Why this weight?** Keep the explanation reachable at the exercise level after logging and identify the originally recommended weight when the actual load differs. | **Extend PRES-02 and the frozen-prescription decision.** The roadmap already defines which weight WHY explains. Add discoverability and after-completion access. [PRES-02][pres] · [Roadmap decision][frozen] · [WHY visibility][why] |
| FT-10 · P2 | **Set-type controls look disconnected from the set.** The rounded iOS menu and separate W/UP badge compete with the RPE buttons. The menu doesn't show the current choice. `IMG_5431.png`. | One compact set-type control shows the current type and a clear selected state. Working, Warm-up, Drop Set, To Failure, and Rest-Pause remain easy to select and distinguish. | **Existing D-270 plus SESS-02.** Group with the logger density pass so the effort and set-type controls are designed together. [Audit D-270][d270] · [Set-type control][set-type] |
| FT-11 · P2 | **The inline barbell plate graphic adds bulk during weight entry.** It opens under the set when the weight field has focus and takes space above the keyboard. You asked to remove it. `IMG_5430.png`. | Editing a set's weight opens the numeric input without the large inline plate-stack panel. | **Reverse the inline behavior from T125.** The standalone plate calculator and inventory are separate surfaces. Scope this request to the graphic shown in the logger. [Inline plate stack][plates] · [PRES-08][pres] |
| FT-12 · P2 | **Exercise sections stay expanded.** All the set rows remain in view while logging, and the finished workout summary lists every set again. Squats were your example. The logger and summary both render the rows directly. | During logging, each exercise can be collapsed to its header, set count, and completion status. The finished summary opens with compact exercise sections that expand to show set details. | **Extend Logger density.** Add summary disclosure to the workout-review workflow as well. [Product roadmap][roadmap-priorities] · [Logger set rows][logger-rows] · [Summary exercise rows][summary-rows] |

## Finish and return to Today

| ID | What went wrong | Done when | Roadmap reconciliation |
| --- | --- | --- | --- |
| FT-13 · P3 | **Finish confirmation feels visually disconnected.** A stock iOS dialog with similarly styled Finish and Keep logging buttons sits over the custom workout screen. `IMG_5433.png`. | The confirmation fits the app's workout UI, keeps the set count and elapsed time, and gives Finish and Keep logging clear visual priority. | **Add to workout-finish polish.** Finishing and opening the summary already work in the documented gym-day flow. The request is about the confirmation's presentation and action hierarchy. [Finish confirmation][finish] · [Gym-day roadmap][gym-day] |
| FT-14 · P2 | **The Resume workout card is almost white in dark mode.** The current slab uses `bruInk`, which inverts to near-white in dark appearance. `IMG_5429.png`. | The dark Resume card fits the surrounding Today screen, and Resume and Discard are still easy to distinguish. Review the light appearance alongside it. | **Add a theme decision for T-RESUME.** The redesign keeps the existing Today Resume slab. Step 1.6 restyles the Program banner. [Resume layout][today-resume] · [Resume slab][resume-source] · [Adaptive ink token][ink] |
| FT-15 · P2 | **The color hierarchy feels off after finishing.** Today shows a large white Done Today panel in dark mode, then a bright + New Routine button. The capture also shows a second + New Routine action under No Active Block. `IMG_5434.png`. | Review the finish-to-summary-to-Today transition in light and dark. The completed workout and its View action are easy to find, and the next action reads clearly. Verify the no-routine/no-block state presents one relevant routine-creation action. | **Add to T-DONE acceptance in step 1.3.** The planned state slab already changes the completed-workout layout. The precise color treatment and the transition from the summary need a visual check. [Done Today source][done-source] · [T-DONE layout][today-done] · [Redesign step 1.3][plan-state] |

## Muscle volume and heatmap

| ID | What went wrong | Done when | Roadmap reconciliation |
| --- | --- | --- | --- |
| FT-16 · P2 | **The front and back heatmap are cut off.** Both diagrams end around the hips despite the blank space below. Lower-body regions are hard to inspect or tap. `IMG_5427.png`. | Both diagrams and every lower-body region can be reached in the normal scroll flow on small and large phones. The bottom of the map clears the tab bar and safe area. | **Add clipping acceptance to redesign step 1.4.** The existing plan moves the full surface into Progress → Volume with a shortcut from Today. Step 2.5 already handles the date label and collapsed untrained rows. [Redesign step 1.4][plan-volume] · [Step 2.5][plan-volume-polish] |
| FT-17 · P2 | **The route to a detail page for each muscle isn't obvious.** The app already has `PerMuscleDetailView`, and the volume bars and most map regions route there from Today. The visible neck tile is decorative in the map. | Each tracked muscle has a discoverable path into its own detail from the volume list and its corresponding heatmap regions. Resolve how to surface neck if the labeled tile is meant to offer detail. Check entry from both Today and Progress. | **Verify VOL-05 and step 1.4.** Reuse the existing detail and route. D-160 already records the small map targets. [VOL-05][vol] · [Audit D-160][d160] · [Heatmap routes][fatigue-routes] · [Neck tile][heatmap-tap] |
| FT-18 · P2 | **The dark volume chart doesn't show current progress clearly.** The hamstrings card says 2 sets and MEV 4, but the dark fill is easy to miss next to the track and threshold marks. Zero-set and under-target states also need a clearer visual distinction. `IMG_5428.jpeg`, `IMG_5429.png`. | The current fill or marker is obvious against the track, the MEV/MAV/MRV landmarks read separately, and zero sets, under target, and in-range states are distinguishable in dark appearance. The 2-of-4 hamstrings case works at a glance. | **Extend VOL-04 and Volume polish.** The roadmap already calls out the heatmap's absent versus below-MEV colors. Step 2.5 covers collapsed untrained rows and the date label, so add bar contrast and current-volume readability explicitly. [VOL-04][vol] · [Roadmap release checks][release] · [Step 2.5][plan-volume-polish] |

## iPhone Live Activities and app icon

| ID | What went wrong | Done when | Roadmap reconciliation |
| --- | --- | --- | --- |
| FT-19 · P1 | **“Always Allow” keeps appearing and its text was missing or broken.** Reported while Do Not Disturb was on. The sequence and the exact system prompt need physical-device reproduction. | Record the full prompt and when it reappears. Check first use, already allowed, and denied states with Focus on and off. The prompt is legible and ordinary rest starts respect the chosen authorization state. | **Add a specific repro under P2 Live Activities release quality.** Keep permission and prompt behavior separate from the blank rendering symptom. [Product roadmap][roadmap-priorities] · [Activity authorization path][live-controller] |
| FT-20 · P1 | **The Lock Screen Live Activity appears blank.** The capture shows an empty card below the music player, with no workout or countdown text. `IMG_5432.jpeg`. | On a physical iPhone, log a set and verify the workout rest countdown on the Lock Screen and Dynamic Island. Check backgrounding, timer adjustment, expiry, and cleanup when the workout ends. Repeat with music active to match the capture. | **Existing P2 Live Activities release quality and SESS-04.** The widget extension is embedded on `main`. Track the phone symptom as a rendering or lifecycle investigation, with the cause open. [Product roadmap][roadmap-priorities] · [SESS-04][sess] · [Widget target][widget] |
| FT-21 · P3 | **The app icon looks wrong in the installed build.** This is reported in the notes. The captures show the app and media surfaces, so the Home Screen icon needs its own capture. | Compare the actual installed Home Screen icon against the intended artwork and verify the selected icon in the installable build and appearance modes. | **Add a branding verification item.** The native icon was delivered in Milestone 1 and the asset catalog points to one universal image. [Milestone verification][icon-verified] · [Icon asset definition][icon] |

## Suggested roadmap edits

1. **Logger pass.** Group the two exit/navigation findings, exercise removal, and set-entry usability into one gym-day workflow pass. Use the D-64, D-84, D-90, and D-270 audit rows for the exact matches. Give same-workout carry-forward its own behavior and acceptance.
2. **Today and Volume redesign.** Add completed-state color to step 1.3 and map clipping and detail navigation to step 1.4. Add volume readability to step 2.5 and record the Resume color decision against T-RESUME. [Redesign plan][plan] · [Today state rules][hierarchy]
3. **Physical-device pass.** Put the repeated prompt and blank card under the existing Live Activities roadmap item as two device reproductions. Keep the icon as a separate branding verification. [Roadmap release checks][release]

## Resolution, November 8, 2026

Every finding was handled the same day, as quick task `.planning/quick/261108-ftx-resolve-playtest-findings/`.
Code fixes landed one commit per group.
Device-only findings have reproduction steps below and a home in the roadmap.

| ID | Status | What changed |
| --- | --- | --- |
| FT-01 | Shipped | Discard is in the logger's ••• menu with and without logged sets; with sets, the confirmation names what is lost and Keep logging keeps the workout. |
| FT-02 | Shipped | The logger lives on Today's stack only. Program's RESUME ▸, a session's START WORKOUT ▸ and the Live Activity open it through one request, so ‹ and swipe Back always land on Today, where RESUME ▸ reopens the same workout. |
| FT-03 | Shipped | The exercise header has a visible menu with Remove from workout; with logged sets, the confirmation says they will be removed from this workout. |
| FT-04 | Shipped | The in-workout picker has one header: Cancel, Add Exercise, + New. |
| FT-05 | Shipped | Single-Leg Kneeling Leg Curl (hamstrings, machine) joined the seed at version 3; existing installs re-seed without touching history or custom exercises. |
| FT-06 | Shipped | A logged working set carries its weight and reps to the next untouched working set; RPE never carries; + Add Set offers the last set's reps once it is logged. |
| FT-07 | Shipped | PREVIOUS is LAST TIME; tapping the heading explains it; an empty cell reads "none yet". |
| FT-08 | Shipped | The effort squares carry an RPE label on their own row; the floating RPE heading is gone. |
| FT-09 | Shipped | Why this weight? is a named action in the exercise menu, open after logging too, and names the recommended weight when the logged load differs. |
| FT-10 | Shipped | One set-type picker shows the current choice; the set label carries a small W/UP, DROP, FAIL or RP tag. |
| FT-11 | Shipped | The inline plate graphic under the weight field is gone; plates stay in the WHY sheet and the calculator. |
| FT-12 | Shipped | Each exercise collapses to its header with set count and completion; the finished summary opens compact and each exercise expands to its sets. |
| FT-13 | Deferred | The finish confirmation stays a stock alert, which already carries the set count and elapsed time; a BRU sheet waits until the gym day is stable, as `docs/DEVELOPMENT.md` defers polish on moving workflows. |
| FT-14 | Shipped | Dark slabs draw on `bruSlab`, constant dark (`#0A0A0A` light, warm charcoal `#1F1C16` dark) with `bruOnSlab` text; light mode is unchanged. |
| FT-15 | Shipped | The Done slab shares `bruSlab`; with no block, Today shows one routine action, the picker's + New routine. |
| FT-16 | Device check | The simulator shows both figures whole, so the cut-off needs a phone capture; steps below, acceptance recorded on redesign step 1.4. |
| FT-17 | Shipped | Volume opens from Progress › Volume; every region, the neck included, and every bar open the muscle's detail; a caption says so and the bars carry ›. |
| FT-18 | Shipped | Muscles under MEV draw amber on the bars, the figures and the legend's UNDER MEV cell. |
| FT-19 | Device check | Permission and prompt behaviour needs the phone; steps below, under the roadmap's Live Activities item. |
| FT-20 | Shipped, then device check | The widget extension had neither the app's fonts nor its asset catalog, so the card's text and colours had nothing to draw with; both are in the extension now with every font registered. The Lock Screen check remains on the phone; steps below. |
| FT-21 | Device check | Compare the installed icon with `AppIcon.appiconset`; steps below, under the roadmap's release checks. |

### Device reproductions

FT-16, heatmap reach.
1. Install the current `main` on the phone, open Progress › Volume and scroll to the FRONT and BACK figures.
2. Confirm both figures show the calves and that the map's bottom clears the tab bar; tap a calf on each figure and expect its detail.
3. Repeat on a 6.1-inch phone or at the 390pt simulator width; capture any clipping with the phone model and text size.

FT-19, the repeated "Always Allow" prompt.
1. Delete the app, install `main`, start a workout and log one set with Focus off; record the exact prompt text and the choices it offers.
2. Choose Allow, log another set, and note whether the prompt returns.
3. Repeat from a fresh install with Focus on, then with Live Activities denied in Settings › Fitbod; the rest must still start in the app, and an answered prompt must not come back.

FT-20, the Lock Screen Live Activity.
1. With music playing, log a set, lock the phone and confirm the card shows the exercise and the countdown; check the Dynamic Island compact and expanded views.
2. Adjust the rest by -15 s and +15 s from the app, let one rest expire, background the app during a rest and finish the workout; the card must update each time and leave when the workout ends.
3. If the card is blank again, capture it with the phone model and iOS version and note whether the app was in the foreground.

FT-21, the app icon.
1. Capture the Home Screen icon in light, dark and tinted appearance.
2. Compare each with `fitbod/Assets.xcassets/AppIcon.appiconset` and note which build was installed.

[roadmap]: https://github.com/Saechaoc/fitbod/blob/main/docs/ROADMAP.md
[roadmap-priorities]: https://github.com/Saechaoc/fitbod/blob/main/docs/ROADMAP.md#L16-L26
[gym-day]: https://github.com/Saechaoc/fitbod/blob/main/docs/ROADMAP.md#L34-L50
[frozen]: https://github.com/Saechaoc/fitbod/blob/main/docs/ROADMAP.md#L52-L54
[release]: https://github.com/Saechaoc/fitbod/blob/main/docs/ROADMAP.md#L142-L153
[audit]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/audit.md
[d64]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/audit.md#d-64
[d84]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/audit.md#d-84
[d87]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/audit.md#d-87
[d90]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/audit.md#d-90
[d160]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/audit.md#d-160
[d270]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/audit.md#d-270
[plan]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/plan.md
[plan-state]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/plan.md#L19-L22
[plan-volume]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/plan.md#L20
[plan-volume-polish]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/plan.md#L37
[changelog]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/changelog.md#2026-11-07-step-12-landed
[hierarchy]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/hierarchy.md#state-table
[today-resume]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/today-layouts.md#t-resume
[today-done]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/today-layouts.md#t-done
[today-back]: https://github.com/Saechaoc/fitbod/blob/main/docs/design-map/redesign/today-layouts.md#L374
[sess]: https://github.com/Saechaoc/fitbod/blob/main/.planning/REQUIREMENTS.md#L33-L45
[pres]: https://github.com/Saechaoc/fitbod/blob/main/.planning/REQUIREMENTS.md#L53-L64
[vol]: https://github.com/Saechaoc/fitbod/blob/main/.planning/REQUIREMENTS.md#L78-L86
[logger-menu]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SessionLoggerView.swift#L269-L289
[finish]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SessionLoggerView.swift#L152-L172
[exercise-menu]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SessionExerciseCard.swift#L136-L155
[logger-rows]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SessionExerciseCard.swift#L329-L360
[summary-rows]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SessionDetailView.swift#L201-L227
[picker]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/AddUnplannedExerciseButton.swift#L44-L58
[catalog]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Resources/ExerciseSeed/exercises.json
[planned-sets]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SessionFactory.swift#L282-L308
[add-set]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SessionSetActions.swift#L76-L100
[previous]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/PreviousColumn.swift#L30-L77
[history-selector]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/PreviousMatchingIntent.swift#L82-L119
[rpe]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/InlineRPEChipRow.swift
[why]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SetRow.swift#L252-L279
[set-type]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SetTypeChip.swift
[plates]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/SetRow.swift#L284-L301
[resume-source]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Views/ResumeWorkoutSlab.swift
[done-source]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Views/DoneTodaySlab.swift#L65-L96
[ink]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Assets.xcassets/bruInk.colorset/Contents.json
[fatigue-routes]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Fatigue/FatigueSurfaceView.swift#L283-L355
[heatmap-tap]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Fatigue/BodySilhouetteView.swift#L164-L203
[live-controller]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Sessions/RestTimer/RestTimerActivityController.swift#L83-L115
[widget]: https://github.com/Saechaoc/fitbod/blob/main/fitbod.xcodeproj/project.pbxproj#L49-L57
[icon-verified]: https://github.com/Saechaoc/fitbod/blob/main/docs/VERIFICATION.md#L89-L105
[icon]: https://github.com/Saechaoc/fitbod/blob/main/fitbod/Assets.xcassets/AppIcon.appiconset/Contents.json
