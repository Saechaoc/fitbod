# Conventions

Every file in the design map follows these rules.
`tools/check_map.py` checks the rules marked "(checked)"; [Checks](#checks) lists what it does.

## Words

Use the words the app shows, never code names.

| In the app | In the code |
|---|---|
| Routine | `Split` |
| Session | `SessionTemplate` |
| Workout (a logged one) | `Session` |
| Block | `Block` |

- Code names appear only in `view` paths and in backticked file references.
- Write plain English in full sentences, with one sentence per line.
- Never use the em dash; use a plain dash. (checked)

## Names

- Each screen, sheet, cover, dialog, alert and system sheet has an id made of lowercase words joined by `-`. (checked)
  Dialog and alert ids start with `dialog-`.
- Its file is `screens/<id>.md`.
- A state of a screen is named `<id>--<state>`, such as `today--empty`.
- A screenshot is `screens/img/<phone>-<size>-<appearance>-<id>[--<state>].png`.
  The phone is `17e` (390 pt wide) or `17promax` (440 pt wide).
  The size is `default` or `ax3` (the Accessibility Extra Large text size).
  The appearance is `light` or `dark`.
- Screenshots are stored at 2x scale, so 2 pixels are 1 point on both phones.
  The full-size originals stay out of the repository.
- An accessibility tree is `screens/tree/<id>.txt`, taken on the 17e in light mode at default text, in the main state.

## Paths

- `view`, `mock` and file references in prose are repo-root paths in backticks, with an optional `:line` or `:first-last`, such as `fitbod/Views/TodayView.swift:38`. (checked)
- `img`, `tree` and Markdown links are relative to the file that holds them. (checked)

## Screen files

The front matter is plain `key: value` lines and `[a, b]` lists, read without a YAML library.

| Key | Holds |
|---|---|
| `id` | the file name without `.md` |
| `kind` | `screen` (a tab root or a pushed screen), `sheet`, `cover`, `dialog`, `alert` or `system` (drawn by iOS) |
| `title` | the title as the lifter sees it |
| `view` | the SwiftUI view that draws it, as `path:line` |
| `tab` | `today`, `program`, `progress`, `library`, `settings` (inside the Settings sheet), `none`, or a list of them |
| `presents_from` | the ids of the screens that open it; `x-launch` stands for the app's launch |
| `closes_with` | `back`, `cancel`, `done`, `close`, `verb` (a named action such as SAVE) or `none` |
| `mock` | the `bru-screens/` mock-up it was designed from, or `none` |
| `seed` | the launch arguments of the main screenshot, or `none` |
| `captured` | the capture date and the commit, such as `2026-11-01 61353088` |
| `img` | the screenshots, main state first |
| `tree` | the accessibility tree, or `none` |

The body starts with one sentence on what the lifter does here.
These sections follow, in this order: (checked)

1. `## Entry points`: a table of From, Tap and Kind (push, sheet, cover or dialog).
2. `## Exits`: a table of Control, Goes to, Kind and Closes with.
3. `## States`: a table of State, How to reach it and Screenshot.
4. `## Compared with the mock-up`: a table of In the mock-up, In the app and Difference.
5. `## VoiceOver order`: three to eight lines from the tree, then any gaps.
6. `## Findings`: links to audit rows, such as `[D-03](../audit.md#d-03)`.

AX3 and dark screenshots are listed where the layout changes.
Where only colour and size change, one line under States says so.
A file that is not written yet holds the line `<!-- skeleton -->`.

## Dialog files

Dialogs and alerts use the same front matter plus `message` (the text under the title, or `none`) and `buttons` (the labels in order).
Their sections are `## Trigger`, `## Buttons`, `## Copy check`, `## Screenshot` and `## Findings`. (checked)

## Workflow files

A workflow file is `workflows/<job>.md`.
Its front matter holds `id`, `job` (one sentence), `start` and `end` (screen ids), `taps_min` (the fewest taps from start to end) and `screens` (every screen id the job passes). (checked)
Its sections are `## Steps`, `## Flow`, `## Tap count`, `## Dead ends`, `## Detours`, `## No clear way back` and `## Findings`. (checked)
Steps are numbered from the lifter's point of view, with the screen id of each step.
Flow is a Mermaid flowchart that reuses the screen ids.

## Missing screens

`missing-screens.md` holds one table with the columns `id | Screen or state | Workflow that needs it | Must show | Entered from | Importance | Source`. (checked)
Importance is `must`, `should` or `nice`.
Every `must` row has a mock-up, `mockups/<id>.html`, with its four renders `mockups/<id>-<390|440>-<light|dark>.png`. (checked)

## Audit

`audit.md` holds one table with the columns `ID | Screen | Problem | Evidence | Severity | Ticket`. (checked)

- IDs run `D-01`, `D-02` and on without gaps, and each ID cell starts with its anchor, as in `<a id="d-01"></a>D-01`. (checked)
- Severity is `blocker`, `major`, `minor` or `polish`, which are P0 to P3 on the ticket scale.
- Rows are sorted by severity, then by screen. (checked)
- Screen holds screen ids, missing-screen ids or `app`, separated by commas. (checked)
- Evidence is a screenshot link plus a backticked `path:line` where one is known.
- Ticket links the open ticket under `docs/conway-specs/tickets/`, or holds `-`. (checked)
  A problem that an open ticket already covers gets one row that links the ticket and does not describe the problem again.

A `## Patterns` section follows the table.
Each pattern is a `### P-<n> <rule broken>` heading with the design-system rule, the rows it groups and the one fix.

## Mermaid

- A node id is the screen id with each `-` turned into `_`. (checked)
- A screen is drawn as `id["Title"]`, a sheet or cover as `id(["Title"])`, a dialog or alert as `id{{"Title?"}}`, and system UI as `id[["Title"]]`. (checked in `navigation.md`)
- An edge `-->` is a push, and an edge `-.->` is a sheet, cover, dialog or system presentation.
  A label goes inside the arrow, as in `-->|Sessions|`.
- Each line holds one node or one chain of edges.
- Each tab is a `subgraph tab_<name>`, and a tab switch is not an edge.
- Ids with these prefixes are not screens: `tab_` for a tab, `q_` for a decision in a workflow, `x_` for something outside the app (the launch, the Live Activity), and `m_` for a missing screen, which must have a `missing-screens.md` row. (checked)

## Checks

`python3 -I docs/design-map/tools/check_map.py` exits 1 when any of these fails:

- Every screen file has the front matter keys, its id is its file name, and its `kind`, `tab` and `closes_with` use the words above.
- Every `view` and `mock` path and every backticked file reference exists, and its line number is inside the file.
- Every `img`, `tree` and Markdown link resolves, and every link to an audit row finds the row.
- `navigation.md` has one node for every screen file and no other app node, each drawn in its kind's shape, and its edges are exactly the screen files' `presents_from`.
- Every node in a workflow diagram, and every id in `screens`, `start` and `end`, names a screen file or a missing-screens row.
- Missing-screen ids are new and unique, and every `must` row has its mock-up and four renders.
- Audit rows run without gaps, are sorted, and link real tickets.
- No file uses the em dash.

Warnings do not fail the check: screenshots and trees that no file references, edges whose style does not fit the target's kind, and workflow diagrams that show a screen their `screens` list leaves out.
`--partial` reports files that are not written yet as warnings, for use while the map is being written.
`tools/check.sh` runs the same check and then renders every Mermaid block with mermaid-cli.
`python3 -I docs/design-map/tools/check_map.py --self-test` checks the checker's own parsers.
