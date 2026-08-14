#!/bin/bash
# Captures Xcode's own test-report viewer showing the same bundle this
# checkout just rendered, framed to the same logical window size.
#
# Driven by viewer_compare.sh; runnable on its own:
#
#   scripts/viewer-compare/capture_xcode.sh \
#       --bundle /path/to/TestResults.xcresult --out /path/to/run-dir
#
# WHAT IS AUTOMATED: opening the bundle, waiting for the report to load,
# pinning the window to an exact size, switching the system appearance, moving
# the Report navigator between Summary / Tests / Log, and the screenshots.
#
# WHAT IS NOT: the Tests view's status filter (--with-tests-all), which opens a
# pull-down whose item labels carry live counts, so matching them is a guess
# that changes with the fixture. That one is a numbered prompt. Any automated
# step that fails also degrades to a numbered prompt rather than aborting the
# run — a half-captured comparison is worth more than none, and the manifest
# records which shots were driven by hand.
#
# This drives a GUI. It takes over the keyboard focus for as long as it runs,
# and it changes the system appearance and puts it back. Do not use the machine
# while it works.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI="${HERE}/xcode_ui.applescript"
WINDOWS_JS="${HERE}/xcode_windows.js"

BUNDLE=""
OUT=""
WIDTH=1440
HEIGHT=900
ORIGIN_X=60
ORIGIN_Y=100
SETTLE=4
OPEN_TIMEOUT=240
MANUAL=0
WITH_TESTS_ALL=0

usage() {
    cat <<'EOF'
Usage: capture_xcode.sh --bundle <path.xcresult> --out <dir> [options]

  --bundle PATH      .xcresult to open in Xcode (required)
  --out DIR          directory to write PNGs and xcode-shots.json into (required)
  --width N          logical window width in points (default 1440)
  --height N         logical window height in points (default 900)
  --origin X,Y       where to pin the window (default 60,100)
  --settle SECONDS   pause after each view switch before the shutter (default 4)
  --open-timeout N   how long to wait for the report to load (default 240)
  --manual           drive every view switch by prompt instead of automatically
  --with-tests-all   add a guided shot of the Tests view with the All Tests filter
  -h, --help         this text
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
    --bundle)
        BUNDLE="$2"
        shift 2
        ;;
    --out)
        OUT="$2"
        shift 2
        ;;
    --width)
        WIDTH="$2"
        shift 2
        ;;
    --height)
        HEIGHT="$2"
        shift 2
        ;;
    --origin)
        ORIGIN_X="${2%%,*}"
        ORIGIN_Y="${2##*,}"
        shift 2
        ;;
    --settle)
        SETTLE="$2"
        shift 2
        ;;
    --open-timeout)
        OPEN_TIMEOUT="$2"
        shift 2
        ;;
    --manual)
        MANUAL=1
        shift
        ;;
    --with-tests-all)
        WITH_TESTS_ALL=1
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "capture_xcode.sh: unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
done

if [ -z "$BUNDLE" ] || [ -z "$OUT" ]; then
    echo "capture_xcode.sh: --bundle and --out are both required" >&2
    usage >&2
    exit 2
fi
if [ ! -d "$BUNDLE" ]; then
    echo "capture_xcode.sh: no such bundle: $BUNDLE" >&2
    exit 2
fi
mkdir -p "$OUT"

BUNDLE_NAME="$(basename "$BUNDLE")"
RECORDS="$(mktemp -t viewer-compare-xcode)"
NOTES="$(mktemp -t viewer-compare-notes)"
trap 'rm -f "$RECORDS" "$NOTES"' EXIT

note() {
    echo "$1" >>"$NOTES"
    echo "capture_xcode: $1"
}

ui() {
    osascript "$UI" "$@"
}

# --- preflight -------------------------------------------------------------

if [ "$(uname)" != "Darwin" ]; then
    echo "capture_xcode.sh: macOS only — this drives Xcode's GUI" >&2
    exit 1
fi
if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    echo "capture_xcode.sh: no Xcode selected (xcode-select -p failed)" >&2
    exit 1
fi

# One UI-element read before anything else, so a missing permission fails here
# with the fix rather than fifty lines later as a mystery. It has to be a UI
# read specifically: the appearance commands below go through System Events'
# scripting properties, which Automation alone can do, so probing with those
# would wave through a terminal that lacks Accessibility — and the run would
# then die in the wait loop, where a denied UI call is indistinguishable from a
# report that has not finished loading.
ax_probe="$(ui check-accessibility)"
case "$ax_probe" in
OK*) ;;
*)
    cat >&2 <<EOF
