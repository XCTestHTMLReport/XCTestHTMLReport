#!/usr/bin/env python3
"""Tests for assemble_site.py, the script that stands between a damaged version
store and a deployment that silently deletes released reports.

Every guard here was verified by hand during implementation, in shell
transcripts that no longer exist. This file is the version of that verification
that survives, and that the next person to touch `render_listing` or the
undeclared-directory predicate runs without knowing it exists.

Standard library only, deliberately: the repository has no Python test
dependency and this needs none. The tests drive the real script as a
subprocess and assert on what CI and an operator actually see — exit status,
the `::error::` annotations, and the files left on disk.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assemble_site.py")


class AssembleSiteTests(unittest.TestCase):
    def setUp(self):
        self.site = tempfile.mkdtemp(prefix="assemble-site-")
        self.addCleanup(shutil.rmtree, self.site, ignore_errors=True)

    # --- fixtures ---------------------------------------------------------

    def build_store(self, declared, rendered=None, root_index=True, gitkeep=True):
        """Build the tree pages.yml hands the assembler: the pages-site store
        checked out into the site directory, plus main's render at the root.

        `rendered` defaults to `declared`; passing it is how a test makes the
        manifest and the tree disagree.
        """
        versions_dir = os.path.join(self.site, "v")
        os.makedirs(versions_dir, exist_ok=True)
        if gitkeep:
            # The real store ships this file — git cannot track an empty
            # directory — so every fixture carries it too.
            write(os.path.join(versions_dir, ".gitkeep"), "")
        for version in declared if rendered is None else rendered:
            os.makedirs(os.path.join(versions_dir, version), exist_ok=True)
            write(os.path.join(versions_dir, version, "index.html"), f"<!doctype html>{version}")
        if root_index:
            write(os.path.join(self.site, "index.html"), "<!doctype html>main")
        write(os.path.join(self.site, "versions.json"), json.dumps(declared) + "\n")

    def assemble(self):
        return subprocess.run(
            [sys.executable, SCRIPT, self.site],
            capture_output=True,
            text=True,
            check=False,
        )

    def listing(self):
        with open(os.path.join(self.site, "v", "index.html"), encoding="utf-8") as handle:
            return handle.read()

    def assertFailedCleanly(self, result):
        """Non-zero, with a GitHub annotation rather than a traceback — the
        contract every failure path in the script keeps."""
        self.assertEqual(result.returncode, 1, f"stdout={result.stdout!r}")
        self.assertIn("::error::", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    # --- the store is well-formed ----------------------------------------

    def test_happy_path_assembles_and_links_the_version(self):
        self.build_store(["3.1.0"])

        result = self.assemble()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("1 version(s)", result.stdout)
        self.assertIn('href="./3.1.0/"', self.listing())

    def test_empty_store_assembles_a_valid_empty_listing(self):
        """The state the site is in today, before the first release."""
        self.build_store([])

        result = self.assemble()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("0 version(s)", result.stdout)
        listing = self.listing()
        self.assertIn("<h1>Published versions</h1>", listing)
        self.assertIn("</html>", listing)
        self.assertNotIn("<li>", listing)

    def test_gitkeep_is_not_treated_as_a_version(self):
        """The most load-bearing case in this file: `v/.gitkeep` is in the real
        store, and a regression that reads it as an undeclared version fails
        every merge to main until the first release exists."""
        self.build_store([])
        self.assertTrue(os.path.isfile(os.path.join(self.site, "v", ".gitkeep")))

        result = self.assemble()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(".gitkeep", result.stderr)
        self.assertNotIn(".gitkeep", self.listing())

    def test_store_git_directory_is_removed(self):
        """actions/checkout leaves it behind and upload-pages-artifact would
        publish it."""
        self.build_store([])
        git_dir = os.path.join(self.site, ".git")
        os.makedirs(git_dir)
        write(os.path.join(git_dir, "config"), '[remote "origin"]\n')

        result = self.assemble()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(os.path.exists(git_dir))

    # --- the listing ------------------------------------------------------

    def test_listing_orders_by_version_not_by_publication(self):
        # publish-version prepends, so a maintenance release on an older line
        # is the newest entry in the manifest.
        self.build_store(["3.1.1", "4.0.0", "3.1.0"])

        result = self.assemble()

        self.assertEqual(result.returncode, 0, result.stderr)
        listing = self.listing()
        self.assertLess(listing.index("4.0.0"), listing.index("3.1.1"))
        self.assertLess(listing.index("3.1.1"), listing.index("3.1.0"))

    def test_listing_sorts_numerically_not_lexically(self):
        self.build_store(["9.0.0", "10.0.0"])

        result = self.assemble()

        self.assertEqual(result.returncode, 0, result.stderr)
        listing = self.listing()
        self.assertLess(listing.index("10.0.0"), listing.index("9.0.0"))

    def test_manifest_is_left_in_publication_order(self):
        """The manifest records what happened; only the page reorders."""
        self.build_store(["3.1.1", "4.0.0", "3.1.0"])

        self.assertEqual(self.assemble().returncode, 0)

        with open(os.path.join(self.site, "versions.json"), encoding="utf-8") as handle:
            self.assertEqual(json.load(handle), ["3.1.1", "4.0.0", "3.1.0"])

    # --- the store is damaged ---------------------------------------------

    def test_declared_version_with_no_render_fails(self):
        """The guard the whole design rests on: deploy-pages replaces the site,
        so assembling this tree would delete 3.0.0 in a green run."""
        self.build_store(["3.1.0", "3.0.0"], rendered=["3.1.0"])

        result = self.assemble()

        self.assertFailedCleanly(result)
        self.assertIn("3.0.0", result.stderr)
        self.assertNotIn("3.1.0", result.stderr)

    def test_undeclared_version_directory_fails(self):
        self.build_store([], rendered=["9.9.9"])

        result = self.assemble()

        self.assertFailedCleanly(result)
        self.assertIn("not in versions.json", result.stderr)
        self.assertIn("9.9.9", result.stderr)

    def test_missing_manifest_fails_with_its_own_message(self):
        self.build_store(["3.1.0"])
        os.remove(os.path.join(self.site, "versions.json"))

        result = self.assemble()

        self.assertFailedCleanly(result)
        self.assertIn("pages-site store was not checked out", result.stderr)

    def test_missing_root_render_fails_with_its_own_message(self):
        self.build_store(["3.1.0"], root_index=False)

        result = self.assemble()

        self.assertFailedCleanly(result)
        self.assertIn("main's render did not land", result.stderr)

    def test_duplicate_manifest_entries_fail(self):
        self.build_store(["3.1.0", "3.1.0"])

        result = self.assemble()

        self.assertFailedCleanly(result)
        self.assertIn("more than once", result.stderr)
        self.assertIn("3.1.0", result.stderr)

    def test_entries_that_are_not_version_numbers_are_rejected(self):
        for entry in ["../../etc", "3.1", "v3.1.0", "3.1.0 rc", "3.1.0#x"]:
            with self.subTest(entry=entry):
                # No directories: the format check must fire before the
                # truncation guard catches these only by accident.
                self.build_store([entry], rendered=[])

                result = self.assemble()

                self.assertFailedCleanly(result)
                self.assertIn("MAJOR.MINOR.PATCH", result.stderr)

    def test_unwritable_listing_path_fails_with_an_annotation(self):
        """`v` as a file used to escape as a raw FileExistsError traceback,
        the one failure with no annotation for the operator reading the log."""
        write(os.path.join(self.site, "index.html"), "<!doctype html>main")
        write(os.path.join(self.site, "versions.json"), "[]\n")
        write(os.path.join(self.site, "v"), "not a directory")

        result = self.assemble()

        self.assertFailedCleanly(result)


def write(path, text):
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


if __name__ == "__main__":
    unittest.main()
