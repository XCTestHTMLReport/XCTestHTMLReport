#!/usr/bin/env python3
"""Builds the static comparison site inside a run directory.

Everything is relative: panes and stderr links point into ../render, so the
RUN DIRECTORY is the relocatable unit — zip it, move it, it still opens. The
diff table works over file://; the synced panes need the run served (same-
origin iframes), which version_compare.sh --serve provides.
"""

import argparse
import html
import json
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "site-assets")

PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
{body}
</body>
</html>
"""

FIXTURE_BODY = """<header>
  <a href="index.html">&larr; matrix</a>
  <h1>{fixture}</h1>
  <label>baseline <select id="baseline"></select></label>
</header>
<main>
  <section id="table"></section>
  <section id="panes"></section>
</main>
<script src="data-{fixture}.js"></script>
<script src="app.js"></script>
"""


def badge(cell):
    if cell["status"] == "ok":
        return (f'<a class="badge ok" '
                f'href="fixture-{html.escape(cell["fixture"])}.html">ok</a>')
    stderr_rel = f'../render/{cell["dir"]}/stderr.txt'
    return (f'<a class="badge failed" href="{html.escape(stderr_rel)}">'
            f'failed ({cell["exitCode"]})</a>')


def build_index(cells, summary):
    tools = summary["tools"]
    fixtures = summary["fixtures"]
    by_key = {(c["tool"], c["fixture"]): c for c in cells}
    head = "".join(f"<th>{html.escape(t)}</th>" for t in tools)
    rows = []
    for fixture in fixtures:
        tds = []
        for tool in tools:
            cell = by_key.get((tool, fixture))
            tds.append(f"<td>{badge(cell) if cell else '&mdash;'}</td>")
        name = (f'<th><a href="fixture-{html.escape(fixture)}.html">'
                f'{html.escape(fixture)}</a></th>')
        rows.append(f"<tr>{name}{''.join(tds)}</tr>")
    counts = (f'{summary["unexplained"]} unexplained &middot; '
              f'{summary["expectedOnly"]} expected &middot; '
              f'{summary["cellsFailed"]} failed cells &middot; '
              f'{summary["cellsNoData"]} without data')
    body = (f"<header><h1>version-compare</h1><p>{counts}</p></header>"
            f"<main><table class='matrix'>"
            f"<thead><tr><th></th>{head}</tr></thead>"
            f"<tbody>{''.join(rows)}</tbody></table></main>")
    return PAGE.format(title="version-compare", body=body)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", required=True, help="run directory")
    args = parser.parse_args(argv)

    render_dir = os.path.join(args.run, "render")
    diff_dir = os.path.join(args.run, "diff")
    site_dir = os.path.join(args.run, "site")
    os.makedirs(site_dir, exist_ok=True)

    with open(os.path.join(render_dir, "cells.json"),
              encoding="utf-8") as handle:
        cells = json.load(handle)["cells"]
    with open(os.path.join(diff_dir, "summary.json"),
              encoding="utf-8") as handle:
        summary = json.load(handle)

    with open(os.path.join(site_dir, "index.html"), "w",
              encoding="utf-8") as handle:
        handle.write(build_index(cells, summary))

    for fixture in summary["fixtures"]:
        with open(os.path.join(diff_dir, f"{fixture}.json"),
                  encoding="utf-8") as handle:
            payload = json.load(handle)
        payload["cells"] = [c for c in cells if c["fixture"] == fixture]
        payload["defaultBaseline"] = summary["defaultBaseline"]
        with open(os.path.join(site_dir, f"data-{fixture}.js"), "w",
                  encoding="utf-8") as handle:
            handle.write("window.VC_DATA = ")
            json.dump(payload, handle, sort_keys=True)
            handle.write(";\n")
        with open(os.path.join(site_dir, f"fixture-{fixture}.html"), "w",
                  encoding="utf-8") as handle:
            handle.write(PAGE.format(
                title=f"version-compare: {fixture}",
                body=FIXTURE_BODY.format(fixture=html.escape(fixture))))

    for asset in ("style.css", "app.js"):
        shutil.copyfile(os.path.join(ASSETS, asset),
                        os.path.join(site_dir, asset))
    print(f"site -> {os.path.join(site_dir, 'index.html')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
