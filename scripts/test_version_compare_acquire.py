#!/usr/bin/env python3
"""Tests for scripts/version-compare/acquire.py.

The cache is the part worth testing: a binary that silently stops matching its
recorded hash would render a column labeled "2.5.1" that is not 2.5.1, and
every conclusion drawn from the site would be wrong. Driven as a subprocess;
downloads are stubbed with --offline-zip so no network or gh is involved.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "version-compare", "acquire.py"
)


class AcquireTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(lambda: shutil.rmtree(self.dir, ignore_errors=True))
        self.cache = os.path.join(self.dir, "cache")
        self.out = os.path.join(self.dir, "acquire.json")

    def make_zip(self, tag, payload=b"#!/bin/sh\necho fake\n"):
        path = os.path.join(self.dir, f"xchtmlreport-{tag}.zip")
        with zipfile.ZipFile(path, "w") as zf:
            zf.writestr("xchtmlreport", payload)
        return path

    def run_script(self, *args):
        return subprocess.run(
            [sys.executable, SCRIPT, "--cache-dir", self.cache, "--out", self.out,
             *args],
            capture_output=True,
            text=True,
            check=False,
        )

    def manifest(self):
        with open(self.out, encoding="utf-8") as handle:
            return json.load(handle)

    def test_unpacks_zip_into_cache_and_writes_manifest(self):
        zip_path = self.make_zip("2.5.1")
        result = self.run_script(
            "--versions", "2.5.1", "--offline-zip", f"2.5.1={zip_path}"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        tools = self.manifest()["tools"]
        self.assertEqual(len(tools), 1)
        self.assertEqual(tools[0]["label"], "2.5.1")
        self.assertEqual(tools[0]["source"], "release")
        binary = tools[0]["binary"]
        self.assertTrue(os.path.isfile(binary))
        self.assertTrue(os.access(binary, os.X_OK), "binary must be executable")

    def test_cache_hit_skips_the_zip(self):
        zip_path = self.make_zip("2.5.1")
        self.run_script("--versions", "2.5.1", "--offline-zip", f"2.5.1={zip_path}")
        os.remove(zip_path)  # a second run must not need it
        result = self.run_script(
            "--versions", "2.5.1", "--offline-zip", f"2.5.1={zip_path}"
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_tampered_cached_binary_is_a_hard_failure(self):
        zip_path = self.make_zip("2.5.1")
        self.run_script("--versions", "2.5.1", "--offline-zip", f"2.5.1={zip_path}")
        binary = self.manifest()["tools"][0]["binary"]
        with open(binary, "ab") as handle:
            handle.write(b"tampered")
        result = self.run_script(
            "--versions", "2.5.1", "--offline-zip", f"2.5.1={zip_path}"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(binary, result.stderr)

    def test_zip_without_the_binary_fails_loudly(self):
        path = os.path.join(self.dir, "xchtmlreport-3.0.0.zip")
        with zipfile.ZipFile(path, "w") as zf:
            zf.writestr("README.md", "no binary here")
        result = self.run_script(
            "--versions", "3.0.0", "--offline-zip", f"3.0.0={path}"
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("xchtmlreport", result.stderr)


if __name__ == "__main__":
    unittest.main()
