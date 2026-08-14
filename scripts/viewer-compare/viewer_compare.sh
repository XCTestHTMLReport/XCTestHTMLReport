#!/bin/bash
# One command that puts Xcode's test-report viewer and ours side by side over
# the same .xcresult, and leaves a run directory a comparison can be written
# from months later.
#
#   scripts/viewer-compare/viewer_compare.sh
#
# See README.md in this directory for when to run it and what it needs.
#
# Local-only by design: the Xcode half drives a GUI, which is exactly the kind
# of thing that flakes on a CI runner. Nothing here is wired into a workflow,
# and it should stay that way — the FUNCTIONAL half of new-Xcode coverage is
# .github/workflows/toolchain-drift.yml.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/../.." && pwd)"

# Captured before the parse loop below shifts it all away. The manifest records
# this, and "which flags was that run given" is most of what a reader wants from
# a run directory that does not match the one next to it.
INVOCATION="viewer_compare.sh $*"

FIXTURE="${REPO}/Tests/XCTestHTMLReportTests/Resources/TestResults.xcresult"
OUT=""
RESULT_READER=""
PORT=""
SKIP_OURS=0
SKIP_XCODE=0
XCODE_ARGS=()

usage() {
    cat <<'EOF'
Usage: viewer_compare.sh [options]

  --fixture PATH        .xcresult to show both viewers
                        (default Tests/XCTestHTMLReportTests/Resources/TestResults.xcresult)
  --out DIR             run directory (default .viewer-compare/<UTC timestamp>)
  --result-reader NAME  auto | legacy | modern, passed through to xchtmlreport
  --port N              port for the local report server (default: first free one)
  --skip-ours           do not capture this checkout's report
  --skip-xcode          do not capture Xcode's viewer
  --manual              drive every Xcode view switch by prompt
  --with-tests-all      add a guided shot of Xcode's Tests view, All Tests filter
  -h, --help            this text

Everything after `--` is passed to capture_xcode.sh unchanged.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
    --fixture)
        FIXTURE="$2"
        shift 2
        ;;
    --out)
        OUT="$2"
        shift 2
        ;;
    --result-reader)
        RESULT_READER="$2"
        shift 2
        ;;
    --port)
        PORT="$2"
        shift 2
        ;;
    --skip-ours)
        SKIP_OURS=1
        shift
        ;;
    --skip-xcode)
        SKIP_XCODE=1
        shift
        ;;
    --manual | --with-tests-all)
        XCODE_ARGS+=("$1")
        shift
        ;;
    --)
        shift
        while [ "$#" -gt 0 ]; do
            XCODE_ARGS+=("$1")
            shift
        done
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "viewer_compare.sh: unknown argument: $1" >&2
        usage >&2
        exit 2
        ;;
    esac
done

if [ "$(uname)" != "Darwin" ]; then
    echo "viewer_compare.sh: macOS only — the comparison needs Xcode's own viewer" >&2
    exit 1
fi

for tool in swift python3 node osascript; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "viewer_compare.sh: missing required tool: ${tool}" >&2
        exit 1
    fi
done

if [ ! -d "$FIXTURE" ]; then
    cat >&2 <<EOF
viewer_compare.sh: no fixture at ${FIXTURE}

Generate the repository fixtures first (boots a simulator, takes a few minutes):

    ./prepareTestResults.sh

or point at a bundle you already have with --fixture.
EOF
    exit 1
fi
FIXTURE="$(cd "$(dirname "$FIXTURE")" && pwd)/$(basename "$FIXTURE")"

if [ -z "$OUT" ]; then
    OUT="${REPO}/.viewer-compare/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"

echo "viewer-compare: run directory ${OUT}"

# --- build and render ------------------------------------------------------

echo "viewer-compare: building xchtmlreport (release)"
swift build -c release --package-path "$REPO"
BINARY="$(swift build -c release --package-path "$REPO" --show-bin-path)/xchtmlreport"

