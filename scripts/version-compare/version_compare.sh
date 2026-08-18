#!/bin/bash
# One command that renders the same fixture bundles through released
# xchtmlreport versions (and optionally this checkout), diffs what each
# version says about each test, and assembles a browsable comparison site.
#
#   scripts/version-compare/version_compare.sh --head --serve
#
# See README.md in this directory. The MVP runs locally; every stage is
# headless and DEVELOPER_DIR-parameterized so a CI matrix can adopt it later
# (docs/superpowers/specs/2026-08-18-version-compare-harness-design.md).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${HERE}/../.." && pwd)"
CACHE="${XCHTMLREPORT_VC_CACHE:-${HOME}/.cache/xchtmlreport-version-compare}"
FIXTURE_ROOT="${REPO}/Tests/XCTestHTMLReportTests/Resources"

VERSIONS="2.5.1,3.0.0,4.0.0rc1"
FIXTURES="TestResults,SanityResults,RetryResults,CrashResults"
RUN_DIR=""
BASELINE="3.0.0"
HEAD=0
SERVE=0
PORT=8737
STRICT=0

usage() {
    cat <<'EOF'
Usage: version_compare.sh [options]

  --versions LIST   release tags to compare (default 2.5.1,3.0.0,4.0.0rc1)
  --head            also build and include this checkout
  --fixtures LIST   fixture stems (default TestResults,SanityResults,RetryResults,CrashResults)
  --run DIR         run directory (default .version-compare/<UTC timestamp>)
  --baseline TAG    default baseline column (default 3.0.0)
  --serve [PORT]    serve the run dir and print the site URL (default port 8737)
  --strict          exit non-zero on failed cells or unexplained diffs
  -h, --help        this text
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --versions)
            VERSIONS="${2:-}"
            if [[ -z "$VERSIONS" ]]; then echo "missing value for --versions" >&2; usage >&2; exit 64; fi
            shift 2 ;;
        --head) HEAD=1; shift ;;
        --fixtures)
            FIXTURES="${2:-}"
            if [[ -z "$FIXTURES" ]]; then echo "missing value for --fixtures" >&2; usage >&2; exit 64; fi
            shift 2 ;;
        --run)
            RUN_DIR="${2:-}"
            if [[ -z "$RUN_DIR" ]]; then echo "missing value for --run" >&2; usage >&2; exit 64; fi
            shift 2 ;;
        --baseline)
            BASELINE="${2:-}"
            if [[ -z "$BASELINE" ]]; then echo "missing value for --baseline" >&2; usage >&2; exit 64; fi
            shift 2 ;;
        --serve)
            SERVE=1
            if [[ "${2:-}" =~ ^[0-9]+$ ]]; then PORT="$2"; shift; fi
            shift ;;
        --strict) STRICT=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 64 ;;
    esac
done

if [[ -z "$RUN_DIR" ]]; then
    RUN_DIR="${REPO}/.version-compare/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$RUN_DIR"

FIXTURE_PATHS=()
IFS=',' read -ra STEMS <<< "$FIXTURES"
for stem in "${STEMS[@]}"; do
    FIXTURE_PATHS+=("${FIXTURE_ROOT}/${stem}.xcresult")
done

# Stale or stub fixtures poison every column identically; the shared gate
# names every offender (#454). Regenerate with ./prepareTestResults.sh.
"${REPO}/scripts/verify_fixtures.sh" "${FIXTURE_PATHS[@]}"

ACQUIRE_ARGS=(--cache-dir "$CACHE" --versions "$VERSIONS"
              --out "${RUN_DIR}/acquire.json")
if [[ $HEAD -eq 1 ]]; then
    ACQUIRE_ARGS+=(--head "$REPO")
fi
python3 "${HERE}/acquire.py" "${ACQUIRE_ARGS[@]}"

FIXTURE_LIST="$(IFS=','; echo "${FIXTURE_PATHS[*]}")"
python3 "${HERE}/render.py" --tools "${RUN_DIR}/acquire.json" \
    --fixtures "$FIXTURE_LIST" --out "${RUN_DIR}/render"

python3 "${HERE}/extract.py" --render "${RUN_DIR}/render" \
    --out "${RUN_DIR}/extract"

python3 "${HERE}/diff.py" --extract "${RUN_DIR}/extract" \
    --out "${RUN_DIR}/diff" --default-baseline "$BASELINE"

python3 "${HERE}/assemble.py" --run "$RUN_DIR"

SUMMARY="${RUN_DIR}/diff/summary.json"
python3 - "$SUMMARY" <<'EOF'
import json, sys
with open(sys.argv[1]) as handle:
    s = json.load(handle)
print(f"summary: {s['unexplained']} unexplained, {s['expectedOnly']} expected, "
      f"{s['cellsFailed']} failed cells, {s['cellsNoData']} cells without data "
      f"(baseline {s['defaultBaseline']})")
EOF

if [[ $STRICT -eq 1 ]]; then
    python3 - "$SUMMARY" <<'EOF'
import json, sys
with open(sys.argv[1]) as handle:
    s = json.load(handle)
sys.exit(1 if (s["unexplained"] or s["cellsFailed"]) else 0)
EOF
fi

if [[ $SERVE -eq 1 ]]; then
    echo "site: http://localhost:${PORT}/site/index.html"
    ( cd "$RUN_DIR" && exec python3 -m http.server "$PORT" )
else
    echo "site: ${RUN_DIR}/site/index.html (table works from file://; panes need --serve)"
fi
