# Interaction

How BRU controls respond to touch, and the rules that keep set logging fast with one hand.

## Touch targets

- Every tappable element has a hit area of at least 44 × 44pt.
- Small text links ("+ Add session", "‹ Back") stay small visually and use `.bruHitArea()`, which pads the hit area by 12pt per side and enforces at least 44pt. Short labels may gain a few points of layout height (`fitbod/Design/BRUHitArea.swift`).
- Full-width rows claim their whole frame with `.contentShape(Rectangle())`.
- Visual elements smaller than 44pt, such as the 22pt set square, sit inside a 44pt frame (`SetCompletionGlyph` documents this).
- Buttons use `.buttonStyle(.plain)` or `BRUButtonStyle`, never system bordered styles.

## Control states

| State | How it looks | Where |
| --- | --- | --- |
| Default | The kind's fill, text and border | All controls |
| Pressed | Fill turns ink; a ghost button inverts to an ink slab. No animation needed. | `BRUButtonStyle` |
| Disabled | `bruFaint` fill, `bruMuted` text, `bruHair` border. Text stays readable instead of the whole control fading. | `BRUButtonStyle`, `BRUStepper` step buttons |
| Selected | Ink fill with paper text, plus the VoiceOver selected trait | `BRUSegmentedControl`, `BRUTabBar` |
| On / off | Off: paper track, ink knob. On: signal track, constant ink knob. | `BRUToggleStyle` |
| Completed | Filled signal square; completed rows use `bruFaint` | `SetCompletionGlyph`, set rows |
| Error | A message in words next to the field that caused it. The blocked action stays visible. | Form fields such as the custom exercise name |
| Empty | A condensed headline, one sentence of help, and one action that fixes it | Library, history, Program |

## Confirmation

- Destructive actions (discard a workout, delete a routine or session) ask once before acting.
- The dialog names the consequence, and the destructive button uses the verb ("Discard workout"), never "OK".
- Cancel is always available and never destructive.
- Reversible actions (removing a set, reordering) act immediately without a dialog.

## Set logging, one-handed

- Rest controls are docked at the lower safe-area edge. Completion stays next to the set being edited; the list scrolls to bring the active set within reach.
- The weight cell starts from the prescribed weight, and reps use the number pad, so a set needs at most one short entry before it is completed.
- One signal CTA per screen: in a workout it is the action that moves the session forward.

## Rest timer

- The timer stores an absolute end time, not a counter. The remaining time is always "end time minus now".
- It therefore stays correct after the app goes to the background, is killed or the phone locks.
- −15 s and +15 s move the end time; Skip ends the rest at once.

## Motion and haptics

- Motion is short and functional. Respect Reduce Motion when adding animation; the rest progress arc, PR banner and shared toggle already expose that behavior. Audit screen-level transitions separately.
- Haptics confirm a new personal record during a workout and give selection feedback while dragging to reorder.

Accessibility rules that go with these: [accessibility.md](accessibility.md).
