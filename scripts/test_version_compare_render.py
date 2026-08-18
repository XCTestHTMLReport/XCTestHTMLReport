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
import traceback

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

CAPTURE_SCHEMA_SUCCESS = """#!/usr/bin/env python3
import json, sys
out = sys.argv[sys.argv.index("-o") + 1]
with open(out, "w") as f:
    json.dump({"schema": "test"}, f)
"""

CAPTURE_SCHEMA_FAILURE = """#!/usr/bin/env python3
import sys
sys.stderr.write("schema capture failed\\n")
sys.exit(1)
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

    def run_render(self, tools, provenance="skip", env=None):
        tools_path = os.path.join(self.dir, "acquire.json")
        with open(tools_path, "w") as handle:
            json.dump({"tools": tools}, handle)
        out = os.path.join(self.dir, "render")
        cmd = [sys.executable, SCRIPT, "--tools", tools_path,
               "--fixtures", self.fixture, "--out", out, "--provenance", provenance]
        run_env = os.environ.copy() if env is None else env
        result = subprocess.run(
            cmd, capture_output=True, text=True, check=False, env=run_env,
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

    def test_nonexistent_binary_becomes_failed_cell_not_dead_run(self):
        """When a binary doesn't exist, the run must complete with that cell failed."""
        bad_tool = {"label": "nonexistent", "binary": "/nonexistent/binary/path",
                    "source": "release", "zipSha256": None, "binarySha256": "n/a"}
        result, out = self.run_render([
            self.make_tool("2.5.1", WELL_BEHAVED),
            bad_tool,
        ])
        # The run itself must succeed (exit 0) and cells.json must exist.
        self.assertEqual(result.returncode, 0, result.stderr)
        by_tool = {c["tool"]: c for c in self.cells(out)}
        # The good tool should still work.
        self.assertEqual(by_tool["2.5.1"]["status"], "ok")
        # The bad binary should produce a failed cell with exitCode -1.
        self.assertEqual(by_tool["nonexistent"]["status"], "failed")
        self.assertEqual(by_tool["nonexistent"]["exitCode"], -1)
        # The error (traceback with Error mention) should be in stderr.txt.
        stderr_path = os.path.join(out, by_tool["nonexistent"]["dir"], "stderr.txt")
        with open(stderr_path, encoding="utf-8") as handle:
            stderr_content = handle.read()
            # Should contain exception traceback
            self.assertIn("Error", stderr_content)

    def test_provenance_capture_succeeds(self):
        """When provenance capture succeeds, the result appears in cells.json."""
        capture_script = os.path.join(self.dir, "capture-schema-success")
        with open(capture_script, "w") as handle:
            handle.write(CAPTURE_SCHEMA_SUCCESS)
        os.chmod(capture_script, os.stat(capture_script).st_mode | stat.S_IXUSR)

        env = os.environ.copy()
        env["VC_CAPTURE_SCHEMA"] = capture_script
        result, out = self.run_render([self.make_tool("2.5.1", WELL_BEHAVED)],
                                      provenance="auto", env=env)
        self.assertEqual(result.returncode, 0, result.stderr)

        with open(os.path.join(out, "cells.json"), encoding="utf-8") as handle:
            data = json.load(handle)
        # The provenance map should have an entry for TestResults.
        self.assertIn("TestResults", data["provenance"])
        prov_rel = data["provenance"]["TestResults"]
        # The file should exist at that path.
        prov_path = os.path.join(out, prov_rel)
        self.assertTrue(os.path.isfile(prov_path))

    def test_provenance_capture_failure_is_recoverable(self):
        """When provenance capture fails, the run completes without that entry."""
        capture_script = os.path.join(self.dir, "capture-schema-failure")
        with open(capture_script, "w") as handle:
            handle.write(CAPTURE_SCHEMA_FAILURE)
        os.chmod(capture_script, os.stat(capture_script).st_mode | stat.S_IXUSR)

        env = os.environ.copy()
        env["VC_CAPTURE_SCHEMA"] = capture_script
        result, out = self.run_render([self.make_tool("2.5.1", WELL_BEHAVED)],
                                      provenance="auto", env=env)
        # The run should still exit 0 even though provenance capture failed.
        self.assertEqual(result.returncode, 0, result.stderr)
        # A warning should have been printed to stderr.
        self.assertIn("warning: provenance capture failed", result.stderr)

        with open(os.path.join(out, "cells.json"), encoding="utf-8") as handle:
            data = json.load(handle)
        # The provenance map should NOT have an entry for TestResults.
        self.assertNotIn("TestResults", data["provenance"])
        # The cell should still be ok (provenance is separate).
        (cell,) = data["cells"]
        self.assertEqual(cell["status"], "ok")

    def test_bundle_hash_is_deterministic_and_sensitive_to_content(self):
        """bundleHashes: stable across reruns of an unchanged fixture,
        changes when a file inside the fixture changes, and present even
        when --provenance is skip (it needs no toolchain)."""
        tool = self.make_tool("2.5.1", WELL_BEHAVED)

        result1, out1 = self.run_render([tool], provenance="skip")
        self.assertEqual(result1.returncode, 0, result1.stderr)
        with open(os.path.join(out1, "cells.json"), encoding="utf-8") as handle:
            data1 = json.load(handle)
        self.assertIn("bundleHashes", data1)
        hash1 = data1["bundleHashes"]["TestResults"]

        result2, out2 = self.run_render([tool], provenance="skip")
        self.assertEqual(result2.returncode, 0, result2.stderr)
        with open(os.path.join(out2, "cells.json"), encoding="utf-8") as handle:
            data2 = json.load(handle)
        # Same fixture content, rerun: identical hash.
        self.assertEqual(data2["bundleHashes"]["TestResults"], hash1)

        with open(os.path.join(self.fixture, "Info.plist"), "w") as handle:
            handle.write("plist-changed")

        result3, out3 = self.run_render([tool], provenance="skip")
        self.assertEqual(result3.returncode, 0, result3.stderr)
        with open(os.path.join(out3, "cells.json"), encoding="utf-8") as handle:
            data3 = json.load(handle)
        # Touching a file inside the fixture changes the hash.
        self.assertNotEqual(data3["bundleHashes"]["TestResults"], hash1)


if __name__ == "__main__":
    unittest.main()
