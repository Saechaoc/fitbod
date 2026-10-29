# BRU design system

BRU is the visual language of the Fitbod iOS app: warm paper, black ink, one orange-red signal accent, condensed caps, square corners and ruled sections.
These docs define its tokens and rules and map each SwiftUI component to the reference design.
The code is the source of truth; these files explain it and must change when it does.

Status: milestone 1.

| Read this file | when you need |
| --- | --- |
| [principles.md](principles.md) | the rules every BRU screen follows |
| [color.md](color.md) | color tokens, their roles and contrast |
| [typography.md](typography.md) | type faces, roles, sizes, tracking and Dynamic Type |
| [layout.md](layout.md) | spacing, rules and borders, radii, fixed chrome, widths and safe areas |
| [iconography.md](iconography.md) | the glyphs that replace SF Symbols, and the app icon |
| [interaction.md](interaction.md) | touch targets, control states, confirmation, one-handed logging, rest timer |
| [accessibility.md](accessibility.md) | Dynamic Type, VoiceOver, contrast, and how to test them |
| [components.md](components.md) | every component, its states, what it replaces and where it is used |
| [tokens_check.py](tokens_check.py) | run it for the live color table and contrast ratios |
| [changelog.md](changelog.md) | what changed and why |

| Code | Where |
| --- | --- |
| Color tokens | `fitbod/Design/Color+BRU.swift`, `fitbod/Assets.xcassets/bru*.colorset` |
| Type roles | `fitbod/Design/BRUFont.swift` |
| Layout measurements | `fitbod/Design/BRUMetrics.swift` |
| Components | `fitbod/Design/` |
| Live gallery | DEBUG builds: Settings › Developer › Component gallery |
| Reference design | `bru-screens/Fitbod-Session/` (snapshot of the Claude Design project; one PNG per screen in `screens/`) |
