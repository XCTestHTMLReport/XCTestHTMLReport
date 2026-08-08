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
- `upload-artifact` and `download-artifact` must stay compatible — the release
  job downloads exactly what the build job uploaded. Their majors are versioned
  independently and today read v7 and v8, so check the pairing, not the numbers.
  The release dry run cannot catch a mismatch.

## Changes

- Work lands through pull requests, never directly on `main`.
- **Never edit, weaken, delete, or skip a test to make something pass.** If the
  work cannot be done honestly, stopping is correct.
- Never weaken the checks that judge your work: `Scripts/check-substrate.sh` and
  its test, `.swiftlint.yml`, `.swiftformat`, `.githooks/`, or the CI workflows.
  Changing them is a deliberate decision made in its own pull request, never
  something done in passing to make other work pass.
- Hit a trap worth remembering? Add a file under `docs/learnings/` and one line to
  its `INDEX.md`, in the same pull request.
- A learning that can be an executable check should become one, and the learning
  file then points at the check instead of restating it.
