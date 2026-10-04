#!/usr/bin/env python3
"""Turn .xcresult bundles into reviewable verification evidence.

For every bundle in --results this script:
  * reads the Xcode 16+ test summary (`xcresulttool get test-results summary`),
  * flattens the per-test results (`xcresulttool get test-results tests`),
  * exports XCTAttachment screenshots (`xcresulttool export attachments`),
    renames them to the attachment name the test chose, and downsizes them
    with `sips` so they stay small enough to commit,
and then writes `summary.md` + `summary.json` into --out.

Only macOS tooling is used (xcrun, sips); no third-party packages.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import shutil
import subprocess
import sys


def run_json(*args: str):
    try:
        out = subprocess.check_output(["xcrun", "xcresulttool", *args], text=True, stderr=subprocess.DEVNULL)
        return json.loads(out)
    except Exception as exc:  # noqa: BLE001 - evidence collection must never crash the job
        print(f"warning: xcresulttool {' '.join(args[:3])} failed: {exc}", file=sys.stderr)
        return None


CONTAINER_KINDS = ("Test Plan", "Unit test bundle", "UI test bundle", "Device", "Test Plan Configuration")
DETAIL_KINDS = ("Failure Message", "Source Code Reference", "Attachment", "Expression", "Runtime Warning",
                 "Repetition", "Arguments", "Test Value")


def flatten_tests(nodes, trail=()):
    for node in nodes or []:
        name = node.get("name", "?")
        kind = node.get("nodeType", "")
        children = [c for c in (node.get("children") or []) if c.get("nodeType", "") not in DETAIL_KINDS]
        if kind == "Test Case" or (not children and "result" in node and kind not in CONTAINER_KINDS):
            yield {
                "name": " › ".join([*trail, name]),
                "result": node.get("result", "unknown"),
                "duration": node.get("durationInSeconds") or node.get("duration"),
            }
        elif children:
            label = () if kind in CONTAINER_KINDS else (name,)
            yield from flatten_tests(children, (*trail, *label))


ATTACHMENT_SUFFIX = re.compile(r"_\d+_[0-9A-Fa-f-]{36}$")


def export_screenshots(bundle: pathlib.Path, dest: pathlib.Path) -> list[str]:
    raw = dest / "_raw"
    raw.mkdir(parents=True, exist_ok=True)
    try:
        subprocess.check_call(
            ["xcrun", "xcresulttool", "export", "attachments", "--path", str(bundle), "--output-path", str(raw)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"warning: attachment export failed for {bundle.name}: {exc}", file=sys.stderr)
        shutil.rmtree(raw, ignore_errors=True)
        return []

    manifest_path = raw / "manifest.json"
    names: list[str] = []
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        for test in manifest:
            for att in test.get("attachments", []):
                src = raw / att.get("exportedFileName", "")
                if not src.exists() or src.suffix.lower() not in (".png", ".jpg", ".jpeg", ".heic"):
                    continue
                human = pathlib.Path(att.get("suggestedHumanReadableName") or src.name).stem
                human = ATTACHMENT_SUFFIX.sub("", human)
                human = re.sub(r"[^A-Za-z0-9._-]+", "-", human).strip("-") or src.stem
                target = dest / f"{human}.png"
                n = 2
                while target.exists():
                    target = dest / f"{human}-{n}.png"
                    n += 1
                subprocess.call(
                    ["sips", "-s", "format", "png", "-Z", "1400", str(src), "--out", str(target)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                if target.exists():
                    names.append(target.name)
    shutil.rmtree(raw, ignore_errors=True)
    return sorted(names)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--small", default="")
    ap.add_argument("--large", default="")
    ap.add_argument("--runtime", default="")
    ap.add_argument("--xcode", default="")
    args = ap.parse_args()

    results = pathlib.Path(args.results)
    out = pathlib.Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    report = {
        "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "xcode": args.xcode.strip(),
        "runtime": args.runtime,
        "devices": {"small": args.small, "large": args.large},
        "bundles": [],
    }

    for bundle in sorted(results.glob("*.xcresult")):
        label = bundle.stem
        summary = run_json("get", "test-results", "summary", "--path", str(bundle)) or {}
        tests = run_json("get", "test-results", "tests", "--path", str(bundle)) or {}
        flat = list(flatten_tests(tests.get("testNodes", [])))
        shots = export_screenshots(bundle, out / label)
        report["bundles"].append(
            {
                "label": label,
                "result": summary.get("result", "unknown"),
                "total": summary.get("totalTestCount"),
                "passed": summary.get("passedTests"),
                "failed": summary.get("failedTests"),
                "skipped": summary.get("skippedTests"),
                "failures": [
                    {"test": f.get("testName"), "message": (f.get("failureText") or "").strip()}
                    for f in summary.get("testFailures", [])
                ],
                "tests": flat,
                "screenshots": shots,
            }
        )

    (out / "summary.json").write_text(json.dumps(report, indent=2))

    lines = [
        "# CI verification summary",
        "",
        f"- Generated: {report['generatedAt']}",
        f"- Xcode: {report['xcode'] or 'n/a'}",
        f"- Simulator runtime: {report['runtime'] or 'n/a'}",
        f"- Small device: {args.small or 'n/a'} · Large device: {args.large or 'n/a'}",
        "",
    ]
    for b in report["bundles"]:
        lines += [
            f"## {b['label']} — {b['result']}",
            "",
            f"Total {b['total']} · passed {b['passed']} · failed {b['failed']} · skipped {b['skipped']}",
            "",
        ]
        if b["failures"]:
            lines.append("### Failures")
            lines.append("")
            for f in b["failures"]:
                msg = f["message"].replace("\n", " ")[:400]
                lines.append(f"- `{f['test']}` — {msg}")
            lines.append("")
        if b["tests"]:
            lines.append("<details><summary>All test cases</summary>")
            lines.append("")
            for t in b["tests"]:
                mark = {"Passed": "✅", "Failed": "❌", "Skipped": "⏭️"}.get(t["result"], "•")
                lines.append(f"- {mark} {t['name']}")
            lines.append("")
            lines.append("</details>")
            lines.append("")
        if b["screenshots"]:
            lines.append(f"Screenshots ({len(b['screenshots'])}): " + ", ".join(b["screenshots"]))
            lines.append("")

    (out / "summary.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
