# capacity_model.py - run: python3 -I capacity_model.py
# Checks the ticket bundle, then estimates how long the run takes with one to four parallel lanes.
# Edit only the inputs. Keep them in sync with dispatch.md and assumptions.md.
# Standard library only, so isolated mode (-I) is safe.

import pathlib
import re
import sys

# ---- Inputs ------------------------------------------------------------------

SIZE_MINUTES = {"S": 45, "M": 75, "L": 120}  # worker wall time per ticket size
RUN_MINUTES = {"T46": 240}  # mostly simulator runs and 264 screenshots to review
COORDINATOR_REVIEW_MIN = 10  # accept checks per ticket (dispatch.md)
RETRY_RATE = 0.25  # share of tickets that need one retry
RETRY_COST = 0.5  # a retry costs this share of the ticket again
GATE_AFTER = ["T17", "T33", "T38", "T42", "T43"]  # phase gates in dispatch.md
GATE_MIN = 20  # full suite on the large phone (about 16 min at Phase 0) plus a widget build
FINDINGS_TICKETS_GUESS = 6  # new tickets from Phase 6, each size M
RERUN_TICKETS = ["T44", "T45", "T46"]  # rerun after the findings are fixed (dispatch.md)
FINAL_RERUNS = ["T44", "T47", "T48"]  # T48 changes app code after the runs, so Phase 8 reruns these (dispatch.md)
RERUN_MINUTES = {"T46": 120, "T48": 30}  # these reruns cover only the touched screens or the review page
PHASE8_MIN = 20
PARALLEL_OK = {"T31"}  # the coordinator does it beside the lanes, so it adds no serial time
CONDITIONAL = {"T43"}  # skipped when no newer design export exists
LANES = 3  # code workers at once, each ticket in its own worktree (dispatch.md)
LANE_OPTIONS = (1, 2, 3, 4)  # lane counts the estimate compares
SLOWDOWN = {1: 1.0, 2: 1.1, 3: 1.2, 4: 1.35}  # guess: workers share the Mac's cores, so each runs slower
MERGE_MIN = 8  # coordinator rebase, build and fast-forward when main moved; parallel runs only
EXCLUSIVE = {"T42", "T43", "T44", "T45", "T46", "T47", "T48"}  # run with no other code worker (dispatch.md)
REVIEW_ITEMS = [str(n) for n in range(1, 48)] + ["N1"]
HOTSPOT_MIN_OWNERS = 3
# Completed tickets whose files were removed from tickets/: id -> (phase, review items, files it planned to create).
# They count as done for depends_on, review item coverage and created files, and their ids are never reused.
ARCHIVED = {
    "T01": (1, [], ["fitbodUITests/UITestHelpersSelfTests.swift"]),
    "T02": (1, ["2", "25", "40"], ["fitbod/Design/BRUCountLabel.swift", "fitbodTests/LoggedWorkSetCountTests.swift"]),
    "T03": (1, ["1", "19"], ["fitbodUITests/CustomExerciseEntryUITests.swift"]),
    "T04": (1, ["2", "25"], ["fitbodUITests/SkipWarmupsUITests.swift"]),
    "T05": (1, ["3", "25"], ["fitbodUITests/DirtySheetDismissUITests.swift"]),
    "T06": (1, ["5", "6"], ["fitbodUITests/PrescriptionControlsUITests.swift", "fitbodTests/PrescriptionRangeTests.swift"]),
    "T07": (1, ["33", "41"], ["fitbodUITests/NotesSheetsUITests.swift"]),
    "T08": (1, ["34", "14"], ["fitbodUITests/OneTapShareUITests.swift"]),
    "T09": (1, ["4", "18"], []),
    "T10": (1, ["26", "27"], ["fitbodUITests/BlockTemplateCatalogUITests.swift"]),
    "T11": (1, ["36"], ["fitbodTests/BlockReadinessTests.swift", "fitbodUITests/NewBlockSavesUITests.swift"]),
    "T12": (1, ["28", "29", "25"], ["fitbodUITests/BlockOverviewStatesUITests.swift", "fitbodTests/BlockNumberingTests.swift"]),
    "T13": (1, ["31", "32"], ["fitbodUITests/PRListAndSeriesUITests.swift"]),
    "T14": (1, ["7"], ["fitbodUITests/HeatmapHitAreaUITests.swift"]),
    "T15": (1, ["8"], ["fitbodUITests/ProgramEmptyStateAX3UITests.swift"]),
    "T16": (1, ["9"], ["fitbodTests/AdaptiveColorSourceTests.swift", "fitbodUITests/ProgramDarkModeUITests.swift"]),
    "T17": (1, ["30", "16"], ["fitbodUITests/StripeAndBleedUITests.swift"]),
    "T18": (2, ["35", "43"], ["fitbod/App/EdgeSwipeBack.swift", "fitbodUITests/SwipeBackUITests.swift"]),
    "T19": (2, ["43", "37", "25"], ["fitbodUITests/PlateInventoryNavigationUITests.swift"]),
    "T20": (2, ["44"], ["fitbod/Periodization/ArchivedRoutinesView.swift", "fitbodUITests/ArchiveRoutineUITests.swift"]),
    "T21": (2, ["15"], ["fitbod/Routines/NewRoutineNameScreen.swift", "fitbodUITests/NewRoutineFlowUITests.swift"]),
    "T22": (2, ["39", "40"], ["fitbodTests/EmptyWorkoutCountTests.swift", "fitbodUITests/EmptyWorkoutCountsUITests.swift"]),
    "T23": (2, ["38", "25"], ["fitbodUITests/WeeklyTonnageUITests.swift"]),
    "T24": (2, ["45", "47"], ["fitbodUITests/PhaseRowsVoiceOverUITests.swift", "fitbodUITests/BlockNameTypingUITests.swift"]),
    "T25": (2, ["37", "46"], ["fitbodUITests/NewBlockLayoutUITests.swift"]),
    "T26": (2, ["37", "46", "25"], ["fitbodUITests/BlockAndRoutineTextFitUITests.swift"]),
    "T27": (2, ["46", "24", "25"], ["fitbodUITests/TodayAX3UITests.swift"]),
    "T28": (2, ["10", "11", "25"], ["fitbodUITests/RampAndStripsAX3UITests.swift"]),
    "T29": (2, ["12", "13", "17", "25"], ["fitbodUITests/SessionEditorPolishUITests.swift"]),
    "T30": (2, ["21"], ["fitbodTests/ExerciseDisplayNameSourceTests.swift", "fitbodUITests/ExerciseDisplayNameUITests.swift"]),
    "T31": (2, [], []),
    "T32": (2, ["20"], ["fitbodUITests/CustomExerciseEditorBRUUITests.swift"]),
    "T33": (2, ["42"], ["fitbodUITests/PinnedNoteSheetBRUUITests.swift"]),
    "T34": (3, ["25"], ["fitbodTests/UICopyRulesTests.swift", "fitbodUITests/CopySweepUITests.swift"]),
    "T35": (3, ["22", "24", "25"], ["fitbodUITests/TodayPolishUITests.swift"]),
    "T36": (3, ["23", "24"], ["fitbodUITests/RestSheetAndRPEChipsUITests.swift"]),
    "T37": (3, ["24", "25"], ["fitbodUITests/LibraryPolishUITests.swift"]),
    "T38": (3, ["25"], ["fitbodUITests/SmallFixesUITests.swift"]),
    "T49": (1, [], ["fitbodUITests/RPEDecimalHoldUITests.swift"]),
    "T50": (1, [], ["fitbodTests/WhyUsesFinishedWorkoutsTests.swift"]),
    "T51": (1, [], ["fitbodTests/PlateauUsesFinishedWorkoutsTests.swift"]),
    "T52": (1, [], ["fitbodTests/RPECreepEmptyWorkoutTests.swift"]),
    "T53": (1, [], ["fitbodUITests/StallBadgeWindowUITests.swift"]),
    "T54": (1, [], []),
    "T55": (1, [], ["fitbodUITests/PinnedNoteCapsuleTapTargetUITests.swift"]),
    "T56": (1, [], ["fitbodUITests/ProgressChartFitUITests.swift"]),
    "T57": (1, [], []),
    "T58": (1, [], []),
    "T59": (1, [], ["fitbodTests/SwapExercisePrescriptionTests.swift"]),
    "T60": (1, [], ["fitbodUITests/PlateInventoryDeleteUITests.swift"]),
    "T61": (1, [], ["fitbodTests/ZeroSuggestionTests.swift"]),
    "T62": (1, [], []),
    "T63": (1, [], ["fitbodUITests/ProgramHeaderAndSheetsAX3UITests.swift"]),
    "T64": (1, [], ["fitbodTests/ExerciseDetailPlateauCopyTests.swift"]),
    "T65": (1, [], ["fitbodTests/EditActiveBlockTests.swift"]),
    "T66": (1, [], ["fitbodUITests/TabBarBleedUITests.swift"]),
    "T67": (1, [], ["fitbodTests/BlockLifecycleEntryPointsTests.swift", "fitbodUITests/EndBlockFromCardUITests.swift"]),
    "T68": (1, [], []),
    "T69": (1, [], ["fitbodUITests/BlockBuilderBackLabelUITests.swift"]),
    "T70": (1, [], ["fitbodUITests/BlockReviewAfterEndUITests.swift"]),
    "T71": (1, [], []),
    "T72": (1, [], ["fitbodTests/Fatigue/OneSamplePerWorkoutTests.swift"]),
    "T73": (1, [], []),
    "T74": (1, [], ["fitbodUITests/AddPhaseSheetUITests.swift"]),
    "T75": (1, [], ["fitbodTests/SwapWarmupTests.swift"]),
    "T76": (1, [], []),
    "T77": (1, [], ["fitbodUITests/PlateInventorySwipeUITests.swift"]),
    "T78": (1, [], ["fitbodUITests/BlockWeekCountsUITests.swift", "fitbodTests/BlockPastPlanTests.swift"]),
    "T79": (1, [], []),
    "T80": (1, [], ["fitbod/App/CalibratingSetSeed.swift", "fitbodUITests/CalibratingWeightUITests.swift", "fitbodTests/CalibratingWeightCellTests.swift"]),
    "T81": (1, [], []),
    "T82": (1, [], []),
    "T83": (1, [], ["fitbodUITests/ActionPopoverFitUITests.swift"]),
    "T84": (1, [], ["fitbodTests/PreviousTopSetAcrossLogsTests.swift"]),
    "T85": (3, [], ["fitbodTests/PRRowTextTests.swift"]),
    "T86": (1, [], []),
    "T87": (2, [], ["fitbodUITests/TodaySheetOrderUITests.swift"]),
    "T88": (1, [], ["fitbodTests/SkipNextSessionWarmupTests.swift"]),
    "T89": (1, [], ["fitbodTests/WhySheetInputsTests.swift"]),
    "T90": (1, [], []),
    "T91": (1, [], ["fitbodTests/LastWorkoutRepsAcrossLogsTests.swift"]),
    "T92": (1, [], ["fitbodTests/WorkoutSetsInOrderTests.swift"]),
    "T93": (1, [], ["fitbodTests/WholeWorkoutReadersTests.swift"]),
    "T94": (1, [], ["fitbodTests/ExerciseRowsPerWorkoutTests.swift"]),
    "T95": (1, [], ["fitbodTests/StableExerciseNamesTests.swift"]),
    "T96": (2, [], ["fitbodTests/HistoryPRCountTests.swift"]),
    "T97": (2, [], ["fitbodTests/CalibratingStepCopyTests.swift"]),
    "T98": (3, [], ["fitbodTests/ProgressChartDescriptorTests.swift"]),
    "T99": (2, [], ["fitbodTests/BlockReviewPRCountTests.swift"]),
    "T100": (1, [], []),
    "T101": (2, [], ["fitbodTests/EdgeSwipeBackGuardTests.swift"]),
    "T102": (2, [], []),
    "T103": (2, [], []),
    "T104": (2, [], []),
    "T105": (2, [], []),
    "T106": (3, [], ["fitbod/Design/BRURowButtonStyle.swift"]),
    "T107": (3, [], ["fitbodUITests/PlateScreensFitUITests.swift"]),
    "T108": (3, [], ["fitbodUITests/BlockOverviewAndRoutineAX3UITests.swift"]),
    "T109": (3, [], []),
    "T110": (2, [], ["fitbodTests/SetRowsIgnoreOverridesTests.swift", "fitbodUITests/PerSetOverridesRemovedUITests.swift"]),
    "T111": (3, [], ["fitbodUITests/SessionEditorRowsUITests.swift"]),
    "T112": (2, [], ["fitbodUITests/ExerciseHistoryRowsUITests.swift"]),
    "T113": (3, [], ["fitbodTests/BlockReviewPRMarkTests.swift"]),
    "T114": (3, [], ["fitbodTests/WeeklyRecapTargetTests.swift"]),
    "T115": (2, [], []),
    "T116": (3, [], ["fitbodTests/HistoryTopSetTests.swift"]),
    "T118": (3, [], []),
}

