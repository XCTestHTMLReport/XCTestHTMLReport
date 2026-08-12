# Learnings Index

Traps this project has already paid for. One line each; the file has the detail.

- [Runner images drop old Xcode versions](runner-image-drops-xcode-versions.md) — a pinned Xcode can vanish from `macos-latest`
- [SwiftLint lints dependencies unscoped](swiftlint-lints-dependencies-unscoped.md) — findings in the thousands means it is reading `.build`, not your code
- [`HTMLTemplates.swift` is generated](html-templates-is-generated.md) — reformatting it changes every generated report
- [Sample UI suite flakes on launch](sample-ui-suite-flakes-on-launch.md) — exact per-status counts are not assertable
- [The release job is unreachable by the dry run](release-job-is-unreachable-by-dry-run.md) — ask what the dry run does not cover
- [`read` under `set -e` skips its guard](read-under-set-e-skips-its-guard.md) — empty input kills the script before the error message
