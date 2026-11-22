#!/usr/bin/env python3
"""Tests for check_agent_rules.py, the guard on CLAUDE.md and the learnings index.

A guard nobody tests can quietly stop checking anything, which is the failure
it exists to prevent. Each case builds a small repository tree in a temporary
directory, runs the real script on it as a subprocess, and asserts on what CI
sees: the exit status and the `::error::` lines. The last case runs it on this
repository, so the committed files are held to the same rules.

Standard library only, like the other script tests here.

Run: python3 -m unittest discover -s scripts -p 'test_*.py'
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "check_agent_rules.py")
REPO = os.path.dirname(HERE)


class CheckAgentRulesTests(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="agent-rules-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.write("CLAUDE.md", "# Rules\n\n- One rule.\n")
        self.write("AGENTS.md", "See [CLAUDE.md](CLAUDE.md).\n")
        self.write("docs/learnings/a-trap.md", "# A trap\n")
        self.write("docs/learnings/INDEX.md", "# Learnings\n\n- [A trap](a-trap.md) — hook\n")

    # --- fixtures ---------------------------------------------------------

    def write(self, relative, text):
        path = os.path.join(self.root, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)

    def remove(self, relative):
        os.remove(os.path.join(self.root, relative))

    def run_check(self, root=None):
        return subprocess.run(
            [sys.executable, SCRIPT, root or self.root],
            capture_output=True,
            text=True,
            check=False,
        )

    def assertPasses(self):
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("::error", result.stdout)

    def assertFailsWith(self, *fragments):
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        for fragment in fragments:
            self.assertIn(fragment, result.stdout)

    # --- the baseline -----------------------------------------------------

    def test_a_well_formed_tree_passes(self):
        self.assertPasses()

    # --- CLAUDE.md --------------------------------------------------------

    def test_fifty_lines_pass(self):
        self.write("CLAUDE.md", "line\n" * 50)
        self.assertPasses()

    def test_fifty_one_lines_fail(self):
        self.write("CLAUDE.md", "line\n" * 51)
        self.assertFailsWith("CLAUDE.md has 51 lines; the cap is 50")

    def test_a_last_line_without_a_newline_still_counts(self):
        # `wc -l` would report 50 here.
        self.write("CLAUDE.md", "line\n" * 50 + "line")
        self.assertFailsWith("CLAUDE.md has 51 lines")

    def test_an_overlong_line_fails(self):
        self.write("CLAUDE.md", "# Rules\n" + "x" * 101 + "\n")
        self.assertFailsWith("CLAUDE.md line 2 is 101 characters; the cap is 100")

    def test_a_line_at_the_width_cap_passes(self):
        self.write("CLAUDE.md", "# Rules\n" + "x" * 100 + "\n")
        self.assertPasses()

    def test_a_missing_claude_md_fails(self):
        self.remove("CLAUDE.md")
        self.assertFailsWith("CLAUDE.md is missing")

    def test_a_blank_claude_md_fails(self):
        self.write("CLAUDE.md", "\n  \n")
        self.assertFailsWith("CLAUDE.md is empty")

    # --- AGENTS.md --------------------------------------------------------

    def test_a_missing_agents_md_fails(self):
        self.remove("AGENTS.md")
        self.assertFailsWith("AGENTS.md is missing")

    def test_an_agents_md_that_does_not_point_at_claude_md_fails(self):
        self.write("AGENTS.md", "Be helpful.\n")
        self.assertFailsWith("AGENTS.md does not point at CLAUDE.md")

    # --- the learnings index ---------------------------------------------

    def test_an_unindexed_learning_fails(self):
        self.write("docs/learnings/another-trap.md", "# Another\n")
        self.assertFailsWith(
            "docs/learnings/another-trap.md is not listed in docs/learnings/INDEX.md"
        )

    def test_an_unindexed_learning_in_a_subdirectory_fails(self):
        self.write("docs/learnings/ci/hidden.md", "# Hidden\n")
        self.assertFailsWith("docs/learnings/ci/hidden.md is not listed")

    def test_a_learning_in_a_subdirectory_passes_when_indexed(self):
        self.write("docs/learnings/ci/found.md", "# Found\n")
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md)\n- [Found](ci/found.md)\n",
        )
        self.assertPasses()

    def test_a_file_that_is_not_markdown_still_needs_an_entry(self):
        self.write("docs/learnings/notes.txt", "loose notes\n")
        self.assertFailsWith("docs/learnings/notes.txt is not listed")

    def test_an_entry_for_a_missing_file_fails(self):
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md)\n- [Renamed](renamed-away.md)\n",
        )
        self.assertFailsWith("links renamed-away.md, which does not exist")

    def test_an_entry_outside_the_directory_fails(self):
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md)\n- [Rules](../../CLAUDE.md)\n",
        )
        self.assertFailsWith("links ../../CLAUDE.md, which is not a learning")

    def test_an_absolute_link_fails(self):
        target = os.path.join(self.root, "CLAUDE.md")
        self.write(
            "docs/learnings/INDEX.md",
            f"- [A trap](a-trap.md)\n- [Rules]({target})\n",
        )
        self.assertFailsWith(f"links {target}, which is not a learning")

    def test_a_url_escaped_link_names_the_unescaped_file(self):
        self.write("docs/learnings/read guard.md", "# Read guard\n")
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md)\n- [Read guard](read%20guard.md)\n",
        )
        self.assertPasses()

    def test_a_bullet_with_no_learning_linked_fails(self):
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md)\n- A trap nobody wrote down\n",
        )
        self.assertFailsWith("line 2 is an entry with no learning linked")

    def test_a_bullet_linking_only_elsewhere_fails(self):
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md)\n- [#511](https://github.com/o/r/pull/511)\n",
        )
        self.assertFailsWith("line 2 is an entry with no learning linked")

    def test_external_links_and_anchors_are_not_entries(self):
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md), see [#511](https://github.com/o/r/pull/511)"
            " and [above](#learnings)\n",
        )
        self.assertPasses()

    def test_a_missing_index_fails(self):
        self.remove("docs/learnings/INDEX.md")
        self.assertFailsWith("docs/learnings/INDEX.md is missing")

    def test_an_empty_learnings_directory_fails(self):
        # Matching an empty index to an empty directory proves nothing.
        self.remove("docs/learnings/a-trap.md")
        self.write("docs/learnings/INDEX.md", "# Learnings\n")
        self.assertFailsWith("docs/learnings holds no learnings besides the index")

    def test_every_problem_is_reported_not_just_the_first(self):
        self.write("CLAUDE.md", "line\n" * 51)
        self.write("docs/learnings/another-trap.md", "# Another\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout.count("::error"), 2, result.stdout)

    # --- files nobody meant to add ----------------------------------------

    def git(self, *arguments):
        subprocess.run(
            ["git", "-C", self.root, *arguments],
            capture_output=True, check=True,
        )

    def make_checkout(self):
        self.git("init", "-q")
        self.git("add", "-A")

    def test_outside_a_checkout_dotfiles_are_not_learnings(self):
        self.write("docs/learnings/.DS_Store", "\0finder\0")
        self.write("docs/learnings/.cache/scratch.md", "# Scratch\n")
        self.assertPasses()

    def test_in_a_checkout_an_untracked_file_is_not_a_learning(self):
        self.make_checkout()
        self.write("docs/learnings/.DS_Store", "\0finder\0")
        self.write("docs/learnings/draft.md", "# Not added yet\n")
        self.assertPasses()

    def test_in_a_checkout_a_gitignored_file_is_not_a_learning(self):
        self.write(".gitignore", "*.swp\n")
        self.make_checkout()
        self.write("docs/learnings/a-trap.md.swp", "editor swap\n")
        self.assertPasses()

    def test_in_a_checkout_a_staged_unindexed_learning_fails(self):
        # The pre-commit hook runs before the commit exists: staged counts.
        self.make_checkout()
        self.write("docs/learnings/another-trap.md", "# Another\n")
        self.git("add", "docs/learnings/another-trap.md")
        self.assertFailsWith("docs/learnings/another-trap.md is not listed")

    def test_in_a_checkout_a_tracked_dotfile_still_needs_an_entry(self):
        self.write("docs/learnings/.DS_Store", "\0finder\0")
        self.make_checkout()
        # Forced, because a global excludes file commonly ignores .DS_Store,
        # and `add -A` would then leave this fixture untracked.
        self.git("add", "-f", "docs/learnings/.DS_Store")
        self.assertFailsWith("docs/learnings/.DS_Store is not listed")

    def test_in_a_checkout_linking_an_untracked_file_fails(self):
        self.make_checkout()
        self.write("docs/learnings/draft.md", "# Not added yet\n")
        self.write(
            "docs/learnings/INDEX.md",
            "- [A trap](a-trap.md)\n- [Draft](draft.md)\n",
        )
        self.assertFailsWith("links draft.md, which is untracked or hidden")

    def test_a_tree_nested_in_another_checkout_is_walked(self):
        # git would answer for the outer checkout, where none of this tree is
        # tracked, and every learning would read as absent.
        self.git("init", "-q")
        nested = os.path.join(self.root, "nested")
        shutil.copytree(self.root, nested, ignore=shutil.ignore_patterns(".git", "nested"))
        result = self.run_check(nested)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    # --- this repository --------------------------------------------------

    def test_this_repository_passes(self):
        result = self.run_check(REPO)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