BUNDLE = pathlib.Path(__file__).resolve().parent
REPO = BUNDLE.parents[1]  # the bundle lives in <repo>/docs/conway-specs
TICKETS = BUNDLE / "tickets"
SIMS = {"small", "large", "both", "none"}
FIELDS = ("id", "title", "phase", "items", "depends_on", "size", "sim", "owns")
SECTIONS = ("## Problem", "## Target", "## Change", "## Constraints", "## Ownership",
            "## Repro first", "## Observable acceptance", "## Hints")
RULES_LINE = "Read [../worker-rules.md](../worker-rules.md) first; it is part of this ticket."
EM_DASH = chr(0x2014)  # a code point, so this file passes its own em dash check
# Quoted existing UI copy may keep its em dash: (file name, text the line must contain).
EM_DASH_ALLOWED = {("T23-weekly-tonnage.md", f"No block data yet {EM_DASH} define a block in Routines.")}
TEST_NAME = re.compile(r"\b([A-Z][A-Za-z0-9]*Tests)\b")
TWO_SENTENCES = re.compile(r"[a-z0-9)\]`'\"]\.\s+[A-Z(]")
LIST_MARKER = re.compile(r"^\s*(?:\d+\.|-)\s+")
QUOTED = re.compile(r'"[^"]*"')  # quoted UI copy may hold two sentences


