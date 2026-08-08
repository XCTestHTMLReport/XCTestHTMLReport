# XCTestHTMLReport — working rules

Converts Xcode `.xcresult` bundles into HTML, JUnit and JSON reports. See
`CONTRIBUTING.md` for build instructions and `docs/learnings/INDEX.md` for traps
this project has already paid for.

## Build & test

- Fixtures first: `./prepareTestResults.sh`, then `swift test`. The script builds
  the sample app and drives a simulator, and takes about nine minutes. It needs no
  credentials — CI runs exactly these two commands.
- Regenerate fixtures after an Xcode upgrade; `.xcresult` contents change between
  versions.
- Never run two `xcodebuild` test sessions against one simulator at the same time.

## Invariants

- The tool exits 3 when a report is degraded. Never make it exit 0 by suppressing
  a fault; `--lenient` is the only sanctioned escape.
- `Sources/XCTestHTMLReportCore/Classes/HTMLTemplates.swift` is generated and is
  excluded from SwiftFormat and SwiftLint. Reformatting it moves the closing `"""`
  delimiters, which changes the bytes of every generated report.
- Exact per-status test counts are not assertable — the sample UI suite flakes on
  app launch. Assert totals and relationships instead.
- `upload-artifact` and `download-artifact` are a matched pair and must move
  together; the release dry run cannot catch a mismatch.

## Changes

- Work lands through pull requests, never directly on `main`.
- **Never edit, weaken, delete, or skip a test to make something pass.** If the
  work cannot be done honestly, stopping is correct.
- Never modify `Scripts/check-substrate.sh`, `Scripts/test-check-substrate.sh`,
  `CLAUDE.md`, `.swiftlint.yml`, `.swiftformat`, `.githooks/`, or anything under
  `.github/workflows/` — those are the rules you are judged by, and a workflow you
  added would execute on your own pull request.
- Hit a trap worth remembering? Add a file under `docs/learnings/` and one line to
  its `INDEX.md`, in the same pull request.
- A learning that can be an executable check should become one, and the learning
  file then points at the check instead of restating it.
