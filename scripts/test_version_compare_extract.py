#!/usr/bin/env python3
"""Tests for scripts/version-compare/extract.py.

The readers are tested against synthetic documents that follow the two
documented shapes: report.junit as 3.0.0's JUnitReport.swift renders it, and
report.json as docs/json-schema.md specifies. Task 8's end-to-end run checks
the same readers against real binaries' output; these tests pin the mapping
rules (status fold, id normalization, aggregation) precisely.

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
    os.path.dirname(os.path.abspath(__file__)), "version-compare", "extract.py"
)

JUNIT = """<?xml version='1.0' encoding='UTF-8'?>
<testsuites name='All' tests='4' failures='1' skipped='1'>
  <testsuite name='FirstSuite' tests='4' failures='1' skipped='1'>
  <testcase classname='FirstSuite' name='testPass()' time='0.05'/>
  <testcase classname='FirstSuite' name='testFail()' time='0.10'>
    <failure message='XCTAssertEqual failed: (&quot;0&quot;) is not equal to (&quot;1&quot;)'>
    </failure>
  </testcase>
  <testcase classname='FirstSuite' name='testSkip()' time='0.00'>
    <skipped/>
  </testcase>
  <testcase classname='FirstSuite' name='testRetry() (Iteration 1)' time='0.20'>
    <failure message='flaked'>
    </failure>
  </testcase>
  <testcase classname='FirstSuite' name='testRetry() (Iteration 2)' time='0.30'/>
  </testsuite>