def parse_front_matter(text):
    """Returns (meta, body, body_start), where body_start is the body's first line number.
    Raises ValueError when the block is not closed."""
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        return None, text, 1
    end = lines.index("---", 1)
    meta = {}
    for line in lines[1:end]:
        key, _, value = line.partition(":")
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            value = [v.strip() for v in inner.split(",")] if inner else []
        meta[key.strip()] = value
    return meta, "\n".join(lines[end + 1:]), end + 2


_meta, _body, _start = parse_front_matter("---\nid: T99\nitems: [1, N1]\nowns: []\n---\nbody")
assert _meta == {"id": "T99", "items": ["1", "N1"], "owns": []} and _body == "body" and _start == 6
assert not TWO_SENTENCES.search(QUOTED.sub('""', 'It reads "No data yet. Define a block."'))
assert TWO_SENTENCES.search(QUOTED.sub('""', 'Tap "Save". Then check.'))

errors, warnings = [], []


def num(tid):
    return int(tid[1:])


def phase_of(tid):
    return tickets[tid]["phase"] if tid in tickets else ARCHIVED[tid][0]


def open_deps(tid):
    """Dependencies that still have a ticket file; an archived one is done."""
    return [d for d in tickets[tid]["depends_on"] if d in tickets]


def bundle_files(suffixes):
    for f in sorted(BUNDLE.rglob("*")):
        rel = f.relative_to(BUNDLE)
        if f.is_file() and f.suffix in suffixes and rel.parts[0] != "evidence":
            yield f, rel


