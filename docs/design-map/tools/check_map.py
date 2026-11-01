#!/usr/bin/env python3
"""Checks that the design map's files agree with each other.

  python3 -I docs/design-map/tools/check_map.py [--partial] [--mmd-out DIR]
  python3 -I docs/design-map/tools/check_map.py --self-test

The rules are listed in docs/design-map/conventions.md under "Checks".
Errors exit 1; warnings do not. --partial reports deliverables that are not
written yet (missing files, skeleton screen files, mock-ups not rendered)
as warnings, for use while the map is being written; the final check runs
without it. --mmd-out DIR writes every Mermaid block to DIR, where
tools/check.sh renders them. Only the standard library is used.
"""

from __future__ import annotations

import argparse
import collections
import functools
import pathlib
import re
import sys

MAP = pathlib.Path(__file__).resolve().parent.parent
ROOT = MAP.parent.parent
TICKETS = ROOT / "docs" / "conway-specs" / "tickets"

SCREEN_KEYS = ("id", "kind", "title", "view", "tab", "presents_from", "closes_with",
               "mock", "seed", "captured", "img", "tree")
DIALOG_KEYS = SCREEN_KEYS + ("message", "buttons")
WORKFLOW_KEYS = ("id", "job", "start", "end", "taps_min", "screens")
SCREEN_SECTIONS = ("Entry points", "Exits", "States", "Compared with the mock-up", "VoiceOver order", "Findings")
DIALOG_SECTIONS = ("Trigger", "Buttons", "Copy check", "Screenshot", "Findings")
WORKFLOW_SECTIONS = ("Steps", "Flow", "Tap count", "Dead ends", "Detours", "No clear way back", "Findings")
MISSING_HEADER = ["id", "Screen or state", "Workflow that needs it", "Must show", "Entered from",
                  "Importance", "Source"]
AUDIT_HEADER = ["ID", "Screen", "Problem", "Evidence", "Severity", "Ticket"]
KIND_SHAPE = {"screen": "rect", "sheet": "stadium", "cover": "stadium",
              "dialog": "hexagon", "alert": "hexagon", "system": "subroutine"}
TABS = {"today", "program", "progress", "library", "settings", "none"}
CLOSES = {"back", "cancel", "done", "close", "verb", "none"}
SEVERITY = ("blocker", "major", "minor", "polish")
IMPORTANCE = {"must", "should", "nice"}
MOCK_SIZES = ("390-light", "390-dark", "440-light", "440-dark")
EXEMPT = ("q_", "x_", "tab_")
DELIVERABLES = ("README.md", "assumptions.md", "conventions.md", "changelog.md", "navigation.md",
                "missing-screens.md", "audit.md", "workflows", "mockups")
SKELETON = "<!-- skeleton -->"
TEXT_SUFFIXES = {".md", ".html", ".css", ".py", ".sh", ".txt", ".tsv", ".json"}
EM_DASH = "\u2014"

STEM = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
CAPTURED = re.compile(r"\d{4}-\d{2}-\d{2} [0-9a-f]{7,40}")
FENCE = re.compile(r"^```.*?^```[ \t]*$", re.S | re.M)
BLOCK = re.compile(r"^```mermaid[ \t]*\n(.*?)^```[ \t]*$", re.S | re.M)
INLINE_CODE = re.compile(r"`[^`\n]*`")
HEADING = re.compile(r"^## (.+?)\s*$", re.M)
ARROW = re.compile(r"\s*(-->|-\.->)(?:\|[^|\n]*\|)?\s*")
NODE = re.compile(r'([A-Za-z][A-Za-z0-9_]*)\s*(\[\[".*"\]\]|\(\[".*"\]\)|\{\{".*"\}\}|\(\(".*"\)\)'
                  r'|\[".*"\]|\{".*"\}|\(".*"\))?(?::::[\w-]+)?')
KEYWORD = re.compile(r"%%|(?:flowchart|graph|subgraph|end|classDef|class|style|linkStyle|click|direction)\b")
SHAPES = (("[[", "subroutine"), ("([", "stadium"), ("{{", "hexagon"), ("((", "circle"),
          ("[", "rect"), ("{", "rhombus"), ("(", "round"))
