# screen_budget.py - run: python3 -I screen_budget.py
# Element and tap budgets for the Today and Program redesign.
# Edit only the inputs. Counts are hand-tallied from the screenshots in
# docs/design-map/screens/img/ (current) and the wireframes in
# today-layouts.md and program-layouts.md (proposed).
#
# Counting rule: one element per separately styled block the eye stops on,
# above the fold at 390x844pt, default text size. A list of same-styled rows
# counts once. Each chip style counts once. A button counts once. The header
# bar counts once. A notice row counts once.
# "signal" counts elements drawn in the orange accent.
# "before_cta" counts elements between the header and the primary action.

ELEMENT_BUDGET = 8          # elements above the fold, per screen state
BEFORE_CTA_BUDGET = 2       # elements between the header and the primary action
SIGNAL_BUDGET = 1           # orange elements per screen

# state: (current elements, current signal, current before_cta,
#         proposed elements, proposed signal, proposed before_cta)
STATES = {
    "Today T-TODAY (block, session)":   (15, 2, 7,  8, 1, 1),
    "Today T-TODAY (deload week)":      (17, 2, 9,  8, 1, 1),
    "Today T-TODAY (advisory notice)":  (16, 2, 8,  9, 1, 2),
    "Today T-RESUME":                   (12, 2, 7,  6, 1, 1),
    "Today T-DONE":                     (15, 2, 7,  5, 0, 0),
    "Today T-DONE (no block, review)":  (13, 3, 4,  5, 0, 0),
    "Today T-REST":                     (11, 1, 7,  5, 0, 0),
    "Today T-FIX (empty session)":      (15, 2, 7,  6, 0, 0),
    "Today T-READY (review pending)":   (13, 3, 4,  7, 1, 1),
    "Today T-PICK (no block)":          (13, 3, 4,  7, 1, 0),
    "Today T-FIRST (fresh store)":      (13, 2, 4,  4, 1, 2),
    "Program P-ACTIVE":                 (12, 2, 0,  8, 0, 0),
    "Program P-PLANNED":                (10, 2, 0,  8, 1, 0),
    "Program P-EMPTY":                  (11, 1, 4,  4, 1, 2),
    "Program P-RESUME":                 (13, 3, 0, 10, 1, 0),
}

# States allowed over ELEMENT_BUDGET, each with the reason evaluation.md records.
ACCEPTED_OVER_BUDGET = {
    "Program P-RESUME": "transient; the resume banner adds its three elements to P-ACTIVE",
    "Today T-TODAY (advisory notice)": "transient; the advisory adds one row to T-TODAY until it is acted on or dismissed",
}

# job: (current taps, proposed taps, estimate?, everyday?)
# Current taps come from docs/design-map/workflows/*.md. None = not possible now.
# everyday marks jobs a lifter does most training days; only those must fit TAP_BUDGET.
TAPS = {
    "Start today's workout":                    (1, 1, False, True),
    "Resume a workout":                         (1, 1, False, True),
    "Start another session while a block runs": (4, 2, False, True),
    "Start a workout on a rest day":            (4, 2, False, True),
    "See this week's muscle volume from Today": (0, 1, False, True),   # current: a scroll, no tap
    "Start the ready block after one ends":     (4, 1, False, False),
    "Open the review right after a block ends": (0, 1, False, False),  # current: opens by itself
    "Reopen a finished block's review":         (None, 4, False, False),  # from Today: tab, list, block, Review
    "End a block whose plan is over":           (3, 3, False, False),
    "See muscle volume from Progress":          (None, 1, False, False),
    "First launch to first workout":            (17, 15, True, False),
}
TAP_BUDGET = 2  # for everyday workout tasks

# --- derived ---------------------------------------------------------------

print(f"{'state':34} {'elements':>12} {'signal':>10} {'before cta':>12}")
over_signal, over_before, over_elements, accepted = [], [], [], []
worst_state, worst_elements = None, -1
for name, (ce, cs, cb, pe, ps, pb) in STATES.items():
    print(f"{name:34} {ce:>5} -> {pe:<4} {cs:>4} -> {ps:<3} {cb:>5} -> {pb:<4}")
    if ps > SIGNAL_BUDGET:
        over_signal.append(name)
    if pb > BEFORE_CTA_BUDGET:
        over_before.append(name)
    if pe > ELEMENT_BUDGET:
        if name in ACCEPTED_OVER_BUDGET:
            accepted.append(f"{name} ({ACCEPTED_OVER_BUDGET[name]})")
        else:
            over_elements.append(name)
            if pe > worst_elements:
                worst_state, worst_elements = name, pe

cur_total = sum(v[0] for v in STATES.values())
new_total = sum(v[3] for v in STATES.values())
print(f"\nelements, all states: {cur_total} -> {new_total} "
      f"({100 * (cur_total - new_total) // cur_total}% fewer)")
print(f"states over {SIGNAL_BUDGET} signal element: {', '.join(over_signal) or 'none'}")
print(f"states over {BEFORE_CTA_BUDGET} elements before the action: {', '.join(over_before) or 'none'}")
print(f"states over {ELEMENT_BUDGET} elements above the fold: {', '.join(over_elements) or 'none'}")
print(f"accepted over budget: {', '.join(accepted) or 'none'}")

print(f"\n{'job':44} {'taps':>12}")
worst_job, worst_taps = None, -1
for name, (ct, pt, est, everyday) in TAPS.items():
    flag = "  (estimate, verify in Phase 1)" if est else ""
    cur = "n/a" if ct is None else ct
    print(f"{name:44} {cur:>4} -> {pt:<4}{flag}")
    if pt > worst_taps:
        worst_job, worst_taps = name, pt

over_taps = [n for n, (ct, pt, est, everyday) in TAPS.items()
             if everyday and pt > TAP_BUDGET and not est]
print(f"\neveryday jobs over {TAP_BUDGET} taps: {', '.join(over_taps) or 'none'}")

print("\nhotspot:",
      f"{worst_state} still shows {worst_elements} elements above the fold"
      if worst_state
      else f"{worst_job} at {worst_taps} taps")
