#!/usr/bin/env python3
"""Select the iOS simulator that fixture generation will use.

Single source of truth for "which simulator runtime do the fixtures target":
prepareTestResults.sh consumes the device fields, and the CI fixture cache key
(.github/workflows/test.yml and toolchain-drift.yml) consumes the runtime
fields. Deriving both from one selection keeps the cache key aligned with the
runtime the script actually boots (#436).

Picks the newest available iOS runtime that offers an iPhone, then the newest
iPhone model within it. Device names cannot be compared as strings: "iPhone 8"
sorts above "iPhone 17 Pro Max" because '8' > '1', and "iPhone SE" outranks
both. Compare the numeric model instead.

Prints one tab-separated line:

    DEVICE_NAME  OS_VERSION  UDID  RUNTIME_BUILD

Exits 1 with nothing on stdout when no iPhone simulator is available.
"""

import json
import re
import subprocess
import sys


def simctl_list(*args):
    result = subprocess.run(
        ["xcrun", "simctl", "list", *args, "--json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def runtime_version(identifier):
    match = re.search(r"iOS-([0-9-]+)$", identifier)
    if not match:
        return None
    return tuple(int(part) for part in match.group(1).split("-"))


def model_rank(entry):
    match = re.search(r"iPhone (\d+)", entry["name"])
    # Unnumbered models (iPhone SE, iPhone X) rank below numbered ones.
    return (1, int(match.group(1)), entry["name"]) if match else (0, 0, entry["name"])


def main():
    devices = simctl_list("devices", "available")["devices"]

    best = None
    for identifier, entries in devices.items():
        version = runtime_version(identifier)
        if version is None:
            continue
        iphones = [e for e in entries if e["name"].startswith("iPhone")]
        if not iphones:
            continue
        candidate = (version, identifier, max(iphones, key=model_rank))
        if best is None or candidate[0] > best[0]:
            best = candidate

    if best is None:
        print("No iPhone simulator available", file=sys.stderr)
        return 1

    version, identifier, entry = best

    # The devices listing keys runtimes by identifier only; the build version
    # that distinguishes two installs of the same iOS version lives in the
    # runtimes listing. Failing loudly beats a silently wrong cache key.
    builds = {
        runtime["identifier"]: runtime["buildversion"]
        for runtime in simctl_list("runtimes", "available")["runtimes"]
    }
    build = builds.get(identifier)
    if build is None:
        print(f"Runtime {identifier} missing from `simctl list runtimes`", file=sys.stderr)
        return 1

    # Tab-separated: device names contain spaces.
    print(
        "\t".join(
            [
                entry["name"],
                ".".join(str(part) for part in version),
                entry["udid"],
                build,
            ]
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