LINK = re.compile(r"!?\[([^\]\n]*)\]\(([^)\s]+)\)")
HTML_IMG = re.compile(r"<img\b[^>]*?\bsrc=\"([^\"]+)\"")
SCHEME = re.compile(r"[a-z][a-z0-9+.-]*:")
CODE_REF = re.compile(r"`((?:fitbod|fitbodTests|fitbodUITests|FitbodWidgets|bru-screens|docs|scripts)/[\w./+-]*"
                      r"(?::\d+(?:-\d+)?)?)`")
REF = re.compile(r"([^:\s]+)(?::(\d+)(?:-(\d+))?)?")
TICKET = re.compile(r"\bT\d+\b")
AUDIT_ID = re.compile(r"\bD-(\d{2,3})\b")


class Report:
    def __init__(self, partial: bool) -> None:
        self.partial = partial
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def error(self, where: str, message: str) -> None:
        self.errors.append(f"{where}: {message}")

    def warn(self, where: str, message: str) -> None:
        self.warnings.append(f"{where}: {message}")

    def unwritten(self, where: str, message: str) -> None:
        """Something not written yet: an error unless --partial."""
        (self.warn if self.partial else self.error)(where, message)


# Parsers

def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]
    return value


def front_matter(text: str) -> tuple[dict[str, str | list[str]], str]:
    """Reads `key: value` and `key: [a, b]` lines between --- fences and
    returns them with the body. Raises ValueError on a malformed block."""
    if not text.startswith("---\n"):
        return {}, text
    end = text.find("\n---\n", 3)
    if end < 0:
        raise ValueError("the front matter has no closing ---")
    meta: dict[str, str | list[str]] = {}
    for line in text[4:end].splitlines():
        if not line.strip():
            continue
        key, colon, value = line.partition(":")
        if not colon:
            raise ValueError(f"a front matter line has no colon: {line!r}")
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            meta[key.strip()] = [unquote(item) for item in value[1:-1].split(",") if item.strip()]
        else:
            meta[key.strip()] = unquote(value)
    return meta, text[end + 5:]


def as_list(value: str | list[str] | None) -> list[str]:
    if isinstance(value, list):
        return value
    return [value] if value else []


def shape_of(token: str | None) -> str | None:
    for start, name in SHAPES:
        if token and token.startswith(start):
            return name
    return None


def parse_mermaid(block: str) -> tuple[dict[str, str | None], list[tuple[str, str, str]], list[str]]:
    """Reads node shapes and edges from a flowchart written in the map's
    style: one node or one chain of `-->` / `-.->` edges per line."""
    nodes: dict[str, str | None] = {}
    edges: list[tuple[str, str, str]] = []
    problems: list[str] = []
    for raw in block.splitlines():
        line = raw.strip()
        if not line or KEYWORD.match(line):
            continue
        parts = ARROW.split(line)
        ids = []
        for ref in parts[0::2]:
            match = NODE.fullmatch(ref.strip())
            if not match:
                problems.append(f"cannot read the Mermaid line {line!r}")
                break
            node, shape = match.group(1), shape_of(match.group(2))
            nodes[node] = shape or nodes.get(node)
            ids.append(node)
        else:
            edges += [(ids[i], arrow, ids[i + 1]) for i, arrow in enumerate(parts[1::2])]
    return nodes, edges, problems


def links(text: str) -> list[tuple[str, str]]:
    """(text, target) of every Markdown link and image, and every HTML
    <img src>, outside code."""
    prose = INLINE_CODE.sub("", FENCE.sub("", text))
    return LINK.findall(prose) + [("", src) for src in HTML_IMG.findall(prose)]


def split_row(line: str) -> list[str]:
    line = line.strip()
    if not line.startswith("|"):
        return []
    inner = line[1:-1] if line.endswith("|") and not line.endswith("\\|") else line[1:]
    return [cell.strip() for cell in re.split(r"(?<!\\)\|", inner)]


