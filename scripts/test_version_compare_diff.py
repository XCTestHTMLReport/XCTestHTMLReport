#!/usr/bin/env python3
"""Tests for scripts/version-compare/diff.py.

The flag rules are the product: a wrong "missing" is a phantom regression, a
missed "status" is a real one waved through. Baselines are precomputed for
every tool so the UI never re-implements these rules in JS — that property is
pinned here by asserting the same row flags both directions.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "version-compare", "diff.py"
)


def test_row(id_, status="passed", duration=1.0, attachments=None):
    return {"id": id_, "rawNames": [id_], "status": status,
            "duration": duration, "attachmentCount": attachments,
            "failureMessages": []}


class DiffTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(lambda: shutil.rmtree(self.dir, ignore_errors=True))
        self.extract = os.path.join(self.dir, "extract")
        self.out = os.path.join(self.dir, "diff")
        self.index = []

    def add_doc(self, tool, fixture, tests, extracted=True,
                reason=None):
        entry = {"tool": tool, "fixture": fixture, "extracted": extracted,
                 "source": "junit" if extracted else None,
                 "file": os.path.join(tool, f"{fixture}.json")
                 if extracted else None,
                 "reason": reason}
        self.index.append(entry)
        if extracted:
            dest = os.path.join(self.extract, tool, f"{fixture}.json")
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "w") as handle:
                json.dump({"tool": tool, "fixture": fixture,
                           "totals": {}, "tests": tests}, handle)

    def run_diff(self, *args):
        os.makedirs(self.extract, exist_ok=True)
        with open(os.path.join(self.extract, "index.json"), "w") as handle:
            json.dump({"cells": self.index}, handle)
        return subprocess.run(
            [sys.executable, SCRIPT, "--extract", self.extract,
             "--out", self.out, *args],
            capture_output=True, text=True, check=False,
        )

    def fixture_doc(self, stem):
        with open(os.path.join(self.out, f"{stem}.json"),
                  encoding="utf-8") as handle:
            return json.load(handle)

    def summary(self):
        with open(os.path.join(self.out, "summary.json"),
                  encoding="utf-8") as handle:
            return json.load(handle)

    def test_flags_status_missing_and_duration_disagreements(self):
        self.add_doc("3.0.0", "TestResults", [
            test_row("S/testA()"), test_row("S/testB()", status="failed"),
            test_row("S/testC()", duration=1.0),
        ])
        self.add_doc("4.0.0rc1", "TestResults", [
            test_row("S/testA()"), test_row("S/testB()", status="passed"),
            test_row("S/testC()", duration=1.5),
            test_row("S/testNew()"),
        ])
        result = self.run_diff()
        self.assertEqual(result.returncode, 0, result.stderr)
        doc = self.fixture_doc("TestResults")
        rows = {r["id"]: r for r in doc["rows"]}
        base = "3.0.0"
        # testA agrees everywhere: no flags entry for the baseline at all.
        self.assertEqual(rows["S/testA()"]["flags"].get(base, {}), {})
        self.assertEqual(rows["S/testB()"]["flags"][base]["4.0.0rc1"],
                         ["status"])
        self.assertEqual(rows["S/testC()"]["flags"][base]["4.0.0rc1"],
                         ["duration"])
        self.assertEqual(rows["S/testNew()"]["flags"][base]["4.0.0rc1"],
                         ["extra"])
        # The reverse baseline is precomputed too, with mirrored semantics.
        self.assertEqual(rows["S/testNew()"]["flags"]["4.0.0rc1"]["3.0.0"],
                         ["missing"])
        self.assertEqual(self.summary()["defaultBaseline"], "3.0.0")
        self.assertEqual(self.summary()["unexplained"], 3)

    def test_sub_tolerance_duration_difference_is_quiet(self):
        self.add_doc("3.0.0", "TestResults", [test_row("S/t()", duration=1.0)])
        self.add_doc("4.0.0rc1", "TestResults",
                     [test_row("S/t()", duration=1.05)])
        self.run_diff()
        self.assertEqual(self.summary()["unexplained"], 0)

    def test_expected_pattern_mutes_a_row(self):
        self.add_doc("3.0.0", "TestResults",
                     [test_row("S/tOld()", status="failed")])
        self.add_doc("4.0.0rc1", "TestResults",
                     [test_row("S/tOld()", status="passed")])
        expected = os.path.join(self.dir, "expected.json")
        with open(expected, "w") as handle:
            json.dump([{"pattern": r"TestResults/S/tOld\(\)",
                        "reason": "4.0 reclassifies this on purpose"}], handle)
        self.run_diff("--expected", expected)
        doc = self.fixture_doc("TestResults")
        (row,) = doc["rows"]
        self.assertTrue(row["expected"])
        self.assertEqual(row["reason"], "4.0 reclassifies this on purpose")
        self.assertEqual(self.summary()["unexplained"], 0)
        self.assertEqual(self.summary()["expectedOnly"], 1)

    def test_no_data_tool_generates_no_flags(self):
        self.add_doc("3.0.0", "TestResults", [test_row("S/t()")])
        self.add_doc("2.5.1", "TestResults", [], extracted=False,
                     reason="render failed")
        self.run_diff()
        doc = self.fixture_doc("TestResults")
        self.assertEqual(doc["noData"], ["2.5.1"])
        (row,) = doc["rows"]
        self.assertEqual(row["flags"], {})
        self.assertEqual(self.summary()["cellsNoData"], 1)

    def test_missing_extracted_file_degrades_gracefully(self):
        """If an extracted doc is missing, treat as no-data with warning."""
        self.add_doc("3.0.0", "TestResults", [test_row("S/t()")])
        # Add an entry claiming extraction but don't create the file
        self.index.append({"tool": "4.0.0rc1", "fixture": "TestResults",
                          "extracted": True, "source": "junit",
                          "file": "4.0.0rc1/TestResults.json", "reason": None})
        result = self.run_diff()
        # Should succeed despite missing file
        self.assertEqual(result.returncode, 0)
        # Should have a warning on stderr
        self.assertIn("4.0.0rc1/TestResults", result.stderr)
        self.assertIn("unreadable", result.stderr)
        # Missing file should be in noData
        doc = self.fixture_doc("TestResults")
        self.assertIn("4.0.0rc1", doc["noData"])
        # With only 3.0.0 extracted, it's the only tool
        self.assertEqual(doc["tools"], ["3.0.0"])


if __name__ == "__main__":
    unittest.main()
