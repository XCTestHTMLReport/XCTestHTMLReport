#!/usr/bin/env python3
"""Tests for scripts/viewer-compare/make_manifest.py.

The manifest is the only part of a viewer-compare run that survives contact
with time: the PNGs show what the two viewers looked like, and the manifest is
what says which Xcode and which commit that was. A run that silently drops the
shot inventory, or that dies because one toolchain probe is missing, is worth
nothing — and neither failure is visible until someone tries to read the run
months later.

The tool it covers is macOS-only and drives a GUI, so it cannot be exercised on
CI. The manifest assembler is the piece that has no such excuse: it is plain
stdlib Python over a directory of files, and it runs here on any platform.

Driven as a subprocess, like test_assemble_site.py, so the assertions are about
what an operator actually gets: exit status, stdout, and the file on disk.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
import zlib

SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "viewer-compare", "make_manifest.py"
)


def write_png(path, width, height):
    """Writes a real, minimal PNG so the IHDR reader has something to read."""

    def chunk(kind, payload):
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw = b"".join(b"\x00" + b"\x00\x00\x00" * width for _ in range(height))
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n")
        handle.write(chunk(b"IHDR", ihdr))
        handle.write(chunk(b"IDAT", zlib.compress(raw)))
        handle.write(chunk(b"IEND", b""))


class MakeManifestTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.addCleanup(lambda: __import__("shutil").rmtree(self.dir, ignore_errors=True))

    def run_script(self, *args):
        return subprocess.run(
            [sys.executable, SCRIPT, "--out", self.dir, *args],
            capture_output=True,
            text=True,
            check=False,
        )

    def manifest(self):
        with open(os.path.join(self.dir, "manifest.json"), encoding="utf-8") as handle:
            return json.load(handle)

    def side(self, name, shots):
        with open(os.path.join(self.dir, f"{name}-shots.json"), "w", encoding="utf-8") as handle:
            json.dump({"tool": f"{name} tool", "shots": shots}, handle)

    def test_writes_a_manifest_with_nothing_captured(self):
        """An aborted run still has to explain itself.

        The commonest way to end up here is a permissions failure on the Xcode
        half, and the manifest is where the Xcode version that refused belongs.
        """
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)

        manifest = self.manifest()
        self.assertEqual(manifest["screenshots"], [])
        for key in ("purpose", "capturedAt", "toolchain", "git", "fixture", "render"):
            self.assertIn(key, manifest)

    def test_inventories_both_sides_with_pixel_facts(self):
        write_png(os.path.join(self.dir, "ours-summary-1440-light.png"), 2880, 946)
        write_png(os.path.join(self.dir, "xcode-summary-1440-light.png"), 2880, 1800)
        self.side(
            "ours",
            [
                {
                    "file": "ours-summary-1440-light.png",
                    "side": "ours",
                    "view": "summary",
                    "width": 1440,
                    "colorScheme": "light",
                    "automated": True,
                }
            ],
        )
        self.side(
            "xcode",
            [
                {
                    "file": "xcode-summary-1440-light.png",
                    "side": "xcode",
                    "view": "summary",
                    "width": 1440,
                    "colorScheme": "light",
                    "automated": False,
                }
            ],
        )

        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)

        shots = self.manifest()["screenshots"]
        self.assertEqual(len(shots), 2)
        by_side = {shot["side"]: shot for shot in shots}
        self.assertEqual(by_side["ours"]["pixelHeight"], 946)
        self.assertEqual(by_side["xcode"]["pixelHeight"], 1800)
        self.assertFalse(by_side["xcode"]["automated"])
        for shot in shots:
            self.assertTrue(shot["exists"])
            self.assertEqual(len(shot["sha256"]), 64)
            self.assertGreater(shot["bytes"], 0)

    def test_a_shot_that_never_landed_is_reported_not_hidden(self):
        """A promised shot missing from disk must be loud.

        `screencapture` can fail without failing the run — a denied Screen
        Recording permission is the usual reason — and a manifest that just
        omitted the entry would read as "we never asked for that view".
        """
        self.side(
            "xcode",
            [
                {
                    "file": "xcode-logs-1440-dark.png",
                    "side": "xcode",
                    "view": "logs",
                    "width": 1440,
                    "colorScheme": "dark",
                    "automated": True,
                }
            ],
        )

        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("missing on disk", result.stdout)

        shot = self.manifest()["screenshots"][0]
        self.assertFalse(shot["exists"])
        self.assertIsNone(shot["pixelWidth"])
        self.assertIsNone(shot["bytes"])

    def test_orders_shots_so_the_two_sides_pair_up(self):
        """Inventory order is the reading order of a comparison page: one view
        and appearance at a time, ours next to Xcode's."""
        shots = []
        for side in ("ours", "xcode"):
            for view in ("logs", "summary"):
                name = f"{side}-{view}-1440-light.png"
                write_png(os.path.join(self.dir, name), 100, 100)
                shots.append(
                    {
                        "file": name,
                        "side": side,
                        "view": view,
                        "width": 1440,
                        "colorScheme": "light",
                        "automated": True,
                    }
                )
        self.side("ours", [s for s in shots if s["side"] == "ours"])
        self.side("xcode", [s for s in shots if s["side"] == "xcode"])

        self.run_script()
        order = [(s["view"], s["side"]) for s in self.manifest()["screenshots"]]
        self.assertEqual(
            order,
            [
                ("summary", "ours"),
                ("summary", "xcode"),
                ("logs", "ours"),
                ("logs", "xcode"),
            ],
        )

    def test_a_missing_fixture_does_not_sink_the_run(self):
        """Runs against a bundle that has since been deleted or moved still
        produce a manifest; the absence is recorded rather than raised."""
        result = self.run_script("--fixture", os.path.join(self.dir, "gone.xcresult"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.manifest()["fixture"]["exists"])

    def test_records_the_render_it_was_told_about(self):
        result = self.run_script(
            "--render-command",
            "xchtmlreport --rendering-mode linking -o out bundle.xcresult",
            "--result-reader",
            "modern",
            "--invocation",
            "viewer_compare.sh --result-reader modern",
        )
        self.assertEqual(result.returncode, 0, result.stderr)

        manifest = self.manifest()
        self.assertEqual(manifest["render"]["resultReader"], "modern")
        self.assertIn("--rendering-mode linking", manifest["render"]["command"])
        self.assertIn("--result-reader modern", manifest["harness"]["invocation"])
        # No report/ in this temp directory, so the size is unknown rather than 0.
        self.assertIsNone(manifest["render"]["renderedHtmlBytes"])


if __name__ == "__main__":
    unittest.main()
