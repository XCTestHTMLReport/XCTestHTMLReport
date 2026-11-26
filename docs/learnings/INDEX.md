# Learnings

Traps this project has already paid for. One line each; the file has the
detail. Every file in this directory is listed here, and every entry here is a
file: `scripts/check_agent_rules.py` fails CI otherwise.

## CI and runners

- [Runner images drop old Xcode versions](runner-images-drop-xcode-versions.md) — pin the image, not just the Xcode
- [`ubuntu-latest` moves too](ubuntu-latest-moves-too.md) — a red Linux job with no diff is usually the image
- [A "beta" runner image can hold the shipping Xcode](preview-image-ships-a-release.md) — ask the Xcode, not the label
- [One pending run per concurrency group](one-pending-run-per-concurrency-group.md) — a ref-keyed group drops runs on `main`
- [The release job is unreachable by the dry run](release-job-is-unreachable-by-dry-run.md) — it builds and signs; attesting, publishing and the second artifact hand-off wait for a tag
- [A tag's shape reaches the package managers](tag-shape-reaches-package-managers.md) — Mint, Homebrew and version-increment each parse tags their own way

## Reading bundles and testing

- [The legacy run-log shape follows the writing Xcode](legacy-run-log-follows-the-writing-xcode.md) — cross bundle writer and reader before blaming either
- [Exact pass/fail splits are not assertable](generated-fixture-counts-are-not-exact.md) — assert what the sample sources determine
- [`HTMLTemplates.swift` is hand-maintained](html-templates-is-hand-maintained.md) — reformatting it changes every report
- [SwiftSoup reuses source bytes](swiftsoup-reuses-source-bytes.md) — an edited and an untouched document serialize differently
- [Benchmark against the last release](benchmark-against-the-last-release.md) — 4.0 serialised reads 3.0.0 ran concurrently, and main-vs-main never showed it
- [Everything in a result bundle belongs to Xcode](the-bundle-belongs-to-xcode.md) — delete only files this tool wrote, never what the report merely does not link

## Tooling

- [SwiftLint run unscoped lints `.build`](swiftlint-unscoped-reads-build.md) — thousands of findings means the wrong tree
- [`read` under `set -e` skips its guard](read-under-set-e-skips-its-guard.md) — empty input kills the script before the error message
- [Signing git commits from the maintainer's Mac](signing-commits-from-the-maintainers-mac.md) — agent key inline, HTTPS push, never unsigned