# ---- Load tickets --------------------------------------------------------------

tickets = {}
for path in sorted(TICKETS.glob("T*.md")):
    text = path.read_text(encoding="utf-8")
    try:
        meta, body, start = parse_front_matter(text)
    except ValueError:
        errors.append(f"{path.name}: front matter is not closed with ---")
        continue
    if meta is None:
        errors.append(f"{path.name}: no front matter")
        continue
    missing = [k for k in FIELDS if k not in meta]
    if missing:
        errors.append(f"{path.name}: front matter lacks {', '.join(missing)}")
        continue
    tid = meta["id"]
    if not re.fullmatch(r"T\d{2,3}", tid):
        errors.append(f"{path.name}: bad id {tid!r}")
        continue
    if tid in tickets:
        errors.append(f"{path.name}: duplicate id {tid}")
        continue
    if tid in ARCHIVED:
        errors.append(f"{path.name}: {tid} is archived, so a new ticket needs a new id")
        continue
    if not path.name.startswith(tid + "-"):
        errors.append(f"{path.name}: the file name does not start with its id")
    if not meta["phase"].isdigit():
        errors.append(f"{tid}: phase {meta['phase']!r} is not a number")
        meta["phase"] = "0"
    meta.update(file=path.name, body=body, start=start, phase=int(meta["phase"]))
    tickets[tid] = meta