</testsuites>
"""

REPORT_JSON = {
    "schemaVersion": "1.0.0",
    "runs": [{
        "destination": {"displayName": "iPhone 16 Pro",
                        "deviceIdentifier": "ABC", "modelName": "iPhone 16 Pro",
                        "operatingSystemVersion": "26.2"},
        "testables": [{
            "targetName": "SampleAppUITests",
            "groups": [{
                "kind": "group", "name": "FirstSuite",
                "identifier": "FirstSuite", "duration": 0,
                "children": [
                    {"kind": "testCase", "name": "testPass()",
                     "identifier": "FirstSuite/testPass()", "arguments": [],
                     "iterations": [{
                         "iterationNumber": None, "status": "passed",
                         "duration": 0.05,
                         "activities": [{
                             "title": "Start", "isFailure": False,
                             "start": None,
                             "attachments": [
                                 {"name": None, "filename": "aa.png",
                                  "filenameExtension": "png"},
                                 {"name": None, "filename": "bb.png",
                                  "filenameExtension": "png"},
                             ],
                             "subActivities": [{
                                 "title": "nested", "isFailure": False,
                                 "start": None,
                                 "attachments": [
                                     {"name": None, "filename": "cc.txt",
                                      "filenameExtension": "txt"}],
                                 "subActivities": [],
                             }],
                         }],
                     }]},
                    {"kind": "testCase", "name": "testRetry()",
                     "identifier": "FirstSuite/testRetry()", "arguments": [],
                     "iterations": [
                         {"iterationNumber": 1, "status": "failed",
                          "duration": 0.2,
                          "activities": [{"title": "x:1: flaked",
                                          "isFailure": True, "start": None,
                                          "attachments": [],
                                          "subActivities": []}]},
                         {"iterationNumber": 2, "status": "passed",
                          "duration": 0.3, "activities": []},
                     ]},
                ],
            }],
        }],
    }],
}


class ExtractTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(lambda: shutil.rmtree(self.dir, ignore_errors=True))
        self.render = os.path.join(self.dir, "render")
        self.out = os.path.join(self.dir, "extract")
        self.cells = []

    def add_cell(self, tool, fixture, status="ok", junit=None, report=None):
        rel = os.path.join(tool, fixture)
        cell_dir = os.path.join(self.render, rel)
        os.makedirs(cell_dir, exist_ok=True)
        artifacts = {"html": True, "junit": False, "json": False}
        if junit is not None:
            with open(os.path.join(cell_dir, "report.junit"), "w") as handle:
                handle.write(junit)
            artifacts["junit"] = True
        if report is not None:
            with open(os.path.join(cell_dir, "report.json"), "w") as handle:
                json.dump(report, handle)
            artifacts["json"] = True
        self.cells.append({"tool": tool, "fixture": fixture, "status": status,
                           "exitCode": 0 if status == "ok" else 3,
                           "wallSeconds": 1.0, "dir": rel,
                           "artifacts": artifacts})

    def run_extract(self):
        os.makedirs(self.render, exist_ok=True)
        with open(os.path.join(self.render, "cells.json"), "w") as handle:
            json.dump({"cells": self.cells, "provenance": {}}, handle)
        return subprocess.run(
            [sys.executable, SCRIPT, "--render", self.render,
             "--out", self.out],
            capture_output=True, text=True, check=False,
        )

    def cell_doc(self, tool, fixture):
        path = os.path.join(self.out, tool, f"{fixture}.json")
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)

    def index(self):
        with open(os.path.join(self.out, "index.json"),
                  encoding="utf-8") as handle:
            return json.load(handle)["cells"]

    def test_junit_cell_maps_statuses_and_merges_iterations(self):
        self.add_cell("2.5.1", "TestResults", junit=JUNIT)
        result = self.run_extract()
        self.assertEqual(result.returncode, 0, result.stderr)
        doc = self.cell_doc("2.5.1", "TestResults")
        by_id = {t["id"]: t for t in doc["tests"]}
        self.assertEqual(by_id["FirstSuite/testPass()"]["status"], "passed")
        self.assertEqual(by_id["FirstSuite/testFail()"]["status"], "failed")
        self.assertIn("is not equal to",
                      by_id["FirstSuite/testFail()"]["failureMessages"][0])
        self.assertEqual(by_id["FirstSuite/testSkip()"]["status"], "skipped")
        retry = by_id["FirstSuite/testRetry()"]  # two iterations, one row
        self.assertEqual(retry["status"], "mixed")
        self.assertAlmostEqual(retry["duration"], 0.5)
        self.assertIsNone(retry["attachmentCount"])
        self.assertEqual(doc["totals"]["mixed"], 1)
        self.assertEqual(doc["totals"]["passed"], 1)

    def test_schema_json_cell_counts_nested_attachments(self):
        self.add_cell("4.0.0rc1", "TestResults", report=REPORT_JSON)
        result = self.run_extract()
        self.assertEqual(result.returncode, 0, result.stderr)
        doc = self.cell_doc("4.0.0rc1", "TestResults")
        by_id = {t["id"]: t for t in doc["tests"]}
        self.assertEqual(by_id["FirstSuite/testPass()"]["attachmentCount"], 3)
        self.assertEqual(by_id["FirstSuite/testRetry()"]["status"], "mixed")
        self.assertIn("x:1: flaked",
                      by_id["FirstSuite/testRetry()"]["failureMessages"])
        (entry,) = [c for c in self.index() if c["tool"] == "4.0.0rc1"]
        self.assertEqual(entry["source"], "json")

    def test_legacy_raw_graph_json_is_not_mistaken_for_the_schema(self):
        # Old versions' report.json is the raw xcresulttool graph: a top-level
        # array, no schemaVersion. The junit next to it must win.
        self.add_cell("3.0.0", "TestResults",
                      junit=JUNIT, report=[{"_values": []}])
        result = self.run_extract()
        self.assertEqual(result.returncode, 0, result.stderr)
        (entry,) = [c for c in self.index() if c["tool"] == "3.0.0"]
        self.assertEqual(entry["source"], "junit")

    def test_failed_render_and_missing_artifacts_degrade_to_no_data(self):
        self.add_cell("2.5.1", "CrashResults", status="failed")
        self.add_cell("3.0.0", "CrashResults")  # ok but no junit, no json
        result = self.run_extract()
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = {c["tool"]: c for c in self.index()}
        self.assertFalse(entries["2.5.1"]["extracted"])
        self.assertEqual(entries["2.5.1"]["reason"], "render failed")
        self.assertFalse(entries["3.0.0"]["extracted"])


if __name__ == "__main__":
    unittest.main()
