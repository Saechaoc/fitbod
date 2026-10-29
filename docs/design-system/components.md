# Components

Every BRU component lives in `fitbod/Design/` and has a SwiftUI `#Preview`.
DEBUG builds show them all, in their states, in the component gallery: Settings › Developer › Component gallery (`BRUComponentGallery`).
Read a component's file header before using it: each one documents its contract and usage.

"Reference" names the screen in `bru-screens/Fitbod-Session/screens/` where the component first appears.

## Chrome

| Component | What it is | Variants and states | Replaces | Used on | Reference |
| --- | --- | --- | --- | --- | --- |
| `BRUHeaderBar` | Screen header: left action, centered title, right action, 2pt ink rule | `HeaderAction` init or `.slots(left:center:right:)` with `.back`, `.cancel`, `.action`, `.text`; signal-colored actions; title wraps to two lines | `.navigationTitle`, `.toolbar` | About 40 screens and sheets | Every screen |
| `BRUTabBar`, `BRUTab` | Bottom bar for Today, Program, Progress and Library | Active cell is ink with paper text and the selected trait | System tab bar | `RootView` | `phase-2--today.png` |
| `BRUSectionHead` | Section strip between 2pt rules: title on the left, metadata or an action on the right | Plain, with right text, with a tappable right action | `Section` headers | About 23 screens | `phase-2--today.png` |
| `BRUDivider` | Horizontal rule | `.hair` (1pt `bruHair`), `.ink` (2pt `bruInk`) | `Divider()` | About 42 screens | Every screen |

## Actions

| Component | What it is | Variants and states | Replaces | Used on | Reference |
| --- | --- | --- | --- | --- | --- |
| `BRUButton`, `BRUButtonStyle` | Square button | Kinds `.primary` (ink), `.signal` (the one CTA), `.ghost` (outline); sizes `.sm`, `.md`, `.lg`; pressed and disabled states | `.bordered`, `.borderedProminent` | About 25 screens | `phase-2--routine-builder.png` |
| `BRUPillButton` | Full-width signal CTA ("Start workout ▸"). A rectangle despite the name. | Default, pressed, disabled; shares `BRUButtonStyle` | Prominent system buttons | Today slab, resume slab and banner | `phase-2--today.png` |
| `BRUDashedSlot` | Dashed "+ Add exercise ↘ From library" slot | Label plus hint | Plain add rows | Session builder, workout logger | `phase-2--routine-builder.png` |
| `BRUActionPopover` | Square-cornered menu | A list of titled actions | `confirmationDialog` menus | Program "New" menu | `phase-2--program-newmenu.png` |
| `.bruHitArea(_:)` | Modifier that grows a hit area to at least 44pt | Default 12pt per side; negative outer padding preserves most layout, but very short labels can grow | Manual padding | Small text links | Every screen |

## Inputs

| Component | What it is | Variants and states | Replaces | Used on | Reference |
| --- | --- | --- | --- | --- | --- |
| `BRUStepper` | Label, − value +, 44pt step buttons, one adjustable VoiceOver element | Disabled ends of the range; label above the control at accessibility sizes | `Stepper` | Settings, exercise detail, session builder cards | `phase-6--settings.png` |
| `BRUSegmentedControl` | Square segmented choice | Selected segment is ink with paper text and the selected trait | `Picker` with `.segmented` | Settings units | `phase-6--settings.png` |
| `BRUToggleStyle` | `.toggleStyle(.bru)`: square switch | Off: paper track, ink knob. On: signal track, constant ink knob. Respects Reduce Motion. | System toggle style | Exercise detail, session builder cards | `phase-6--settings.png` |
| `BRUChip` | Square label for tags and filters | Outline or filled, any token color, uppercase or as typed | Capsule tags | About 26 screens | `phase-1--library.png` |
| `PlateTallyRow` | Plate inventory row whose tally boxes are the input | Counts 0 to the maximum, "None" | `Stepper` | Plate calculator, plate inventory | `phase-3--plate-calc.png` |

## Data display

| Component | What it is | Variants and states | Replaces | Used on | Reference |
| --- | --- | --- | --- | --- | --- |
| `BRUDisplay` | Space Grotesk display text | `.hero` 56, `.large` 32, `.medium` 18 | Large system titles | About 10 screens | `phase-2--today.png` |
| `BRUReadout` | Stat cell: small label over a large value | Optional value color | `LabeledContent` | Today and history stat strips, workout summary | `phase-2--today.png` |
| `BRUCornerBadge` | Tiny badge on a corner ("DL", "PR") | Any fill and text token | Overlay badges | Week ticker, block cards, history rows | `phase-2--history.png` |
| `BRUSpark` | Eight-bar mini chart | Highlighted trailing bar | Small charts | Weekly tonnage card | `phase-2--history.png` |
| `SetCompletionGlyph` | 22pt set square inside a 44pt target | Incomplete (1.5pt ink outline), complete (signal fill) | Checkmark symbols | Workout set rows | `phase-2--active-session.png` |
| `BRUSupersetBracket` | Signal bracket on the left of grouped exercises | Any number of rows | Grouped list styling | Session builder cards | `phase-2--modal-superset.png` |
| `PlateStackViz` | Plates drawn to scale on a bar | Scales with height | None | Warm-up rows, plate disclosure, plate calculator | `phase-3--plate-calc.png` |
| `CalibratingProgressMeter` | Progress card while an exercise is calibrating | Progress clamped to its range | `ProgressView` | Why-this-weight sheet | `phase-3--why-weight.png` |
| `LiveEditBanner` | Warning that a routine is on the active block | Signal stripe, label, body | Inline alerts | Routine detail, session builder | None (from the program graph spec) |

## Layout and tooling

| Component | What it is | Notes |
| --- | --- | --- |
| `BRUFlowLayout` | `Layout` that wraps chips onto new lines | Keeps chip rows whole at 390pt and at accessibility sizes |
| `BRUPhoneFrame` | DEBUG-only 390 × 844pt frame for previews | Never used in app code |
| `BRUComponentGallery` | DEBUG-only screen listing reusable components in their states | Native UI tests open the gallery and verify real action feedback |

Foundations: [color.md](color.md), [typography.md](typography.md), [layout.md](layout.md).
