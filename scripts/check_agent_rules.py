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

Usage: check_agent_rules.py [repo-root]   (defaults to the repository root)
Exit 0 when everything holds, 1 with one `::error::` line per problem otherwise.
"""

import os
import re
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


def learning_files(directory):
    """Every file under the learnings directory except the index, as paths
    relative to it with forward slashes, which is how the index links them."""
    found = set()
    for current, _, files in os.walk(directory):
        for name in files:
            relative = os.path.relpath(os.path.join(current, name), directory)
            found.add(relative.replace(os.sep, "/"))
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
            linked.add(normalised)
            entries += 1
        # A bullet is an entry, and an entry is a file: one with no link to a
        # learning would list something nobody can open.
        if re.match(r"\s*[-*+]\s", line) and entries == 0:
            problems.append((index_name, f"line {number} is an entry with no learning linked"))

    files = learning_files(directory)
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
