#!/usr/bin/env python3
"""Puts the released xchtmlreport binaries this run compares on disk.

Release zips are fetched by tag into a content-verified cache; --head builds
the working tree. The output manifest is the render stage's tool list. A
cached binary that no longer matches its recorded hash fails the run — a
column labeled "2.5.1" that is not 2.5.1 poisons every conclusion.
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

DEFAULT_SLUG = "XCTestHTMLReport/XCTestHTMLReport"


def sha256_of(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def download_zip(tag, slug, dest_dir):
    asset = f"xchtmlreport-{tag}.zip"
    dest = os.path.join(dest_dir, asset)
    subprocess.run(
        ["gh", "release", "download", tag, "--repo", slug,
         "--pattern", asset, "--output", dest],
        check=True,
    )
    return dest


def install_from_zip(zip_path, bin_dir):
    """Extracts the executable member; returns (binary_path, zip_sha)."""
    zip_sha = sha256_of(zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        members = [m for m in zf.namelist()
                   if os.path.basename(m) == "xchtmlreport"]
        if not members:
            raise SystemExit(
                f"error: no xchtmlreport member inside {zip_path}"
            )
        os.makedirs(bin_dir, exist_ok=True)
        binary = os.path.join(bin_dir, "xchtmlreport")
        with zf.open(members[0]) as src, open(binary, "wb") as dst:
            shutil.copyfileobj(src, dst)
    # zipfile drops permission bits; the binary must be executable.
    os.chmod(binary, 0o755)
    return binary, zip_sha


def ensure_release(tag, cache_dir, slug, offline_zips):
    bin_dir = os.path.join(cache_dir, "bins", tag)
    binary = os.path.join(bin_dir, "xchtmlreport")
    meta_path = os.path.join(bin_dir, "meta.json")

    if os.path.isfile(binary) and os.path.isfile(meta_path):
        with open(meta_path, encoding="utf-8") as handle:
            meta = json.load(handle)
        actual = sha256_of(binary)
        if actual != meta["binarySha256"]:
            raise SystemExit(
                f"error: cached binary {binary} hashes {actual}, "
                f"expected {meta['binarySha256']} — remove it to re-fetch"
            )
        return binary, meta

    if tag in offline_zips:
        zip_path = offline_zips[tag]
        if not os.path.isfile(zip_path):
            raise SystemExit(f"error: --offline-zip {tag}={zip_path} not found")
        binary, zip_sha = install_from_zip(zip_path, bin_dir)
    else:
        with tempfile.TemporaryDirectory() as tmp:
            zip_path = download_zip(tag, slug, tmp)
            binary, zip_sha = install_from_zip(zip_path, bin_dir)

    meta = {
        "asset": f"xchtmlreport-{tag}.zip",
        "zipSha256": zip_sha,
        "binarySha256": sha256_of(binary),
    }
    with open(meta_path, "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=2, sort_keys=True)
        handle.write("\n")
    return binary, meta


def ensure_head(repo_dir):
    subprocess.run(
        ["swift", "build", "-c", "release", "--package-path", repo_dir],
        check=True,
    )
    binary = os.path.join(repo_dir, ".build", "release", "xchtmlreport")
    if not os.path.isfile(binary):
        raise SystemExit(f"error: swift build produced no {binary}")
    short = subprocess.run(
        ["git", "-C", repo_dir, "rev-parse", "--short", "HEAD"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    porcelain = subprocess.run(
        ["git", "-C", repo_dir, "status", "--porcelain"],
        capture_output=True, text=True, check=True,
    ).stdout.strip()
    label = f"head-{short}" + ("-dirty" if porcelain else "")
    return label, binary


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", required=True)
    parser.add_argument("--versions", default="",
                        help="comma-separated release tags")
    parser.add_argument("--head", default=None, metavar="REPO_DIR",
                        help="also build this checkout and include it")
    parser.add_argument("--repo-slug", default=DEFAULT_SLUG)
    parser.add_argument("--offline-zip", action="append", default=[],
                        metavar="TAG=ZIPPATH",
                        help="use a local zip for TAG instead of gh")
    parser.add_argument("--out", required=True,
                        help="write the tools manifest here")
    args = parser.parse_args(argv)

    offline_zips = {}
    for entry in args.offline_zip:
        tag, _, path = entry.partition("=")
        offline_zips[tag] = path

    tools = []
    for tag in [t for t in args.versions.split(",") if t]:
        binary, meta = ensure_release(
            tag, args.cache_dir, args.repo_slug, offline_zips
        )
        tools.append({
            "label": tag,
            "binary": os.path.abspath(binary),
            "source": "release",
            "zipSha256": meta["zipSha256"],
            "binarySha256": meta["binarySha256"],
        })

    if args.head:
        label, binary = ensure_head(args.head)
        tools.append({
            "label": label,
            "binary": os.path.abspath(binary),
            "source": "head",
            "zipSha256": None,
            "binarySha256": sha256_of(binary),
        })

    if not tools:
        raise SystemExit("error: nothing to acquire — pass --versions or --head")

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as handle:
        json.dump({"tools": tools}, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"acquired {len(tools)} tool(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