ids = sorted(tickets, key=num)

# ---- Validate tickets ----------------------------------------------------------

for tid in ids:
    t = tickets[tid]
    if t["size"] not in SIZE_MINUTES:
        errors.append(f"{tid}: size {t['size']!r} is not S, M or L")
    if t["sim"] not in SIMS:
        errors.append(f"{tid}: sim {t['sim']!r} is not one of {sorted(SIMS)}")
    lines = t["body"].splitlines()
    if f"# {tid}: {t['title']}" not in lines:
        errors.append(f"{tid}: no heading '# {tid}: {t['title']}'")
    if RULES_LINE not in lines:
        errors.append(f"{tid}: the worker-rules line is missing")
    for section in SECTIONS:
        if section not in lines:
            errors.append(f"{tid}: section '{section}' is missing")
    if "```" in t["body"]:
        errors.append(f"{tid}: has a code fence, and tickets hold no code")
    for n, line in enumerate(lines, t["start"]):
        if line.startswith(("|", "#")):
            continue
        if TWO_SENTENCES.search(QUOTED.sub('""', LIST_MARKER.sub("", line))):
            warnings.append(f"{t['file']}:{n}: may hold two sentences: {line.strip()[:80]}")
    for dep in t["depends_on"]:
        if dep not in tickets and dep not in ARCHIVED:
            errors.append(f"{tid}: depends on {dep}, which does not exist")
        elif num(dep) >= num(tid):
            errors.append(f"{tid}: depends on {dep}, which is not earlier")
        elif phase_of(dep) > t["phase"]:
            errors.append(f"{tid}: depends on {dep}, which is in a later phase")

covered = {}
for tid in ids:
    for item in tickets[tid]["items"]:
        if item not in REVIEW_ITEMS:
            errors.append(f"{tid}: unknown review item {item}")
        covered.setdefault(item, []).append(tid)
for tid, (_, items, _) in ARCHIVED.items():
    for item in items:
        covered.setdefault(item, []).append(tid)
uncovered = [i for i in REVIEW_ITEMS if i not in covered]
if uncovered:
    errors.append(f"review items with no ticket: {', '.join(uncovered)}")

created = {}  # repo path -> ticket that creates it
for tid, (_, _, new_files) in ARCHIVED.items():
    for path in new_files:
        created[path] = tid
for tid in ids:
    for p in tickets[tid]["owns"]:
        if not p.startswith("new:"):
            continue
        path = p[4:]
        if path in created:
            errors.append(f"{tid}: {path} is already created by {created[path]}")
            continue
        created[path] = tid
        if (REPO / path).exists():
            warnings.append(f"{tid}: new file {path} already exists in the repo")
for tid in ids:
    for p in tickets[tid]["owns"]:
        if p.startswith("new:") or (REPO / p).exists():
            continue
        creator = created.get(p)
        if not (creator and num(creator) < num(tid)):
            errors.append(f"{tid}: owned path {p} does not exist")

repo_tests = set()
for folder in ("fitbodTests", "fitbodUITests"):
    for f in (REPO / folder).rglob("*.swift"):
        repo_tests.add(f.stem)
        repo_tests.update(TEST_NAME.findall(f.read_text(encoding="utf-8", errors="replace")))
created_tests = {pathlib.PurePosixPath(p).stem: tid for p, tid in created.items()}
for tid in ids:
    for name in sorted(set(TEST_NAME.findall(tickets[tid]["body"]))):
        creator = created_tests.get(name)
        if name not in repo_tests and not (creator and num(creator) <= num(tid)):
            errors.append(f"{tid}: test {name} is not in the repo and no earlier ticket creates it")
rules_text = (BUNDLE / "worker-rules.md").read_text(encoding="utf-8")
for name in sorted(set(TEST_NAME.findall(rules_text))):
    if name not in repo_tests and name not in created_tests:
        errors.append(f"worker-rules.md: test {name} is not in the repo and no ticket creates it")

# ---- Validate the whole bundle -------------------------------------------------

index = (BUNDLE / "index.md").read_text(encoding="utf-8")
listed = {tid: (file, title.strip())
          for tid, file, title in re.findall(r"\| \[(T\d{2,3})\]\(tickets/([^)]+)\) \| ([^|]+)\|", index)}
