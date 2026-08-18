#!/usr/bin/env python3
"""Tests for scripts/version-compare/render.py.

Two properties carry the stage: a failing tool must become a recorded failed
cell rather than a dead run, and the fixture bundle must never be exposed to
the tool — a shipped version mutates its input in some modes. The fake tools
here are Python scripts, so the suite runs on the Linux lint job.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "version-compare", "render.py"
)

WELL_BEHAVED = """#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
out = args[args.index("-o") + 1]
bundle = args[-1]
os.makedirs(out, exist_ok=True)
for name in ("index.html", "report.junit", "report.json"):
    open(os.path.join(out, name), "w").write("rendered")
# Misbehave like a real old version: scribble on the input bundle.
open(os.path.join(bundle, "MUTATED"), "w").write("gotcha")
"""

BROKEN = """#!/usr/bin/env python3
import sys
sys.stderr.write("cannot parse this bundle\\n")
sys.exit(3)
"""


class RenderTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(lambda: shutil.rmtree(self.dir, ignore_errors=True))
        self.fixture = os.path.join(self.dir, "TestResults.xcresult")
        os.makedirs(os.path.join(self.fixture, "Data"))
        with open(os.path.join(self.fixture, "Info.plist"), "w") as handle:
            handle.write("plist")

    def make_tool(self, label, source):
        path = os.path.join(self.dir, f"tool-{label}")
        with open(path, "w") as handle:
            handle.write(source)
        os.chmod(path, os.stat(path).st_mode | stat.S_IXUSR)
        return {"label": label, "binary": path, "source": "release",
                "zipSha256": None, "binarySha256": "irrelevant"}

    def run_render(self, tools):
        tools_path = os.path.join(self.dir, "acquire.json")
        with open(tools_path, "w") as handle:
            json.dump({"tools": tools}, handle)
        out = os.path.join(self.dir, "render")
        result = subprocess.run(
            [sys.executable, SCRIPT, "--tools", tools_path,
             "--fixtures", self.fixture, "--out", out, "--provenance", "skip"],
            capture_output=True, text=True, check=False,
        )
        return result, out

    def cells(self, out):
        with open(os.path.join(out, "cells.json"), encoding="utf-8") as handle:
            return json.load(handle)["cells"]

    def test_ok_cell_records_artifacts_and_leaves_fixture_untouched(self):
        result, out = self.run_render([self.make_tool("2.5.1", WELL_BEHAVED)])
        self.assertEqual(result.returncode, 0, result.stderr)
        (cell,) = self.cells(out)
        self.assertEqual(cell["status"], "ok")
        self.assertEqual(cell["artifacts"],
                         {"html": True, "junit": True, "json": True})
        self.assertTrue(
            os.path.isfile(os.path.join(out, cell["dir"], "index.html")))
        # The isolation property: the tool mutated ITS COPY, not the fixture.
        self.assertFalse(os.path.exists(os.path.join(self.fixture, "MUTATED")))

    def test_broken_tool_becomes_a_failed_cell_not_a_dead_run(self):
        result, out = self.run_render([
            self.make_tool("2.5.1", WELL_BEHAVED),
            self.make_tool("3.0.0", BROKEN),
        ])
        self.assertEqual(result.returncode, 0, result.stderr)
        by_tool = {c["tool"]: c for c in self.cells(out)}
        self.assertEqual(by_tool["2.5.1"]["status"], "ok")
        self.assertEqual(by_tool["3.0.0"]["status"], "failed")
        self.assertEqual(by_tool["3.0.0"]["exitCode"], 3)
        stderr_path = os.path.join(out, by_tool["3.0.0"]["dir"], "stderr.txt")
        with open(stderr_path, encoding="utf-8") as handle:
            self.assertIn("cannot parse this bundle", handle.read())


if __name__ == "__main__":
    unittest.main()
