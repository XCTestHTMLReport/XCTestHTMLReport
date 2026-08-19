#!/usr/bin/env python3
"""Tests for scripts/version-compare/assemble.py.

The site is static files over relative paths — that IS the contract: a run
directory must stay browsable after being zipped and moved (spec: the run
directory is the relocatable unit). So the assertions are about which files
exist, what data was embedded, and that no URL is absolute.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "version-compare", "assemble.py"
)


class AssembleTests(unittest.TestCase):
    def setUp(self):
        self.run_dir = tempfile.mkdtemp()
        self.addCleanup(lambda: shutil.rmtree(self.run_dir,
                                              ignore_errors=True))
        render = os.path.join(self.run_dir, "render")
        os.makedirs(os.path.join(render, "3.0.0", "TestResults"))
        os.makedirs(os.path.join(render, "2.5.1", "TestResults"))
        with open(os.path.join(render, "2.5.1", "TestResults",
                               "stderr.txt"), "w") as handle:
            handle.write("boom")
        with open(os.path.join(render, "cells.json"), "w") as handle:
            json.dump({"cells": [
                {"tool": "3.0.0", "fixture": "TestResults", "status": "ok",
                 "exitCode": 0, "wallSeconds": 1.0,
                 "dir": "3.0.0/TestResults",
                 "artifacts": {"html": True, "junit": True, "json": False}},
                {"tool": "2.5.1", "fixture": "TestResults",
                 "status": "failed", "exitCode": 3, "wallSeconds": 0.1,
                 "dir": "2.5.1/TestResults",
                 "artifacts": {"html": False, "junit": False, "json": False}},
            ], "provenance": {}}, handle)
        diff = os.path.join(self.run_dir, "diff")
        os.makedirs(diff)
        with open(os.path.join(diff, "TestResults.json"), "w") as handle:
            json.dump({"fixture": "TestResults", "tools": ["3.0.0"],
                       "noData": ["2.5.1"],
                       "rows": [{"id": "S/t()", "cells": {"3.0.0": {
                           "status": "passed", "duration": 1.0,
                           "attachmentCount": None, "rawNames": ["S/t()"],
                           "failureMessages": []}},
                           "flags": {}, "expected": False, "reason": None}],
                       }, handle)
        with open(os.path.join(diff, "summary.json"), "w") as handle:
            json.dump({"defaultBaseline": "3.0.0", "tools": ["2.5.1", "3.0.0"],
                       "fixtures": ["TestResults"], "unexplained": 0,
                       "expectedOnly": 0, "cellsFailed": 1,
                       "cellsNoData": 1}, handle)

    def run_assemble(self):
        return subprocess.run(
            [sys.executable, SCRIPT, "--run", self.run_dir],
            capture_output=True, text=True, check=False,
        )

    def read(self, *parts):
        with open(os.path.join(self.run_dir, "site", *parts),
                  encoding="utf-8") as handle:
            return handle.read()

    def test_writes_matrix_fixture_page_data_and_assets(self):
        result = self.run_assemble()
        self.assertEqual(result.returncode, 0, result.stderr)
        index = self.read("index.html")
        self.assertIn("fixture-TestResults.html", index)
        self.assertIn("../render/2.5.1/TestResults/stderr.txt", index)
        page = self.read("fixture-TestResults.html")
        self.assertIn("data-TestResults.js", page)
        self.assertIn("app.js", page)
        data = self.read("data-TestResults.js")
        self.assertTrue(data.startswith("window.VC_DATA = "))
        payload = json.loads(
            data[len("window.VC_DATA = "):].rstrip().rstrip(";"))
        self.assertEqual(payload["fixture"], "TestResults")
        self.assertEqual(payload["cells"][0]["tool"], "3.0.0")
        for asset in ("style.css", "app.js"):
            self.assertTrue(
                os.path.isfile(os.path.join(self.run_dir, "site", asset)))

    def test_every_url_is_relative(self):
        self.run_assemble()
        for name in ("index.html", "fixture-TestResults.html"):
            html = self.read(name)
            for target in re.findall(r'(?:href|src)="([^"]+)"', html):
                self.assertFalse(target.startswith(("/", "file:", "http")),
                                 f"absolute URL {target} in {name}")


if __name__ == "__main__":
    unittest.main()