for tid in ids:
    if tid not in listed:
        errors.append(f"index.md: {tid} is not listed")
    elif listed[tid] != (tickets[tid]["file"], tickets[tid]["title"]):
        errors.append(f"index.md: {tid} is listed as {listed[tid]}, "
                      f"but the ticket is {(tickets[tid]['file'], tickets[tid]['title'])}")
for tid in listed:
    if tid not in tickets:
        errors.append(f"index.md: lists {tid}, which has no ticket file")

headings = {}
for leaf in ("tradeoffs", "risks", "decisions"):
    leaf_text = (BUNDLE / f"{leaf}.md").read_text(encoding="utf-8")
    headings[leaf] = {h.strip() for h in re.findall(r"^#{2,4} (.+)$", leaf_text, re.M)}

for f, rel in bundle_files({".md", ".py"}):
    text = f.read_text(encoding="utf-8")
    for n, line in enumerate(text.splitlines(), 1):
        if EM_DASH in line and not any(f.name == name and snippet in line
                                       for name, snippet in EM_DASH_ALLOWED):
            errors.append(f"{rel}:{n}: em dash")
    if f.suffix != ".md":
        continue
    for target in re.findall(r"\]\(([^)#\s]+)(?:#[^)]*)?\)", text):
        if not target.startswith(("http://", "https://")) and not (f.parent / target).exists():
            errors.append(f"{rel}: broken link {target}")
    for title, leaf in re.findall(r'"([^"]+)" in \[(?:\.\./)?(tradeoffs|risks|decisions)\.md\]', text):
        if title not in headings[leaf]:
            errors.append(f"{rel}: no entry \"{title}\" in {leaf}.md")

for name, group in (("PARALLEL_OK", PARALLEL_OK), ("CONDITIONAL", CONDITIONAL), ("EXCLUSIVE", EXCLUSIVE),
                    ("GATE_AFTER", set(GATE_AFTER)), ("RERUN_TICKETS", set(RERUN_TICKETS)),
                    ("FINAL_RERUNS", set(FINAL_RERUNS)), ("RERUN_MINUTES", set(RERUN_MINUTES))):
    for tid in sorted(group - set(tickets) - set(ARCHIVED)):
        errors.append(f"capacity_model.py: {name} names {tid}, which has no ticket")
if LANES not in LANE_OPTIONS or any(n not in SLOWDOWN for n in LANE_OPTIONS):
    errors.append("capacity_model.py: LANES must be in LANE_OPTIONS, and each option needs a SLOWDOWN")

# ---- Report validation ---------------------------------------------------------

for w in warnings:
    print("WARNING", w)
for e in errors:
    print("ERROR", e)
print(f"\n{len(ids)} tickets, {len(errors)} errors, {len(warnings)} warnings\n")
if errors:
    sys.exit(1)

# ---- Estimate --------------------------------------------------------------------


def worker_min(tid):
    return RUN_MINUTES.get(tid, SIZE_MINUTES[tickets[tid]["size"]])


def work_min(minutes):
    """Worker minutes plus the expected cost of retries."""
    return minutes * (1 + RETRY_RATE * RETRY_COST)


def ticket_min(tid):
    return work_min(worker_min(tid)) + COORDINATOR_REVIEW_MIN


def rerun_work(tid):
    return work_min(RERUN_MINUTES.get(tid, worker_min(tid)))


def words(items):
    return items[0] if len(items) == 1 else f"{', '.join(items[:-1])} and {items[-1]}"