def table(text: str, first: str) -> tuple[list[str], list[list[str]]]:
    """The header and rows of the first table whose first header cell is `first`."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        header = split_row(line)
        if header and header[0] == first:
            rows = []
            for row in lines[index + 2:]:
                if not row.lstrip().startswith("|"):
                    break
                rows.append(split_row(row))
            return header, rows
    return [], []


def cell_ids(cell: str) -> list[str]:
    plain = LINK.sub(lambda match: match.group(1), cell).replace("`", "")
    return [part.strip() for part in plain.split(",") if part.strip()]


def rel(path: pathlib.Path) -> str:
    path = path.resolve()
    for base in (MAP, ROOT):
        if path.is_relative_to(base):
            return path.relative_to(base).as_posix()
    return str(path)


def in_unwritten_deliverable(path: pathlib.Path) -> bool:
    for name in DELIVERABLES:
        target = (MAP / name).resolve()
        if not target.exists() and (path == target or path.is_relative_to(target)):
            return True
    return False


@functools.cache
def line_count(path: pathlib.Path) -> int:
    return len(path.read_text(errors="replace").splitlines())


def check_ref(report: Report, where: str, ref: str) -> None:
    """A repo-root path with an optional :line or :first-last."""
    match = REF.fullmatch(ref)
    if not match:
        report.error(where, f"cannot read the path {ref!r}")
        return
    path = ROOT / match.group(1)
    if not path.exists():
        report.error(where, f"{match.group(1)} does not exist")
    elif match.group(2):
        first, last = int(match.group(2)), int(match.group(3) or match.group(2))
        count = line_count(path) if path.is_file() else 0
        if not 1 <= first <= last <= count:
            report.error(where, f"{ref} is outside the file's {count} lines")


# Checks

def check_screens(report: Report, referenced: set[pathlib.Path]) -> dict[str, dict]:
    screens: dict[str, dict] = {}
    for path in sorted((MAP / "screens").glob("*.md")):
        where = rel(path)
        try:
            meta, body = front_matter(path.read_text())
        except ValueError as error:
            report.error(where, str(error))
            continue
        kind = meta.get("kind")
        dialog = kind in ("dialog", "alert")
        if not STEM.fullmatch(path.stem):
            report.error(where, "the file name must be lowercase words joined by -")
        for key in DIALOG_KEYS if dialog else SCREEN_KEYS:
            if key not in meta:
                report.error(where, f"the front matter has no {key}")
        if meta.get("id") != path.stem:
            report.error(where, f"id {meta.get('id')!r} is not the file name")
        if kind not in KIND_SHAPE:
            report.error(where, f"kind {kind!r} is not one of {', '.join(KIND_SHAPE)}")
        for tab in as_list(meta.get("tab")):
            if tab not in TABS:
                report.error(where, f"tab {tab!r} is not one of {', '.join(sorted(TABS))}")
        if meta.get("view"):
            check_ref(report, where, str(meta["view"]))
        skeleton = SKELETON in body
        screens[path.stem] = {"meta": meta, "skeleton": skeleton, "path": path}
        if skeleton:
            continue
        if meta.get("closes_with") not in CLOSES:
            report.error(where, f"closes_with {meta.get('closes_with')!r} is not one of {', '.join(sorted(CLOSES))}")
        if meta.get("mock") and meta["mock"] != "none":
            check_ref(report, where, str(meta["mock"]))
        captured = str(meta.get("captured", ""))
        if captured == "none":
            if as_list(meta.get("img")):
                report.error(where, "captured is none, but img lists screenshots")
        elif not CAPTURED.fullmatch(captured):
            report.error(where, "captured must be a date and a commit, such as 2026-11-01 61353088, or none")
        images = as_list(meta.get("img")) + [t for t in as_list(meta.get("tree")) if t != "none"]
        for image in images:
            target = (path.parent / image).resolve()
            referenced.add(target)
            if not target.is_file():
                report.error(where, f"{image} does not exist")
        wanted = DIALOG_SECTIONS if dialog else SCREEN_SECTIONS
        if [h for h in HEADING.findall(body) if h in wanted] != list(wanted):
            report.error(where, f"the sections must be {', '.join(wanted)}, in this order")
    for stem, screen in screens.items():
        for source in as_list(screen["meta"].get("presents_from")):
            if source not in screens and not source.startswith("x-"):
                report.error(rel(screen["path"]), f"presents_from names {source}, which has no screens/ file")
    skeletons = [stem for stem, screen in screens.items() if screen["skeleton"]]
    if skeletons:
        shown = ", ".join(skeletons[:6]) + (", ..." if len(skeletons) > 6 else "")
        report.unwritten("screens", f"{len(skeletons)} files are skeletons, not written yet: {shown}")
    return screens


def check_node_ids(report: Report, where: str, ids: set[str], by_node: dict[str, str],
                   missing: dict[str, list[str]]) -> None:
    missing_nodes = {row.replace("-", "_") for row in missing}
    for node in sorted(ids):
        if node.startswith("m_"):
            if node[2:] not in missing_nodes:
                report.error(where, f"{node} names no missing-screens.md row")
        elif node not in by_node:
            report.error(where, f"node {node} has no screens/ file")


def check_navigation(report: Report, screens: dict[str, dict], missing: dict[str, list[str]]) -> tuple[int, int]:
    path = MAP / "navigation.md"
    if not path.exists():
        return 0, 0
    nodes: dict[str, str | None] = {}
    edges: list[tuple[str, str, str]] = []
    for block in BLOCK.findall(path.read_text()):
        found, block_edges, problems = parse_mermaid(block)
        for problem in problems:
            report.error("navigation.md", problem)
        for node, shape in found.items():
            nodes[node] = shape or nodes.get(node)
        edges += block_edges
    by_node = {stem.replace("-", "_"): stem for stem in screens}
    app_nodes = {node for node in nodes if not node.startswith(EXEMPT)}
    check_node_ids(report, "navigation.md", app_nodes, by_node, missing)
    for node in sorted(by_node.keys() - nodes.keys()):
        report.error(f"screens/{by_node[node]}.md", "is not in navigation.md")
    for node in sorted(app_nodes & by_node.keys()):
        kind = screens[by_node[node]]["meta"].get("kind")
        if nodes[node] != KIND_SHAPE.get(kind):
            report.error("navigation.md", f"{node} is drawn as {nodes[node] or 'no shape'}, "
                                          f"but a {kind} is drawn as {KIND_SHAPE.get(kind)}")
    expected = {(source.replace("-", "_"), node) for node, stem in by_node.items()
                for source in as_list(screens[stem]["meta"].get("presents_from"))}
    actual = {(a, b) for a, _, b in edges if b in by_node}
    for a, b in sorted(expected - actual):
        report.error(f"screens/{by_node[b]}.md", f"presents_from has {a.replace('_', '-')}, "
                                                 f"but navigation.md has no edge {a} to {b}")
    for a, b in sorted(actual - expected):
        report.error("navigation.md", f"the edge {a} to {b} is not in screens/{by_node[b]}.md presents_from")
    for a, arrow, b in edges:
        if b in by_node:
            kind = screens[by_node[b]]["meta"].get("kind")
            want = "-->" if kind == "screen" else "-.->"
            if arrow != want:
                report.warn("navigation.md", f"{a} {arrow} {b}: a {kind} is usually reached with {want}")
    return len(nodes), len(edges)


def check_workflows(report: Report, screens: dict[str, dict], missing: dict[str, list[str]]) -> int:
    folder = MAP / "workflows"
    by_node = {stem.replace("-", "_"): stem for stem in screens}
    paths = sorted(folder.glob("*.md")) if folder.exists() else []
    for path in paths:
        where = rel(path)
        try:
            meta, body = front_matter(path.read_text())
        except ValueError as error:
            report.error(where, str(error))
            continue
        for key in WORKFLOW_KEYS:
            if key not in meta:
                report.error(where, f"the front matter has no {key}")
        if meta.get("id") != path.stem:
            report.error(where, f"id {meta.get('id')!r} is not the file name")
        listed = as_list(meta.get("screens"))
        for screen in listed:
            if screen not in screens:
                report.error(where, f"screens lists {screen}, which has no screens/ file")
        for key in ("start", "end"):
            value = str(meta.get(key, ""))
            if value not in screens and not value.startswith("x-"):
                report.error(where, f"{key} {value!r} has no screens/ file")
        if not str(meta.get("taps_min", "")).isdigit():
            report.error(where, "taps_min must be a whole number")
        if [h for h in HEADING.findall(body) if h in WORKFLOW_SECTIONS] != list(WORKFLOW_SECTIONS):
            report.error(where, f"the sections must be {', '.join(WORKFLOW_SECTIONS)}, in this order")
        for block in BLOCK.findall(body):
            nodes, _, problems = parse_mermaid(block)
            for problem in problems:
                report.error(where, problem)
            ids = {node for node in nodes if not node.startswith(EXEMPT)}
            check_node_ids(report, where, ids, by_node, missing)
            for node in sorted(ids & by_node.keys()):
                if by_node[node] not in listed:
                    report.warn(where, f"the flow shows {by_node[node]}, which screens: does not list")
    return len(paths)


def check_missing(report: Report, screens: dict[str, dict], referenced: set[pathlib.Path]) -> dict[str, list[str]]:
    path = MAP / "missing-screens.md"
    rows: dict[str, list[str]] = {}
    if not path.exists():
        return rows
    header, body = table(path.read_text(), "id")
    if header != MISSING_HEADER:
        report.error("missing-screens.md", f"the table header must be: {' | '.join(MISSING_HEADER)}")
    for cells in body:
        if len(cells) != len(MISSING_HEADER):
            report.error("missing-screens.md", f"the row {cells[:1]} has {len(cells)} cells")
            continue
        row_id, importance = cells[0].strip("`"), cells[5].lower()
        if not STEM.fullmatch(row_id):
            report.error("missing-screens.md", f"id {row_id!r} must be lowercase words joined by -")
        if row_id in rows:
            report.error("missing-screens.md", f"{row_id} is listed twice")
        if row_id in screens:
            report.error("missing-screens.md", f"{row_id} already has a screens/ file")
        if importance not in IMPORTANCE:
            report.error("missing-screens.md", f"{row_id}: importance {importance!r} is not must, should or nice")
        rows[row_id] = cells
        if importance == "must":
            mockups = MAP / "mockups"
            for target in [mockups / f"{row_id}.html"] + [mockups / f"{row_id}-{size}.png" for size in MOCK_SIZES]:
                referenced.add(target.resolve())
                if not target.is_file():
                    report.unwritten("missing-screens.md", f"{row_id} is a must, but {rel(target)} is not there")
    if (MAP / "mockups").exists():
        for html in sorted((MAP / "mockups").glob("*.html")):
            if html.stem not in rows:
                report.error(rel(html), "names no missing-screens.md row")
    return rows


def check_audit(report: Report, screens: dict[str, dict], missing: dict[str, list[str]]) -> set[str]:
    path = MAP / "audit.md"
    ids: set[str] = set()
    if not path.exists():
        return ids
    header, body = table(path.read_text(), "ID")
    if header != AUDIT_HEADER:
        report.error("audit.md", f"the table header must be: {' | '.join(AUDIT_HEADER)}")
    keys: list[tuple[tuple[int, str], str]] = []
    for number, cells in enumerate(body, 1):
        want = f"D-{number:02d}"
        if len(cells) != len(AUDIT_HEADER):
            report.error("audit.md", f"row {number} has {len(cells)} cells")
            continue
        match = AUDIT_ID.search(cells[0])
        if not match or f"D-{match.group(1)}" != want:
            report.error("audit.md", f"row {number} must be {want}")
        if match:
            ids.add(f"d-{match.group(1)}")
        if f'<a id="{want.lower()}"></a>' not in cells[0]:
            report.error("audit.md", f'{want} needs the anchor <a id="{want.lower()}"></a> in its ID cell')
        severity = cells[4].lower()
        if severity not in SEVERITY:
            report.error("audit.md", f"{want}: severity {severity!r} is not one of {', '.join(SEVERITY)}")
        targets = cell_ids(cells[1])
        for target in targets:
            if target not in screens and target not in missing and target != "app":
                report.error("audit.md", f"{want}: screen {target!r} has no screens/ file or missing-screens.md row")
        rank = SEVERITY.index(severity) if severity in SEVERITY else len(SEVERITY)
        keys.append(((rank, targets[0] if targets else ""), want))
        for text, target in LINK.findall(cells[5]):
            dest = (path.parent / target).resolve()
            if TICKET.fullmatch(text) and (dest.parent != TICKETS.resolve() or not dest.name.startswith(text + "-")):
                report.error("audit.md", f"{want} links {text} to {target}, not to its ticket file")
        for bare in TICKET.findall(LINK.sub("", cells[5])):
            report.error("audit.md", f"{want} names {bare} without linking its ticket file")
    for (key, row), (next_key, _) in zip(keys, keys[1:]):
        if key > next_key:
            report.error("audit.md", f"the rows are not sorted by severity, then screen, after {row}")
            break
    return ids


def check_link(report: Report, where: str, path: pathlib.Path, target: str,
               audit_ids: set[str], referenced: set[pathlib.Path]) -> None:
    if SCHEME.match(target) or target.startswith("#"):
        return
    file_part, _, anchor = target.partition("#")
    dest = (path.parent / file_part.split("?")[0]).resolve()
    referenced.add(dest)
    if not dest.exists():
        if in_unwritten_deliverable(dest):
            report.unwritten(where, f"links {target}, which is not written yet")
        else:
            report.error(where, f"links {target}, which does not exist")
    elif dest == (MAP / "audit.md").resolve() and anchor and anchor not in audit_ids:
        report.error(where, f"links {target}, but audit.md has no row {anchor.upper()}")


def check_text_files(report: Report, audit_ids: set[str], referenced: set[pathlib.Path]) -> list[tuple[str, str]]:
    """The em dash, links and code paths in every text file; returns the
    Mermaid blocks as (name, block)."""
    blocks: list[tuple[str, str]] = []
    for path in sorted(MAP.rglob("*")):
        if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
            continue
        if path.is_relative_to(MAP / "screens" / "tree"):
            continue  # the app's own text, copied as the app shows it
        where = rel(path)
        text = path.read_text(errors="replace")
        for number, line in enumerate(text.splitlines(), 1):
            if EM_DASH in line:
                report.error(f"{where}:{number}", "uses the em dash; use - instead")
        if path.suffix != ".md":
            continue
        stem = where.removesuffix(".md").replace("/", "__")
        blocks += [(f"{stem}-{index}", block) for index, block in enumerate(BLOCK.findall(text), 1)]
        for _, target in links(text):
            check_link(report, where, path, target, audit_ids, referenced)
        for ref in CODE_REF.findall(FENCE.sub("", text)):
            check_ref(report, where, ref)
    return blocks


def check_unreferenced(report: Report, referenced: set[pathlib.Path]) -> tuple[int, int]:
    total = unused_total = 0
    for folder, pattern in (("screens/img", "*.png"), ("screens/tree", "*.txt"),
                            ("mockups", "*.png"), ("audit/evidence", "*.png")):
        files = sorted((MAP / folder).glob(pattern)) if (MAP / folder).exists() else []
        unused = [path for path in files if path.resolve() not in referenced]
        total += len(files)
        unused_total += len(unused)
        if unused:
            shown = ", ".join(path.name for path in unused[:5]) + (", ..." if len(unused) > 5 else "")
            report.warn(folder, f"{len(unused)} of {len(files)} files are not referenced: {shown}")
    return total, unused_total


def check(partial: bool, mmd_out: pathlib.Path | None) -> int:
    report = Report(partial)
    for name in DELIVERABLES:
        if not (MAP / name).exists():
            report.unwritten(name, "not written yet")
    referenced: set[pathlib.Path] = set()
    screens = check_screens(report, referenced)
    missing = check_missing(report, screens, referenced)
    audit_ids = check_audit(report, screens, missing)
    nodes, edges = check_navigation(report, screens, missing)
    workflows = check_workflows(report, screens, missing)
    blocks = check_text_files(report, audit_ids, referenced)
    files, unused = check_unreferenced(report, referenced)
    if mmd_out:
        mmd_out.mkdir(parents=True, exist_ok=True)
        for old in mmd_out.glob("*.mmd"):
            old.unlink()
        for name, block in blocks:
            (mmd_out / f"{name}.mmd").write_text(block)

    kinds = collections.Counter(str(screen["meta"].get("kind")) for screen in screens.values())
    skeletons = sum(screen["skeleton"] for screen in screens.values())
    musts = sum(1 for cells in missing.values() if cells[5].lower() == "must")
    print(f"screens     {len(screens)} files ({', '.join(f'{n} {k}' for k, n in sorted(kinds.items()))}),"
          f" {skeletons} skeletons")
    print(f"navigation  {nodes} nodes, {edges} edges")
    print(f"workflows   {workflows} files")
    print(f"missing     {len(missing)} rows, {musts} must")
    print(f"audit       {len(audit_ids)} rows")
    print(f"images      {files} files, {unused} unreferenced")
    print(f"mermaid     {len(blocks)} blocks{f' written to {mmd_out}' if mmd_out else ''}")
    for line in report.errors:
        print(f"ERROR {line}")
    for line in report.warnings:
        print(f"warning {line}")
    print(f"{len(report.errors)} errors, {len(report.warnings)} warnings")
    return 1 if report.errors else 0


def self_test() -> int:
    meta, body = front_matter('---\nid: today\nimg: [img/a.png, img/b.png]\ntitle: "Today: home"\n'
                              'presents_from: []\n---\nBody\n')
    assert meta == {"id": "today", "img": ["img/a.png", "img/b.png"], "title": "Today: home",
                    "presents_from": []}, meta
    assert body == "Body\n", body
    nodes, edges, problems = parse_mermaid(
        'flowchart LR\n  subgraph tab_today["Today"]\n  today["Today"] -->|Sessions| history["History"]\n'
        '  today -.-> settings(["Settings"])\n  end\n  %% a note\n  q_done{"Done?"} --> x_launch\n'
        '  settings -.-> dialog_reset{{"Reset?"}}\n  settings -.-> share_sheet[["Share sheet"]]\n')
    assert nodes == {"today": "rect", "history": "rect", "settings": "stadium", "q_done": "rhombus",
                     "x_launch": None, "dialog_reset": "hexagon", "share_sheet": "subroutine"}, nodes
    assert edges[:2] == [("today", "-->", "history"), ("today", "-.->", "settings")], edges
    assert not problems, problems
    assert parse_mermaid("a ---> b")[2], "a long arrow must not parse"
    assert parse_mermaid("endless --> b")[1] == [("endless", "-->", "b")]
    assert links("![x](img/a.png) `[y](no.md)` [T110](../t/T110-x.md)") == [("x", "img/a.png"),
                                                                            ("T110", "../t/T110-x.md")]
    assert links('<img src="img/a.png" width="300" alt="A"> `<img src="no.png">`') == [("", "img/a.png")]
    assert split_row("| D-01 | today | a \\| b | x | major | - |") == ["D-01", "today", "a \\| b", "x", "major", "-"]
    assert cell_ids("[today](screens/today.md), `history`") == ["today", "history"]
    assert CODE_REF.findall("see `fitbod/Views/TodayView.swift:38` and `fitbod/App/*Seed.swift`") == [
        "fitbod/Views/TodayView.swift:38"]
    assert REF.fullmatch("fitbod/Views/TodayView.swift:38-40").groups() == ("fitbod/Views/TodayView.swift", "38", "40")
    print("self-test passed")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--partial", action="store_true", help="report unwritten deliverables as warnings")
    parser.add_argument("--mmd-out", type=pathlib.Path, help="write every Mermaid block to this folder")
    parser.add_argument("--self-test", action="store_true", help="check the parsers and exit")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    return check(args.partial, args.mmd_out)


if __name__ == "__main__":
    sys.exit(main())
