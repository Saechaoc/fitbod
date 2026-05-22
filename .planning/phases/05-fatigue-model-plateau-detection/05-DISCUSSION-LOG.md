# Phase 5: Fatigue Model & Plateau Detection - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `05-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-22
**Phase:** 5-fatigue-model-plateau-detection
**Areas discussed:** Volume scope + week boundary; Verb thresholds + bar style; Plateau detector signal + window; Deload advisory triggers + UI
**Mode:** Default interactive (single-question turns, effort = max)

---

## Area A — Volume scope + week boundary

### Set scope (which set types count toward weekly working-set volume)

| Option | Description | Selected |
|--------|-------------|----------|
| Working only (strict) | Only `setTypeRaw == 'working'`. Drop / failure / rest-pause excluded as extensions. | |
| Working + working modifiers | working = 1, drop = 1, failure = 1, rest_pause cluster = 1 total. Matches RP / Hevy convention. | ✓ |
| Working + drops only | working + drop count, failure / rest_pause excluded. | |

**User's choice:** Working + working modifiers.
**Notes:** Cluster sub-rep array length does NOT multiply count — one rest-pause set is one set total.

---

### Week boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Calendar week, Mon–Sun | Resets Monday midnight (`UserSettings.weekStartsMonday = true`). Aligns with weekly recap (VOL-07). | ✓ |
| Rolling 7-day window | Last 7 days from now; never resets. | |
| Both — user toggle | Calendar default, rolling toggle. | |

**User's choice:** Calendar week.
**Notes:** —

---

### Frequency-hit threshold (VOL-06)

| Option | Description | Selected |
|--------|-------------|----------|
| ≥1 weighted set (loose) | Any non-zero contribution. | |
| ≥2 weighted sets | Aligns with RP minimum-stimulus convention. | ✓ |
| ≥1 direct (primary-role) set | Strict; under-counts compound-driven volume. | |

**User's choice:** ≥2 weighted sets.
**Notes:** Stored as new additive field `UserSettings.frequencyHitMinSets: Int = 2`.

---

### Aggregation strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Compute on-demand | Pure-function FatigueModel.weeklyVolume(...); FOUND-07 stance; under perf ceiling. | ✓ |
| Denormalized WeeklyVolumeSnapshot @Model | Faster reads, invalidation surface. | |
| Compute on-demand + in-memory cache | Memoized middle-ground. | |

**User's choice:** Compute on-demand.
**Notes:** Pitfall #6 ceiling (~3000 rows) still safe at year-1 (~4500 sets) — re-evaluate at year 2 if dashboard lag.

---

## Area B — Verb thresholds + bar style

### Where 'near MRV — deload soon' starts

| Option | Description | Selected |
|--------|-------------|----------|
| Start at MAV | Zones: <MEV / MEV..<MAV / MAV..<MRV / ≥MRV. | ✓ (user free-text recommendation) |
| Start at MAV-MRV midpoint | Softer transition; more breathing room. | |
| Start at MRV-2 sets | Very late warning. | |

**User's choice:** Start at MAV. User supplied verbatim Swift implementation and verbatim copy strings (captured in CONTEXT D-05 + D-06).
**Notes:** User rationale captured: "MAV is the first fatigue warning boundary. Below MAV, volume is still in the productive/adaptive zone. Once volume reaches or exceeds MAV, additional sets may still be recoverable, but they are increasingly expensive and should be treated as the runway toward MRV." Midpoint rejected ("delays the warning too much") and MRV-2 rejected ("brittle because two sets means different things depending on muscle group and spread").

---

### Bar fill style (direct vs indirect)

| Option | Description | Selected |
|--------|-------------|----------|
| Two-tone direct + indirect | Solid accent for primary stimulus + lighter for secondary. | ✓ |
| Single-tone fill | One solid bar for total. | |
| Single bar + tappable popover | Hides split behind gesture. | |

**User's choice:** Two-tone direct + indirect.
**Notes:** —

---

### Week-over-week delta visibility

| Option | Description | Selected |
|--------|-------------|----------|
| Always show delta below verb | "+N vs last week" always. | ✓ |
| Delta only when significant (≥2 sets) | Hide when ≤1 set change. | |
| No delta | Lives in weekly recap only. | |

**User's choice:** Always show delta below verb.
**Notes:** —

---

### Heatmap color encoding

| Option | Description | Selected |
|--------|-------------|----------|
| Discrete zone colors matching bars | 4 colors mirror the bars (gray/green/amber/red). | ✓ |
| Continuous gradient (sets / MRV) | Smooth hue/saturation mapping. | |
| Two-tone overlay (direct/indirect on heatmap regions) | Most info-dense, risk of clutter. | |

**User's choice:** Discrete zone colors matching bars.
**Notes:** —

---

## Area C — Plateau detector signal + window

### Signal source

