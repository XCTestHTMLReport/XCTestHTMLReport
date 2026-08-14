#!/usr/bin/env python3
"""Assemble the published Pages site and refuse to publish a damaged one.

The site is main's render at the root plus one immutable directory per released
version. `actions/deploy-pages` replaces the whole site on every deployment, so
a run that assembles an incomplete tree would silently delete published versions
and still finish green. Every check here exists to turn that into a failure.

Usage: assemble_site.py <site-dir>
"""

import html
import json
import os
import re
import shutil
import sys

# 1 GB is the documented Pages site limit. Failing at 800 MB turns the ceiling
# into a CI failure with headroom instead of a rejected deployment.
MAX_BYTES = 800 * 1024 * 1024

# pages-release.yml's tag glob only ever writes MAJOR.MINOR.PATCH, so anything
# else means the manifest was written by something other than this design.
# Rejecting it here is what keeps a hostile or hand-edited versions.json from
# reaching the filesystem or the generated hrefs, and what makes the listing's
# integer sort total rather than a crash.
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+")


def fail(message):
    print(f"::error::{message}", file=sys.stderr)
    sys.exit(1)


def directory_size(path):
    total = 0
    for root, _, files in os.walk(path):
        for name in files:
            total += os.path.getsize(os.path.join(root, name))
    return total


def render_listing(versions):
    """A minimal static index. Deliberately depends on nothing in the report
    templates, so template changes never churn it."""
    # versions.json stays in publication order — the manifest records what
    # happened. The page sorts by version instead, because a maintenance release
    # on an older line is published last and would otherwise sit at the top,
    # where a reader reads it as "the latest version".
    ordered = sorted(
        versions, key=lambda v: tuple(int(p) for p in v.split(".")), reverse=True
    )
    items = "\n".join(
        f'      <li><a href="./{html.escape(v)}/">{html.escape(v)}</a></li>'
        for v in ordered
    )
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>XCTestHTMLReport — published versions</title>
  <style>
    body {{ font-family: system-ui, -apple-system, sans-serif; margin: 3rem auto;
           max-width: 40rem; padding: 0 1rem; line-height: 1.6; }}
    li {{ margin: 0.25rem 0; }}
  </style>
</head>
<body>
  <h1>Published versions</h1>
  <p>Each link is the demo report as rendered by that release.
     <a href="../">The site root</a> is always the current <code>main</code>.</p>
  <ul>
{items}
  </ul>
</body>
</html>
"""


def main():
    if len(sys.argv) != 2:
        fail("usage: assemble_site.py <site-dir>")
    site = sys.argv[1]

    # actions/checkout leaves a full repository behind, and
    # upload-pages-artifact packages whatever it is handed — without this the
    # store's git history is published as browsable files.
    shutil.rmtree(os.path.join(site, ".git"), ignore_errors=True)

    manifest = os.path.join(site, "versions.json")
    if not os.path.isfile(manifest):
        fail(f"missing {manifest} — the pages-site store was not checked out")

    if not os.path.isfile(os.path.join(site, "index.html")):
        fail(f"missing {site}/index.html — main's render did not land")

    with open(manifest, encoding="utf-8") as handle:
        try:
            versions = json.load(handle)
        except json.JSONDecodeError as error:
            fail(f"{manifest} is not valid JSON: {error}")

    if not isinstance(versions, list) or any(not isinstance(v, str) for v in versions):
        fail(f"{manifest} must be a flat array of version strings")

    malformed = [v for v in versions if not VERSION.fullmatch(v)]
    if malformed:
        fail(
            f"{manifest} declares {len(malformed)} entr(ies) that are not "
            f"MAJOR.MINOR.PATCH: {', '.join(malformed)}"
        )

    # publish-version dedupes before it writes, so a repeat means the manifest
    # did not come from it. The listing would render the version twice.
    duplicates = sorted({v for v in versions if versions.count(v) > 1})
    if duplicates:
        fail(f"{manifest} lists {', '.join(duplicates)} more than once")

    # Truncation guard. Every declared version must exist on disk. A version
    # that vanished between the store and the artifact would otherwise deploy
    # as a green run that quietly dropped it.
    missing = [v for v in versions if not os.path.isfile(
        os.path.join(site, "v", v, "index.html"))]
    if missing:
        fail(
            f"versions.json declares {len(missing)} version(s) with no render: "
            f"{', '.join(missing)}"
        )

    # The reverse direction matters too: a directory nobody declared means the
    # manifest and the tree disagree, and the listing would omit a live page.
    version_dir = os.path.join(site, "v")
    on_disk = sorted(
        name for name in os.listdir(version_dir)
        if os.path.isdir(os.path.join(version_dir, name))
    ) if os.path.isdir(version_dir) else []
    undeclared = [name for name in on_disk if name not in versions]
    if undeclared:
        fail(
            f"{len(undeclared)} version director(ies) not in versions.json: "
            f"{', '.join(undeclared)}"
        )

    # Routed through fail() like every other failure here: a raw traceback in
    # the log would be the one place an operator gets no ::error:: annotation.
    listing = os.path.join(version_dir, "index.html")
    try:
        os.makedirs(version_dir, exist_ok=True)
        with open(listing, "w", encoding="utf-8") as handle:
            handle.write(render_listing(versions))
    except OSError as error:
        fail(f"could not write {listing}: {error}")

    size = directory_size(site)
    if size > MAX_BYTES:
        fail(
            f"assembled site is {size / 1024 / 1024:.0f} MB, over the "
            f"{MAX_BYTES / 1024 / 1024:.0f} MB ceiling"
        )

    print(f"assembled {site}: {len(versions)} version(s), {size / 1024 / 1024:.1f} MB")


if __name__ == "__main__":
    main()
