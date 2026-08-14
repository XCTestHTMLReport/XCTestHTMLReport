#!/usr/bin/env python3
"""Assembles manifest.json for one viewer-compare run.

The manifest is the point of the run. A directory of PNGs answers "what did the
two viewers look like"; only the manifest answers "on which Xcode, against which
commit, over which fixture" — which is the question anyone reading a comparison
six months later actually has, and the one nobody can reconstruct afterwards.

It also has to be enough to rebuild a comparison page from a run directory
alone, so every shot is inventoried with its side, view, viewport, appearance,
pixel dimensions and digest, not just its filename.

Toolchain probes are all best-effort: a probe that cannot run records `null`
rather than failing the run, because a manifest missing one version string is
worth more than no manifest at all.

Standard library only.
"""

import argparse
import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

PURPOSE = (
    "Like-for-like comparison of Xcode's own test-report viewer against the "
    "report this checkout renders, over the same .xcresult bundle."
)


def run(cmd, cwd=None):
    """Returns collapsed stdout, or None when the command is unavailable."""
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, check=True, cwd=cwd, timeout=120
        )
    except (OSError, subprocess.SubprocessError):
        return None
    return " ".join(proc.stdout.split()) or None


def read_json(path):
    if not os.path.exists(path):
        return None
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def png_size(path):
    """Reads width/height straight out of the IHDR chunk.

    Shelling out to `sips` once per shot costs more than the whole rest of this
    script, and the header is eight bytes at a fixed offset.
    """
    try:
        with open(path, "rb") as handle:
            head = handle.read(24)
    except OSError:
        return (None, None)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        return (None, None)
    return (
        int.from_bytes(head[16:20], "big"),
        int.from_bytes(head[20:24], "big"),
    )


def digest(path):
    sha = hashlib.sha256()
    try:
        with open(path, "rb") as handle:
            for chunk in iter(lambda: handle.read(1 << 20), b""):
                sha.update(chunk)
    except OSError:
        return None
    return sha.hexdigest()


def directory_bytes(path):
    total = 0
    for root, _dirs, files in os.walk(path):
        for name in files:
            try:
                total += os.lstat(os.path.join(root, name)).st_size
            except OSError:
                continue
    return total


def human_bytes(count):
    if count is None:
        return None
    value = float(count)
    for unit in ("B", "KB", "MB", "GB"):
        if value < 1024 or unit == "GB":
            return f"{value:.0f} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return None


def iso(timestamp):
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat().replace("+00:00", "Z")


def git_facts(repo):
    if not os.path.isdir(os.path.join(repo, ".git")) and not os.path.exists(
        os.path.join(repo, ".git")
    ):
        return {"sha": None}
    status = run(["git", "status", "--porcelain"], cwd=repo)
    return {
        "sha": run(["git", "rev-parse", "HEAD"], cwd=repo),
        "branch": run(["git", "rev-parse", "--abbrev-ref", "HEAD"], cwd=repo),
        "subject": run(["git", "log", "-1", "--pretty=%s"], cwd=repo),
        "committedAt": run(["git", "log", "-1", "--pretty=%cI"], cwd=repo),
        "workingTree": "clean" if not status else "dirty",
    }


def toolchain_facts():
    product = run(["sw_vers", "-productName"])
    version = run(["sw_vers", "-productVersion"])
    kernel = run(["uname", "-sr"])
    return {
        "xcode": run(["xcodebuild", "-version"]),
        "xcresulttool": run(["xcrun", "xcresulttool", "version"]),
        "swift": run(["swift", "--version"]),
        "node": run(["node", "--version"]),
        "os": f"{product} {version} ({kernel})" if product else kernel,
        "display": (
            "Screenshots on both sides are captured at 2x. `screencapture` "
            "follows the display's backing scale, so a non-Retina display "
            "produces 1x Xcode shots against 2x ours — check pixelWidth in the "
            "inventory before comparing weights across runs."
        ),
    }


