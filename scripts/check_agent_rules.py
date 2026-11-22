#!/usr/bin/env python3
"""Keep the agent working rules small, and the learnings index whole.

`CLAUDE.md` is read in full at the start of every agent session, so it is only
useful while it stays short; nothing stops it growing one line at a time.
`docs/learnings/INDEX.md` is how anyone finds a learning, so a file it does not
list is invisible, and an entry whose file was renamed is a dead end. Both
failures are quiet, so this script makes them loud:

- `CLAUDE.md` exists, says something, and holds at most 50 lines of at most
  100 characters (the width cap keeps "50 lines" from meaning 50 paragraphs).
- `AGENTS.md` exists and points at `CLAUDE.md`.
- Every file under `docs/learnings/`, at any depth, is linked from the index,
  every local link in the index names a file that exists there, and every
  bullet in the index carries such a link. An empty directory fails too: an
  index over nothing proves nothing.

In a git checkout only tracked files count (staged ones included, so the
pre-commit hook sees a new learning), so a `.DS_Store` or an editor's scratch
file cannot fail the check. Outside one, every file except dotfiles counts.

Usage: check_agent_rules.py [repo-root]   (defaults to the repository root)
Exit 0 when everything holds, 1 with one `::error::` line per problem otherwise.
"""

import os
import re
import subprocess
import sys
from urllib.parse import unquote

MAX_LINES = 50
MAX_LINE_LENGTH = 100

CLAUDE = "CLAUDE.md"
AGENTS = "AGENTS.md"
LEARNINGS = os.path.join("docs", "learnings")
INDEX = "INDEX.md"

# Inline markdown links: [text](target). Titles and angle brackets are not used
# in the index, so the target is everything up to the closing parenthesis.
LINK = re.compile(r"\]\(([^)\s]+)\)")


def check_claude(root):
    path = os.path.join(root, CLAUDE)
    if not os.path.isfile(path):
        return [(CLAUDE, "is missing")]
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    if not text.strip():
        return [(CLAUDE, "is empty")]
    problems = []
    # splitlines() counts a final line with no trailing newline, which
    # `wc -l` does not; a 51st line cannot hide by dropping its newline.
    lines = text.splitlines()
    if len(lines) > MAX_LINES:
        problems.append((CLAUDE, f"has {len(lines)} lines; the cap is {MAX_LINES}"))
    for number, line in enumerate(lines, start=1):
        if len(line) > MAX_LINE_LENGTH:
            problems.append(
                (
                    CLAUDE,
                    f"line {number} is {len(line)} characters; the cap is {MAX_LINE_LENGTH}",
                )
            )
    return problems


def check_agents(root):
    path = os.path.join(root, AGENTS)
    if not os.path.isfile(path):
        return [(AGENTS, "is missing")]
    with open(path, encoding="utf-8") as handle:
        if CLAUDE not in handle.read():
            return [(AGENTS, f"does not point at {CLAUDE}")]
    return []


def tracked_files(root, directory):
    """The files git tracks under `directory`, relative to it, or None when
    `root` is not the top of a git checkout (or git is missing). The top-level
    test matters: a tree nested inside some other checkout would otherwise
    read as having no tracked files at all."""
    # A git hook runs with GIT_DIR set, and git then takes the current
    # directory as the top of the work tree, whatever it is: under the
    # pre-commit hook, `git -C <learnings dir> ls-files` listed the whole
    # repository as if it lived there. Dropping GIT_DIR and GIT_WORK_TREE lets
    # git find the checkout itself; GIT_INDEX_FILE stays, because under a
    # hook it is the index about to be committed.
    environment = {
        name: value
        for name, value in os.environ.items()
        if name not in ("GIT_DIR", "GIT_WORK_TREE")
    }
    try:
        top = subprocess.run(
            ["git", "-C", root, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True, env=environment,
        ).stdout.strip()
        if os.path.realpath(top) != os.path.realpath(root):
            return None
        prefix = os.path.relpath(directory, root).replace(os.sep, "/") + "/"
        listed = subprocess.run(
            ["git", "-C", root, "ls-files", "-z", "--cached", "--", prefix],
            capture_output=True, text=True, check=True, env=environment,
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return None
    return {path[len(prefix):] for path in listed.split("\0") if path.startswith(prefix)}


def walked_files(directory):
    """Every file under `directory` except dotfiles and anything in a dot
    directory, for a tree that is not a git checkout."""
    found = set()
    for current, directories, files in os.walk(directory):
        directories[:] = [name for name in directories if not name.startswith(".")]
        for name in files:
            if name.startswith("."):
                continue
            relative = os.path.relpath(os.path.join(current, name), directory)
            found.add(relative.replace(os.sep, "/"))
    return found


def learning_files(root, directory):
    """Every learning except the index, as paths relative to the learnings
    directory with forward slashes, which is how the index links them."""
    found = tracked_files(root, directory)
    if found is None:
        found = walked_files(directory)
    found = set(found)
    found.discard(INDEX)
    return found


def check_learnings(root):
    directory = os.path.join(root, LEARNINGS)
    index_name = f"{LEARNINGS}/{INDEX}"
    index_path = os.path.join(directory, INDEX)
    if not os.path.isfile(index_path):
        return [(index_name, "is missing")]

    with open(index_path, encoding="utf-8") as handle:
        index_lines = handle.read().splitlines()

    files = learning_files(root, directory)
    linked = set()
    problems = []
    for number, line in enumerate(index_lines, start=1):
        entries = 0
        for target in LINK.findall(line):
            if re.match(r"[a-z][a-z0-9+.-]*:", target) or target.startswith("#"):
                continue  # an external link or an anchor, not a learning
            # Markdown keeps URL escapes in a destination, so `a%20b.md` is
            # the file `a b.md`.
            path = unquote(target.split("#", 1)[0])
            normalised = os.path.normpath(path).replace(os.sep, "/")
            if os.path.isabs(path) or normalised.startswith("../") or normalised == INDEX:
                problems.append((index_name, f"links {target}, which is not a learning"))
                continue
            if not os.path.isfile(os.path.join(directory, normalised)):
                problems.append((index_name, f"links {target}, which does not exist"))
                continue
            if normalised not in files:
                # It exists here but not in git (or is a dotfile outside a
                # checkout), so a clean clone would not have it.
                problems.append((index_name, f"links {target}, which is untracked or hidden"))
                continue
            linked.add(normalised)
            entries += 1
        # A bullet is an entry, and an entry is a file: one with no link to a
        # learning would list something nobody can open.
        if re.match(r"\s*[-*+]\s", line) and entries == 0:
            problems.append((index_name, f"line {number} is an entry with no learning linked"))

    if not files:
        problems.append((LEARNINGS, "holds no learnings besides the index"))
    for missing in sorted(files - linked):
        problems.append((f"{LEARNINGS}/{missing}", f"is not listed in {index_name}"))
    return problems


def check(root):
    return check_claude(root) + check_agents(root) + check_learnings(root)


def main(argv):
    default = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    root = argv[1] if len(argv) > 1 else default
    problems = check(root)
    for path, message in problems:
        print(f"::error file={path}::{path} {message}")
    if problems:
        return 1
    print(f"{CLAUDE}, {AGENTS} and {LEARNINGS}/{INDEX} are in order.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