capture_xcode.sh: cannot read another app's UI through System Events
  ${ax_probe#ERR|}

Both grants below are for the program running this script — your terminal app,
not Xcode — in System Settings > Privacy & Security:

  Accessibility   "not allowed assistive access" (-25211) means this one
  Automation      "Not authorized to send Apple events" (-1743) means this one

Screen Recording, also for your terminal app, is needed later for screencapture.
EOF
    exit 1
    ;;
esac

appearance_before="$(ui get-appearance)"
case "$appearance_before" in
light | dark) ;;
*)
    echo "capture_xcode.sh: cannot read the system appearance: ${appearance_before#ERR|}" >&2
    exit 1
    ;;
esac
note "system appearance on entry: ${appearance_before}"

restore_appearance() {
    ui set-appearance "$appearance_before" >/dev/null 2>&1 || true
}
trap 'restore_appearance; rm -f "$RECORDS" "$NOTES"' EXIT

# --- numbered prompts ------------------------------------------------------

STEP=0
prompt_step() {
    local instruction="$1"
    STEP=$((STEP + 1))
    if [ ! -e /dev/tty ]; then
        note "step ${STEP} needed a prompt but there is no terminal to ask on: ${instruction}"
        return 1
    fi
    {
        echo
        echo "  ---- MANUAL STEP ${STEP} ----------------------------------------"
        echo "  ${instruction}"
        echo "  Press RETURN when the screen shows it, or type s + RETURN to skip."
        echo "  ------------------------------------------------------------"
    } >/dev/tty
    local reply=""
    read -r reply </dev/tty || true
    case "$reply" in
    s | S | skip) return 1 ;;
    esac
    return 0
}

# --- open the bundle and find its window -----------------------------------

echo "capture_xcode: opening ${BUNDLE_NAME} in Xcode"
open -a Xcode "$BUNDLE"

loaded=0
last_err=""
deadline=$((SECONDS + OPEN_TIMEOUT))
while [ "$SECONDS" -lt "$deadline" ]; do
    found="$(ui find "$BUNDLE_NAME")"
    case "$found" in
    ERR*) last_err="${found#ERR|}" ;;
    *)
        rows="${found##*|}"
        # The bundle row alone means the window exists but the report tree has
        # not been read yet; wait for at least one child before framing shots.
        case "$rows" in
        '' | *[!0-9]*) ;;
        *)
            if [ "$rows" -ge 2 ]; then
                loaded=1
                break
            fi
            ;;
        esac
        ;;
    esac
    sleep 2
done

if [ "$loaded" -ne 1 ]; then
    echo "capture_xcode.sh: Xcode never showed a loaded report for ${BUNDLE_NAME} within ${OPEN_TIMEOUT}s" >&2
    if [ -n "$last_err" ]; then
        echo "  (last window lookup: ${last_err})" >&2
    fi
    echo "  (a very large bundle can index for longer — retry with --open-timeout)" >&2
    exit 1
fi
note "report window found after $((OPEN_TIMEOUT - (deadline - SECONDS)))s"

# Xcode keeps loading the editor after the navigator is populated.
sleep "$SETTLE"

pinned="$(ui pin "$BUNDLE_NAME" "$ORIGIN_X" "$ORIGIN_Y" "$WIDTH" "$HEIGHT")"
case "$pinned" in
ERR*)
    echo "capture_xcode.sh: could not pin the report window: ${pinned#ERR|}" >&2
    exit 1
    ;;
esac
IFS='|' read -r got_x got_y got_w got_h <<<"$pinned"
if [ "$got_w" != "$WIDTH" ] || [ "$got_h" != "$HEIGHT" ]; then
    note "WARNING: asked for ${WIDTH}x${HEIGHT}, Xcode settled at ${got_w}x${got_h} — filenames still say ${WIDTH}, the manifest records the truth"
fi
note "window pinned at ${got_x},${got_y} ${got_w}x${got_h}"

# screencapture needs a CGWindowID, which the accessibility API does not expose;
# match the window by the bounds we just pinned it to.
WIN_ID="$(osascript -l JavaScript "$WINDOWS_JS" Xcode | python3 -c '
import json, sys
x, y, w, h = (int(v) for v in sys.argv[1:5])
for win in json.load(sys.stdin):
    if (win["x"], win["y"], win["width"], win["height"]) == (x, y, w, h):
        print(win["id"])
        break
' "$got_x" "$got_y" "$got_w" "$got_h")"

if [ -z "$WIN_ID" ]; then
    echo "capture_xcode.sh: could not match a CGWindowID to the pinned window" >&2
    exit 1
fi
note "CGWindowID ${WIN_ID}"

# --- capture ---------------------------------------------------------------