def plan_jobs(lanes, skip=frozenset(), gates=True):
    """Returns the whole run as jobs: name -> worker minutes, coordinator minutes, deps,
    owned files, lane use and run-alone flag.
    Adds the guessed findings tickets, the T44 and T45 reruns and Phase 8.
    With gates, each phase ends in a barrier that the next phase waits for; it is the phase gate
    when the phase has one. A skipped ticket takes no time, and its gate goes too."""
    jobs = {}
    review = COORDINATOR_REVIEW_MIN + (MERGE_MIN if lanes > 1 else 0)

    def add(name, work, fixed, deps, owns=(), lane=True, alone=False):
        jobs[name] = {"work": work, "fixed": fixed, "deps": list(deps), "owns": set(owns),
                      "lane": lane, "alone": alone}

    phases = sorted({tickets[t]["phase"] for t in ids})
    members = {p: [t for t in ids if tickets[t]["phase"] == p] for p in phases}
    for tid in ids:
        t = tickets[tid]
        deps = open_deps(tid)
        if gates and t["phase"] != phases[0]:
            deps.append(f"end of phase {phases[phases.index(t['phase']) - 1]}")
        owns = (p.removeprefix("new:") for p in t["owns"])
        if tid in skip:
            add(tid, 0, 0, deps, lane=False)
        elif tid in PARALLEL_OK:
            add(tid, 0, ticket_min(tid), deps, owns, lane=False)
        else:
            add(tid, work_min(worker_min(tid)), review, deps, owns, alone=tid in EXCLUSIVE)
    findings_phase = tickets["T46"]["phase"]
    findings = [f"finding {n + 1}" for n in range(FINDINGS_TICKETS_GUESS)]
    for name in findings:  # unknown files, so the model lets them run side by side
        add(name, work_min(SIZE_MINUTES["M"]), review, ["T46"])
    previous = findings
    for tid in RERUN_TICKETS:
        add(f"{tid} rerun", rerun_work(tid), review, previous, alone=True)
        previous = [f"{tid} rerun"]
    members[findings_phase] += findings + previous
    gate_phases = {phase_of(t) for t in GATE_AFTER if t not in skip}
    if gates:
        for p in phases:
            gate = p in gate_phases
            add(f"end of phase {p}", 0, GATE_MIN if gate else 0, members[p], lane=False, alone=gate)
    else:
        jobs["T47"]["deps"] += previous
    final = [f"end of phase {phases[-1]}"] if gates else ["T48"]
    for tid in FINAL_RERUNS:  # the code T48 changes needs fresh runs and docs before the push
        add(f"{tid} final rerun", rerun_work(tid), review, final, alone=True)
        final = [f"{tid} final rerun"]
    add("Phase 8", 0, PHASE8_MIN, list(jobs), lane=False, alone=True)
    return jobs


def simulate(jobs, lanes):
    """List-schedules the jobs on `lanes` workers, the way dispatch.md starts tickets.
    A job starts when its deps are done, a lane is free, no running job owns one of its files,
    and no job that runs alone is running. Earlier jobs go first, and a ready job that must run
    alone stops later jobs from starting until it has started.
    Worker minutes stretch by SLOWDOWN for the number of workers working at that moment;
    coordinator minutes, gates and Phase 8 do not stretch.
    Returns (finish minute, busy lane minutes)."""
    pending, left, start, end = list(jobs), {}, {}, {}
    now = 0.0
    while pending or left:
        hold = False
        for name in list(pending):
            job = jobs[name]
            if not all(d in end for d in job["deps"]):
                continue
            if job["alone"] and left:
                hold = True
                continue
            if (hold or any(jobs[r]["alone"] for r in left)
                    or (job["lane"] and sum(jobs[r]["lane"] for r in left) >= lanes)
                    or any(job["owns"] & jobs[r]["owns"] for r in left)):
                continue
            left[name] = [job["work"], job["fixed"]]
            start[name] = now
            pending.remove(name)
        if not left:
            raise RuntimeError(f"the schedule is stuck; waiting: {', '.join(pending[:5])}")
        stretch = SLOWDOWN[max(1, sum(1 for w, _ in left.values() if w > 0))]
        step = min(w * stretch if w > 0 else f for w, f in left.values())
        now += step
        for name in list(left):
            w, f = left[name]
            if w > 0:
                w = 0.0 if w - step / stretch < 1e-6 else w - step / stretch
            else:
                f -= step
            if w == 0.0 and f < 1e-6:
                end[name] = now
                del left[name]
            else:
                left[name] = [w, f]
    busy = sum(end[j] - start[j] for j in jobs if jobs[j]["lane"])
    return now, busy


print(f"Order (lowest id first; up to {LANES} code workers at once, each ticket in its own worktree;"
      " T31 runs beside them):")
for phase in sorted({tickets[t]["phase"] for t in ids}):
    row = [t for t in ids if tickets[t]["phase"] == phase]
    gates = [f"gate {n + 1}" for n, t in enumerate(GATE_AFTER) if phase_of(t) == phase]
    print(f"  Phase {phase}: {' '.join(row)}" + (f"  | {', '.join(gates)}" if gates else ""))
print("  Phase 8: coordinator only")

phase_min = {}
for tid in ids:
    if tid not in PARALLEL_OK:
        phase_min[tickets[tid]["phase"]] = phase_min.get(tickets[tid]["phase"], 0) + ticket_min(tid)