def fixture_facts(bundle):
    if not bundle or not os.path.isdir(bundle):
        return {"bundle": bundle, "exists": False}

    facts = {
        "bundle": bundle,
        "exists": True,
        "generatedBy": "./prepareTestResults.sh (unless --fixture pointed elsewhere)",
        "sizeOnDisk": human_bytes(directory_bytes(bundle)),
    }

    info_plist = os.path.join(bundle, "Info.plist")
    stamp = info_plist if os.path.exists(info_plist) else bundle
    try:
        facts["generatedAt"] = iso(os.path.getmtime(stamp))
    except OSError:
        facts["generatedAt"] = None

    summary = run(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", bundle])
    if summary:
        try:
            parsed = json.loads(summary)
        except ValueError:
            parsed = {}
        facts["content"] = {
            key: parsed.get(key)
            for key in (
                "totalTestCount",
                "passedTests",
                "failedTests",
                "skippedTests",
                "expectedFailures",
                "startTime",
                "finishTime",
            )
            if key in parsed
        }
        devices = parsed.get("devicesAndConfigurations") or []
        facts["content"]["devices"] = [
            (entry.get("device") or {}).get("deviceName")
            for entry in devices
            if isinstance(entry, dict)
        ]

    return facts


def inventory(out_dir, ours, xcode):
    """Merges the two capture sides into one list, ordered for a comparison page.

    Side records come from the capture scripts, which know the intent (which
    view, which appearance, whether a human drove it). The pixel facts are read
    off the files here, so a shot that silently came out at the wrong size is
    visible in the manifest instead of only in the image.
    """
    records = []
    for side in (ours, xcode):
        for shot in (side or {}).get("shots", []):
            path = os.path.join(out_dir, shot["file"])
            width, height = png_size(path)
            record = dict(shot)
            record["exists"] = os.path.exists(path)
            record["pixelWidth"] = width
            record["pixelHeight"] = height
            record["bytes"] = os.path.getsize(path) if record["exists"] else None
            record["sha256"] = digest(path)
            records.append(record)

    order = {"summary": 0, "overview": 1, "tests": 2, "tests-all": 3, "logs": 4}
    records.sort(
        key=lambda r: (
            order.get(r.get("view"), 99),
            r.get("colorScheme") or "",
            r.get("width") or 0,
            r.get("side") or "",
        )
    )
    return records


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, help="run directory to write manifest.json into")
    parser.add_argument("--repo", default=".", help="repository checkout the render came from")
    parser.add_argument("--fixture", default=None, help="the .xcresult both sides were shown")
    parser.add_argument("--render-command", default=None, help="how the report was rendered")
    parser.add_argument("--result-reader", default=None, help="--result-reader the render used")
    parser.add_argument("--invocation", default=None, help="the command line that started the run")
    args = parser.parse_args(argv)

    out_dir = os.path.abspath(args.out)
    ours = read_json(os.path.join(out_dir, "ours-shots.json"))
    xcode = read_json(os.path.join(out_dir, "xcode-shots.json"))

    rendered = os.path.join(out_dir, "report", "index.html")
    manifest = {
        "purpose": PURPOSE,
        "capturedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "harness": {
            "tool": "scripts/viewer-compare",
            "invocation": args.invocation,
            "runDirectory": out_dir,
        },
        "toolchain": toolchain_facts(),
        "git": git_facts(os.path.abspath(args.repo)),
        "fixture": fixture_facts(args.fixture),
        "render": {
            "command": args.render_command,
            "resultReader": args.result_reader,
            "renderedHtml": "report/index.html",
            "renderedHtmlBytes": (
                os.path.getsize(rendered) if os.path.exists(rendered) else None
            ),
        },
        "capture": {"ours": ours, "xcode": xcode},
        "screenshots": inventory(out_dir, ours, xcode),
    }

    # The shot lists are already inventoried above with their pixel facts;
    # repeating them inside `capture` would double the file for no reader.
    for side in ("ours", "xcode"):
        if isinstance(manifest["capture"][side], dict):
            manifest["capture"][side].pop("shots", None)

    path = os.path.join(out_dir, "manifest.json")
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2)
        handle.write("\n")

    missing = [r["file"] for r in manifest["screenshots"] if not r["exists"]]
    print(f"manifest: {len(manifest['screenshots'])} shots -> {path}")
    if missing:
        print(f"manifest: {len(missing)} inventoried shot(s) missing on disk: {', '.join(missing)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