view_label() {
    case "$1" in
    summary) echo "the Summary view (the scheme row in the Report navigator)" ;;
    tests) echo "the Tests view (the 'Tests' row in the Report navigator)" ;;
    logs) echo "the Log view (the 'Log' row in the Report navigator)" ;;
    *) echo "the ${1} view" ;;
    esac
}

shoot() {
    local view="$1" scheme="$2" suffix="$3" how="$4"
    local file="xcode-${view}${suffix}-${WIDTH}-${scheme}.png"
    if ! screencapture -x -o -l "$WIN_ID" "${OUT}/${file}"; then
        note "screencapture failed for ${file}"
        return 1
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$file" "$view$suffix" "$WIDTH" "$scheme" "$how" >>"$RECORDS"
    echo "capture_xcode: ${file} (${how})"
}

for scheme in light dark; do
    ui set-appearance "$scheme" >/dev/null
    # Xcode redraws the whole report on an appearance change; the settle here is
    # what keeps a half-repainted window out of the shot.
    sleep $((SETTLE + 2))

    for view in summary tests logs; do
        how="automated"
        if [ "$MANUAL" -eq 0 ]; then
            result="$(ui select "$BUNDLE_NAME" "$view")"
        else
            result="ERR|--manual requested"
        fi
        case "$result" in
        OK*) ;;
        *)
            if [ "$MANUAL" -eq 0 ]; then
                note "automatic view switch to ${view} failed: ${result}"
            fi
            if ! prompt_step "Switch Xcode to $(view_label "$view"), in ${scheme} appearance."; then
                note "skipped xcode ${view} ${scheme}"
                continue
            fi
            how="manual"
            ;;
        esac
        sleep "$SETTLE"
        shoot "$view" "$scheme" "" "$how" || true
    done

    if [ "$WITH_TESTS_ALL" -eq 1 ]; then
        if [ "$MANUAL" -eq 0 ]; then
            ui select "$BUNDLE_NAME" tests >/dev/null || true
            sleep "$SETTLE"
        fi
        if prompt_step "In the Tests view, open the leftmost filter ('Failed Tests (N)') and choose 'All Tests (N)', in ${scheme} appearance."; then
            shoot "tests" "$scheme" "-all" "manual" || true
            # Xcode keeps the filter across an appearance switch, so leaving it
            # on All would make the NEXT appearance's plain `tests` shot show a
            # different view from this one's — two shots named as a light/dark
            # pair that are not comparable.
            if ! prompt_step "Set that filter back to 'Failed Tests (N)', so the remaining shots stay comparable."; then
                note "WARNING: Tests filter left on All Tests after ${scheme}; later tests shots may not match"
            fi
        else
            note "skipped xcode tests-all ${scheme}"
        fi
    fi
done

restore_appearance
note "system appearance restored to ${appearance_before}"

python3 - "$OUT" "$RECORDS" "$NOTES" "$BUNDLE" "$WIN_ID" "$got_x" "$got_y" "$got_w" "$got_h" <<'PY'
import json
import os
import subprocess
import sys

out, records, notes, bundle, win_id, x, y, w, h = sys.argv[1:10]


def lines(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as handle:
        return [line.rstrip("\n") for line in handle if line.strip()]


shots = []
for line in lines(records):
    file, view, width, scheme, how = line.split("\t")
    shots.append(
        {
            "file": file,
            "side": "xcode",
            "view": view,
            "width": int(width),
            "colorScheme": scheme,
            "automated": how == "automated",
        }
    )

xcode_version = "unknown"
try:
    xcode_version = " ".join(
        subprocess.run(
            ["xcodebuild", "-version"], capture_output=True, text=True, check=True
        ).stdout.split()
    )
except (OSError, subprocess.CalledProcessError):
    pass

payload = {
    "tool": "osascript (System Events + JXA/CoreGraphics) + screencapture",
    "xcode": xcode_version,
    "howOpened": f"open -a Xcode {os.path.basename(bundle)}; the window is identified by "
    "the first row of its Report navigator, because a window opened straight "
    "onto an .xcresult has no title",
    "window": f"pinned to {w}x{h} points at ({x},{y}); CGWindowID {win_id}",
    "screenshotCommand": f"screencapture -x -o -l {win_id} (window only, no shadow)",
    "appearance": "system appearance toggled via System Events; Xcode's report "
    "viewer has no appearance of its own",
    "viewSwitching": "Report-navigator selection moved with arrow keys on the "
    "focused outline — setting the AX selected attribute highlights the row "
    "without navigating, and a synthetic click does not land",
    "notes": lines(notes),
    "shots": shots,
}

with open(os.path.join(out, "xcode-shots.json"), "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2)
    handle.write("\n")

print(f"xcode: {len(shots)} shots -> {out}")
PY