| Option | Description | Selected |
|--------|-------------|----------|
| Top-set e1RM, per intent | Highest e1RM working set per session, per intent stream. | ✓ |
| Avg working-set e1RM, per intent | Smoother but dampens peak signal. | |
| Top-set e1RM, pooled | No intent split. | |

**User's choice:** Top-set e1RM, per intent.
**Notes:** Reuses REQUIREMENTS PROG-02 partitioning (Brzycki ≤6, Epley 6–10, suppress >10).

---

### Window default

| Option | Description | Selected |
|--------|-------------|----------|
| Keep 4 sessions | Schema seed `plateauWindowSessions = 4`; 2–4 weeks of intent-matched data. | ✓ |
| Increase to 6 sessions | Larger sample, slower-to-flag. | |
| Decrease to 3 sessions | More aggressive; risk false-positive on a bad day. | |

**User's choice:** Keep 4 sessions.
**Notes:** —

---

### Tolerance default

| Option | Description | Selected |
|--------|-------------|----------|
| Bump to ±2% | Within typical biological noise but tight enough to catch real plateaus. | ✓ |
| Keep ±0.5% | Almost everything flags as stalled. | |
| Bump to ±5% | Only catches entrenched stalls. | |

**User's choice:** Bump to ±2%.
**Notes:** Schema seed updates from `plateauTolerance = 0.005` → `0.02` via SchemaV3 lightweight migration.

---

### Suggested action selection

| Option | Description | Selected |
|--------|-------------|----------|
| Auto-pick by signal pattern | Heuristic picks one action; single visible chip. | ✓ |
| Show all 4 as chips, user picks | No app opinion. | |
| Visual flag only, no actions | Punts on prescriptive half of PROG-06. | |

**User's choice:** Auto-pick by signal pattern.
**Notes:** Heuristic: muscle volume < MAV → addVolume; RPE creep ≥1.0 → dropIntensity; block week ≥3 heavy AND scheduled deload ≤2 weeks → deload; else → tryVariation.

---

## Area D — Deload advisory triggers + UI

### Trigger model

| Option | Description | Selected |
|--------|-------------|----------|
| Multi-signal OR | Any of e1RM drop >5%, RPE creep ≥1.0, missed reps >50% fires advisory. | ✓ |
| Multi-signal AND | All three required; rarely fires. | |
| Single signal: e1RM drop | Simplest; misses early signals. | |

**User's choice:** Multi-signal OR.
**Notes:** Each signal evaluated over 3 sessions / 3 weeks of working-exercise data.

---

### Trigger scope

| Option | Description | Selected |
|--------|-------------|----------|
| Whole-week aggregate | One advisory pooled across all working exercises this week + 2 prior. | ✓ |
| Per-muscle (lift group) | Aggregate per muscle; introduces "deload chest but not back" conflict. | |
| Per-exercise | Duplicates plateau detector signal. | |

**User's choice:** Whole-week aggregate.
**Notes:** Per-exercise stalls already covered by plateau detector (Area C).

---

### UI surface

| Option | Description | Selected |
|--------|-------------|----------|
| Today tab top banner + per-bar tint | Dismissible banner + amber ring; no push notif. | ✓ |
| Modal alert at session start | Blocks session start; risk reflexive dismiss. | |
| Push notification + Today banner | Adds nagging surface. | |

**User's choice:** Today tab top banner + per-bar tint.
**Notes:** No push notifications — personal-app stance.

---

### Dismissal scope

| Option | Description | Selected |
|--------|-------------|----------|
| This week + re-evaluate next Monday | Suppress current calendar week; re-fire Monday if signals persist. | ✓ |
| Suppress for entire current block | Could be silent for 4+ weeks. | |
| Suppress until signal clears + re-fires | Strict; might never re-fire. | |
| Suppress for this session only | Re-shows on every app open. | |

**User's choice:** This week + re-evaluate next Monday.
**Notes:** "Accept" never schedules a deload — block schedule canonical per BLOCK-08 + Pitfall #11.

---

## Claude's Discretion

User explicitly delegated at write-CONTEXT-now:
- Weekly recap (VOL-07) surface form (sheet detents, copy micro-variations, dismiss/snooze UX)
- Per-muscle detail view drill-down content (sections + ordering)
- `MuscleVolumeTarget` editor (SET-05) UI placement
- Per-exercise plateau threshold override (SET-06) editor placement
- Color saturation curves for `VolumeZone` heatmap palette
- `tryVariation` sheet detents + animation

---

## Deferred Ideas

Captured in `05-CONTEXT.md` `<deferred>` section. Highlights:
- Live PR detection (Phase 6 PROG-08)
- Per-exercise time-series chart (Phase 6 PROG-01)
- Weekly tonnage chart (Phase 6 PROG-04)
- Adaptive MEV/MAV/MRV auto-tune (v2)
- Push notification on plateau / deload — explicitly rejected
- "Adaptive deload schedule" auto-inserting deload weeks — explicitly rejected (BLOCK-08)