# Render from a copy INSIDE the report directory, for two reasons.
#
# `--rendering-mode linking` writes hrefs of the form `<bundle>/<attachment>`,
# relative to index.html, and the renderer exports every attachment into the
# bundle directory itself. Serve a report directory that does not contain the
# bundle and every screenshot, video and log in the report 404s — invisibly, in
# shots that otherwise look fine.
#
# And a copy rather than the fixture in the tree, because that export step
# writes into the bundle: pointing it at Tests/.../TestResults.xcresult would
# leave the checked-out fixture modified.
mkdir -p "${OUT}/report"
BUNDLE_COPY="${OUT}/report/$(basename "$FIXTURE")"
rm -rf "$BUNDLE_COPY"
ditto "$FIXTURE" "$BUNDLE_COPY"

RENDER_CMD=("$BINARY" --rendering-mode linking -o "${OUT}/report")
if [ -n "$RESULT_READER" ]; then
    RENDER_CMD+=(--result-reader "$RESULT_READER")
fi
RENDER_CMD+=("$BUNDLE_COPY")

echo "viewer-compare: rendering ${BUNDLE_COPY##*/}"
"${RENDER_CMD[@]}"

if [ ! -f "${OUT}/report/index.html" ]; then
    echo "viewer_compare.sh: render produced no ${OUT}/report/index.html" >&2
    exit 1
fi

# --- ours ------------------------------------------------------------------

SERVER_PID=""
stop_server() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
        SERVER_PID=""
    fi
}
trap stop_server EXIT

if [ "$SKIP_OURS" -eq 0 ]; then
    if [ ! -d "${REPO}/visual/node_modules" ]; then
        echo "viewer-compare: installing visual/ dependencies (npm ci)"
        (cd "${REPO}/visual" && npm ci)
    fi
    if ! (cd "${REPO}/visual" && node -e "require('playwright')" >/dev/null 2>&1); then
        echo "viewer_compare.sh: playwright is not usable in visual/node_modules" >&2
        exit 1
    fi
    # Chromium is downloaded once into the shared Playwright cache; this is a
    # no-op on a machine that has already run the visual suite.
    (cd "${REPO}/visual" && npx --no-install playwright install chromium >/dev/null)

    if [ -z "$PORT" ]; then
        PORT="$(python3 -c '
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
')"
    fi

    # A server rather than file:// — the report loads its attachments over HTTP,
    # and file:// would fail them silently in a way the shots would not show.
    python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "${OUT}/report" >"${OUT}/server.log" 2>&1 &
    SERVER_PID=$!

    ready=0
    for _ in $(seq 1 40); do
        if curl -fsS -o /dev/null "http://127.0.0.1:${PORT}/index.html" 2>/dev/null; then
            ready=1
            break
        fi
        sleep 0.25
    done
    if [ "$ready" -ne 1 ]; then
        echo "viewer_compare.sh: local server never answered on port ${PORT} (see ${OUT}/server.log)" >&2
        exit 1
    fi
    echo "viewer-compare: serving report on http://127.0.0.1:${PORT}/"

    VC_OUT="$OUT" VC_URL="http://127.0.0.1:${PORT}/index.html" \
        node "${HERE}/capture_ours.mjs"

    stop_server
fi

# --- xcode -----------------------------------------------------------------

if [ "$SKIP_XCODE" -eq 0 ]; then
    echo
    echo "viewer-compare: handing the screen to Xcode — do not use the machine until this finishes"
    echo
    "${HERE}/capture_xcode.sh" --bundle "$BUNDLE_COPY" --out "$OUT" ${XCODE_ARGS[@]+"${XCODE_ARGS[@]}"}
fi

# --- manifest --------------------------------------------------------------

python3 "${HERE}/make_manifest.py" \
    --out "$OUT" \
    --repo "$REPO" \
    --fixture "$FIXTURE" \
    --render-command "${RENDER_CMD[*]}" \
    --result-reader "${RESULT_READER:-auto (default)}" \
    --invocation "$INVOCATION"

echo
echo "viewer-compare: done"
echo "  ${OUT}"
