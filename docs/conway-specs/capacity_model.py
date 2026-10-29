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
RERUN_TICKETS = ["T44", "T45"]  # rerun after the findings are fixed (dispatch.md)
PHASE8_MIN = 20
PARALLEL_OK = {"T31"}  # takes no lane and runs beside the code workers, so it adds no serial time
CONDITIONAL = {"T43"}  # skipped when no newer design export exists
LANES = 3  # code workers at once, each ticket in its own worktree (dispatch.md)
LANE_OPTIONS = (1, 2, 3, 4)  # lane counts the estimate compares
SLOWDOWN = {1: 1.0, 2: 1.1, 3: 1.2, 4: 1.35}  # guess: workers share the Mac's cores, so each runs slower
MERGE_MIN = 8  # coordinator rebase, build and fast-forward when main moved; parallel runs only
EXCLUSIVE = {"T42", "T43", "T44", "T45", "T46", "T47", "T48"}  # run with no other code worker (dispatch.md)
REVIEW_ITEMS = [str(n) for n in range(1, 48)] + ["N1"]
HOTSPOT_MIN_OWNERS = 3

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
    if not re.fullmatch(r"T\d{2}", tid):
        errors.append(f"{path.name}: bad id {tid!r}")
        continue
    if tid in tickets:
        errors.append(f"{path.name}: duplicate id {tid}")
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
        if dep not in tickets:
            errors.append(f"{tid}: depends on {dep}, which does not exist")
        elif num(dep) >= num(tid):
            errors.append(f"{tid}: depends on {dep}, which is not earlier")
        elif tickets[dep]["phase"] > t["phase"]:
            errors.append(f"{tid}: depends on {dep}, which is in a later phase")

covered = {}
for tid in ids:
    for item in tickets[tid]["items"]:
        if item not in REVIEW_ITEMS:
            errors.append(f"{tid}: unknown review item {item}")
        covered.setdefault(item, []).append(tid)
uncovered = [i for i in REVIEW_ITEMS if i not in covered]
if uncovered:
    errors.append(f"review items with no ticket: {', '.join(uncovered)}")

created = {}  # repo path -> ticket that creates it
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
          for tid, file, title in re.findall(r"\| \[(T\d{2})\]\(tickets/([^)]+)\) \| ([^|]+)\|", index)}
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
                    ("GATE_AFTER", set(GATE_AFTER)), ("RERUN_TICKETS", set(RERUN_TICKETS))):
    for tid in sorted(group - set(tickets)):
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
        deps = list(t["depends_on"])
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
        add(f"{tid} rerun", work_min(worker_min(tid)), review, previous, alone=True)
        previous = [f"{tid} rerun"]
    members[findings_phase] += findings + previous
    gate_phases = {tickets[t]["phase"] for t in GATE_AFTER if t not in skip}
    if gates:
        for p in phases:
            gate = p in gate_phases
            add(f"end of phase {p}", 0, GATE_MIN if gate else 0, members[p], lane=False, alone=gate)
    else:
        jobs["T47"]["deps"] += previous
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
    gates = [f"gate {GATE_AFTER.index(t) + 1}" for t in row if t in GATE_AFTER]
    print(f"  Phase {phase}: {' '.join(row)}" + (f"  | {', '.join(gates)}" if gates else ""))
print("  Phase 8: coordinator only")

phase_min = {}
for tid in ids:
    if tid not in PARALLEL_OK:
        phase_min[tickets[tid]["phase"]] = phase_min.get(tickets[tid]["phase"], 0) + ticket_min(tid)
gates_min = len(GATE_AFTER) * GATE_MIN
findings_min = FINDINGS_TICKETS_GUESS * (SIZE_MINUTES["M"] * (1 + RETRY_RATE * RETRY_COST)
                                         + COORDINATOR_REVIEW_MIN)
reruns_min = sum(ticket_min(t) for t in RERUN_TICKETS)
total = sum(phase_min.values()) + gates_min + findings_min + reruns_min + PHASE8_MIN
skipped = sum(ticket_min(t) + (GATE_MIN if t in GATE_AFTER else 0) for t in CONDITIONAL)

print("\nSerial hours, including retries and coordinator checks:")
for phase, minutes in sorted(phase_min.items()):
    print(f"  Phase {phase}: {minutes / 60:5.1f} h")
print(f"  Gates:   {gates_min / 60:5.1f} h")
print(f"  Findings ({FINDINGS_TICKETS_GUESS} guessed M tickets): {findings_min / 60:.1f} h")
print(f"  Reruns of {' and '.join(RERUN_TICKETS)}: {reruns_min / 60:.1f} h")
print(f"  Phase 8: {PHASE8_MIN / 60:5.1f} h")
print(f"  Total:   {total / 60:5.1f} h, or {(total - skipped) / 60:.1f} h if "
      f"{', '.join(sorted(CONDITIONAL))} is skipped")

finish = {}
for tid in ids:  # deps always have lower ids, so id order is a topological order
    finish[tid] = max((finish[d] for d in tickets[tid]["depends_on"]), default=0) + ticket_min(tid)
chain = [max(finish, key=finish.get)]
while tickets[chain[-1]]["depends_on"]:
    chain.append(max(tickets[chain[-1]]["depends_on"], key=finish.get))
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
