#!/usr/bin/env python3
"""Result helpers for scripts/test.sh.

usage: test_results.py summary <bundle.xcresult>
       test_results.py coverage <enumerated.json> <ran.json>
       test_results.py shard <enumerated.json> <timings.json> <shards>
       test_results.py timings <bundle.xcresult>
       test_results.py started <bundle.xcresult>

`coverage` fails unless a result bundle ran exactly the tests the build
enumerates. `shard` splits the UI test classes into balanced shards, one line
of classes per shard; `timings` prints each UI class's seconds from a full
serial or sharded run, the input `shard` balances by. `started` prints how
many real tests a bundle holds; 0 means the runner never started one.

enumerated.json comes from `xcodebuild test-without-building -enumerate-tests
-test-enumeration-format json`; ran.json from `xcrun xcresulttool get
test-results tests`. A parallel or sharded run must not drop, duplicate or
leave unfinished any test.
"""
import collections
import json
import os
import subprocess
import sys


UI_BUNDLE = "fitbodUITests"


def enumerated(path):
    found = set()

    def walk(node, parts):
        if node.get("kind") == "test":
            found.add("/".join(parts + [node["name"]]))
            return
        here = parts if node.get("kind") == "plan" else parts + [node["name"]]
        for child in node.get("children", []):
            walk(child, here)

    data = json.load(open(path))
    if data.get("errors"):
        sys.exit(f"enumeration errors: {data['errors']}")
    for value in data["values"]:
        walk(value, [])
    return found


def test_cases(nodes):
    """Every "Test Case" node of `xcresulttool get test-results tests` output."""
    for node in nodes:
        if node.get("nodeType") == "Test Case":
            yield node
        else:
            yield from test_cases(node.get("children", []) or [])


def bundle_tests(bundle):
    out = subprocess.check_output(
        ["xcrun", "xcresulttool", "get", "test-results", "tests", "--path", bundle])
    return json.loads(out)["testNodes"]


def ran_from(nodes):
    results = collections.defaultdict(list)
    for node in test_cases(nodes):
        url = node.get("nodeIdentifierURL", "")
        # test://com.apple.xcode/<project>/<bundle>/<class>/<test>
        key = "/".join(url.split("/")[4:]) if url else node.get("nodeIdentifier", "")
        # Results name XCTest methods without "()"; the enumeration adds it.
        if not key.endswith(")"):
            key += "()"
        results[key].append(node.get("result"))
    return results


def summary(bundle):
    if not os.path.isdir(bundle):
        print(f"   no result bundle at {bundle}; see the log next to it")
        return
    out = subprocess.check_output(
        ["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", bundle])
    d = json.loads(out)
    print(f"   {d.get('result')}: {d.get('totalTestCount')} tests, {d.get('passedTests')} passed, "
          f"{d.get('failedTests')} failed, {d.get('skippedTests')} skipped, "
          f"{d.get('expectedFailures')} expected failures")
    for failure in d.get("testFailures", []):
        text = failure.get("failureText", "").replace("\n", " ")[:200]
        print(f"   FAILED {failure.get('testIdentifierString')} - {text}")


def coverage(enumerated_path, ran_path):
    want = enumerated(enumerated_path)
    got = ran_from(json.load(open(ran_path))["testNodes"])
    missing = sorted(want - got.keys())
    extra = sorted(got.keys() - want)
    repeated = sorted(k for k, v in got.items() if len(v) > 1)
    unfinished = sorted(k for k, v in got.items()
                        if any(r not in ("Passed", "Failed", "Expected Failure", "Skipped") for r in v))
    for label, items in (("missing", missing), ("unexpected", extra),
                         ("ran more than once", repeated), ("without a result", unfinished)):
        for item in items[:50]:
            print(f"   {label}: {item}")
    print(f"   coverage: {len(want)} enumerated, {len(got)} ran, {len(missing)} missing, "
          f"{len(extra)} unexpected, {len(repeated)} repeated, {len(unfinished)} unfinished")
    sys.exit(1 if missing or extra or repeated or unfinished else 0)


def ui_classes(enumerated_path):
    return sorted({test.split("/")[1] for test in enumerated(enumerated_path)
                   if test.startswith(UI_BUNDLE + "/")})


def shard(enumerated_path, timings_path, count):
    """Longest-first greedy split. The same inputs always give the same shards,
    so a failure reproduces on the same shard with the same classes before it."""
    classes = ui_classes(enumerated_path)
    count = max(1, min(count, len(classes)))
    timings = json.load(open(timings_path))
    known = sorted(timings.values())
    fallback = known[len(known) // 2] if known else 60.0
    shards = [[0.0, i, []] for i in range(count)]
    for name in sorted(classes, key=lambda c: (-timings.get(c, fallback), c)):
        target = min(shards, key=lambda s: (s[0], s[1]))
        target[0] += timings.get(name, fallback)
        target[2].append(name)
    for load, index, names in shards:
        print(f"shard {index + 1}: {len(names)} classes, about {load / 60:.1f} min", file=sys.stderr)
        print(" ".join(sorted(names)))


def timings(bundle):
    seconds = collections.defaultdict(float)
    for node in test_cases(bundle_tests(bundle)):
        parts = node.get("nodeIdentifierURL", "").split("/")
        if len(parts) > 6 and parts[4] == UI_BUNDLE:
            seconds[parts[5]] += node.get("durationInSeconds") or 0.0
    print(json.dumps({k: round(v, 1) for k, v in sorted(seconds.items())}, indent=2))


def started(bundle):
    # A runner that never bootstraps reports one pseudo test case, named
    # "<app> (<pid>) encountered an error", with no identifier URL.
    print(sum(bool(n.get("nodeIdentifierURL")) for n in test_cases(bundle_tests(bundle))))


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "summary":
        summary(sys.argv[2])
    elif len(sys.argv) == 4 and sys.argv[1] == "coverage":
        coverage(sys.argv[2], sys.argv[3])
    elif len(sys.argv) == 5 and sys.argv[1] == "shard":
        shard(sys.argv[2], sys.argv[3], int(sys.argv[4]))
    elif len(sys.argv) == 3 and sys.argv[1] == "timings":
        timings(sys.argv[2])
    elif len(sys.argv) == 3 and sys.argv[1] == "started":
        started(sys.argv[2])
    else:
        sys.exit(__doc__)