gates_min = len(GATE_AFTER) * GATE_MIN
findings_min = FINDINGS_TICKETS_GUESS * (SIZE_MINUTES["M"] * (1 + RETRY_RATE * RETRY_COST)
                                         + COORDINATOR_REVIEW_MIN)
reruns_min = sum(rerun_work(t) + COORDINATOR_REVIEW_MIN for t in RERUN_TICKETS)
final_min = sum(rerun_work(t) + COORDINATOR_REVIEW_MIN for t in FINAL_RERUNS)
total = sum(phase_min.values()) + gates_min + findings_min + reruns_min + final_min + PHASE8_MIN
skipped = sum(ticket_min(t) + (GATE_MIN if t in GATE_AFTER else 0) for t in CONDITIONAL)

print("\nSerial hours, including retries and coordinator checks:")
for phase, minutes in sorted(phase_min.items()):
    print(f"  Phase {phase}: {minutes / 60:5.1f} h")
print(f"  Gates:   {gates_min / 60:5.1f} h")
print(f"  Findings ({FINDINGS_TICKETS_GUESS} guessed M tickets): {findings_min / 60:.1f} h")
print(f"  Reruns of {words(RERUN_TICKETS)}: {reruns_min / 60:.1f} h")
print(f"  Final reruns of {words(FINAL_RERUNS)}: {final_min / 60:.1f} h")
print(f"  Phase 8: {PHASE8_MIN / 60:5.1f} h")
print(f"  Total:   {total / 60:5.1f} h, or {(total - skipped) / 60:.1f} h if "
      f"{', '.join(sorted(CONDITIONAL))} is skipped")

finish = {}
for tid in ids:  # deps always have lower ids, so id order is a topological order
    finish[tid] = max((finish[d] for d in open_deps(tid)), default=0) + ticket_min(tid)
chain = [max(finish, key=finish.get)]
while open_deps(chain[-1]):
    chain.append(max(open_deps(chain[-1]), key=finish.get))
print(f"\nDependency critical path: {' -> '.join(reversed(chain))}")
print(f"  {finish[chain[0]] / 60:.1f} h, a lower bound for any number of lanes")

print("\nParallel lanes: lowest id first, no two live tickets share an owned file, phases wait")
print(f"for their gates, and {', '.join(sorted(EXCLUSIVE))} and the reruns run alone (dispatch.md).")
print("Worker minutes stretch by SLOWDOWN, a guess for workers sharing the Mac's cores at once.")
for n in LANE_OPTIONS:
    stop, busy = simulate(plan_jobs(n), n)
    mark = "  <- the default in dispatch.md" if n == LANES else ""
    print(f"  {n} lane{'s' if n > 1 else ' '}: {stop / 60:5.1f} h, lanes busy {busy / (n * stop):4.0%}{mark}")
stop_skip, _ = simulate(plan_jobs(LANES, skip=CONDITIONAL), LANES)
stop_free, _ = simulate(plan_jobs(LANES, gates=False), LANES)
print(f"  At {LANES} lanes: {stop_skip / 60:.1f} h if {', '.join(sorted(CONDITIONAL))} is skipped, "
      f"or {stop_free / 60:.1f} h without phase gates, which the run keeps (tradeoffs.md)")

sim_min = sum(worker_min(t) for t in ids if tickets[t]["sim"] != "none")
print(f"\nSimulator-bound worker time: {sim_min / 60:.1f} h of {sum(map(worker_min, ids)) / 60:.1f} h")

owners = {}
for tid in ids:
    for p in tickets[tid]["owns"]:
        owners.setdefault(p.removeprefix("new:"), []).append(tid)
hot = sorted(((p, ts) for p, ts in owners.items() if len(ts) >= HOTSPOT_MIN_OWNERS),
             key=lambda pair: (-len(pair[1]), pair[0]))
print(f"\nHotspot files ({HOTSPOT_MIN_OWNERS} or more owners):")
for p, ts in hot:
    print(f"  {len(ts)}  {p}: {' '.join(ts)}")

big_phase = max(phase_min, key=phase_min.get)
print(f"\nHotspot: Phase {big_phase} takes {phase_min[big_phase] / 60:.1f} h of {total / 60:.1f} h",
      f"and the most shared file is {hot[0][0]} ({len(hot[0][1])} tickets)" if hot else "")
