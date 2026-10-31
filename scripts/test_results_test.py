"""python3 scripts/test_results_test.py — checks the coverage guard and the shard split."""
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import test_results  # noqa: E402

ENUMERATED = {"errors": [], "values": [{"kind": "plan", "name": "fitbod", "children": [
    {"kind": "target", "name": "fitbodTests", "children": [
        {"kind": "class", "name": "SeedTests", "children": [
            {"kind": "test", "name": "importsCatalog()"},
            {"kind": "test", "name": "colors(in:)"}]}]},
    {"kind": "target", "name": "fitbodUITests", "children": [
        {"kind": "class", "name": "LoggerUITests", "children": [
            {"kind": "test", "name": "testLogsASet()"}]},
        {"kind": "class", "name": "TodayUITests", "children": [
            {"kind": "test", "name": "testOpens()"}]}]}]}]}


def case(test, result="Passed"):
    return {"nodeType": "Test Case", "result": result,
            "nodeIdentifierURL": f"test://com.apple.xcode/fitbod/{test}"}


def ran(*cases):
    return {"testNodes": [{"nodeType": "Test Plan", "children": [
        {"nodeType": "Unit test bundle", "children": list(cases)}]}]}


ALL = [case("fitbodTests/SeedTests/importsCatalog()"),
       case("fitbodTests/SeedTests/colors(in:)"),
       # XCTest results drop the "()" the enumeration has.
       case("fitbodUITests/LoggerUITests/testLogsASet"),
       case("fitbodUITests/TodayUITests/testOpens", "Failed")]


class CoverageTests(unittest.TestCase):
    def run_coverage(self, results):
        with tempfile.TemporaryDirectory() as tmp:
            enumerated, ran_path = os.path.join(tmp, "e.json"), os.path.join(tmp, "r.json")
            json.dump(ENUMERATED, open(enumerated, "w"))
            json.dump(results, open(ran_path, "w"))
            return subprocess.run([sys.executable, os.path.join(HERE, "test_results.py"),
                                   "coverage", enumerated, ran_path],
                                  capture_output=True, text=True)

    def test_every_test_once_passes_even_when_one_failed(self):
        self.assertEqual(self.run_coverage(ran(*ALL)).returncode, 0)

    def test_a_dropped_test_fails(self):
        out = self.run_coverage(ran(*ALL[:-1]))
        self.assertEqual(out.returncode, 1)
        self.assertIn("missing: fitbodUITests/TodayUITests/testOpens()", out.stdout)

    def test_a_test_run_twice_fails(self):
        out = self.run_coverage(ran(*ALL, ALL[0]))
        self.assertEqual(out.returncode, 1)
        self.assertIn("ran more than once", out.stdout)

    def test_a_runner_that_never_started_fails(self):
        pseudo = {"nodeType": "Test Case", "result": "Failed",
                  "nodeIdentifier": "fitbod (123) encountered an error"}
        out = self.run_coverage(ran(*ALL, pseudo))
        self.assertEqual(out.returncode, 1)
        self.assertIn("unexpected: fitbod (123) encountered an error()", out.stdout)

    def test_started_counts_only_real_tests(self):
        pseudo = {"nodeType": "Test Case", "nodeIdentifier": "fitbod (123) encountered an error"}
        nodes = ran(ALL[0], pseudo)["testNodes"]
        self.assertEqual(sum(bool(n.get("nodeIdentifierURL"))
                             for n in test_results.test_cases(nodes)), 1)


class ShardTests(unittest.TestCase):
    def test_longest_first_and_capped_at_the_class_count(self):
        with tempfile.TemporaryDirectory() as tmp:
            enumerated, timings = os.path.join(tmp, "e.json"), os.path.join(tmp, "t.json")
            json.dump(ENUMERATED, open(enumerated, "w"))
            json.dump({"LoggerUITests": 300, "TodayUITests": 100}, open(timings, "w"))
            out = subprocess.run([sys.executable, os.path.join(HERE, "test_results.py"),
                                  "shard", enumerated, timings, "5"],
                                 capture_output=True, text=True, check=True)
        self.assertEqual(out.stdout.splitlines(), ["LoggerUITests", "TodayUITests"])


if __name__ == "__main__":
    unittest.main()
