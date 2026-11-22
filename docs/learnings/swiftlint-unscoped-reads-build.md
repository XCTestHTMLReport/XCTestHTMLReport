# SwiftLint run unscoped lints `.build/checkouts`

Run without the committed config (`swiftlint lint --config <empty file>` after
`swift package resolve`), SwiftLint reports thousands of violations, about
7,300 on 2026-11-22, and 98% of them are in `.build/checkouts`: SwiftSoup,
XCResultKit, Rainbow and swift-argument-parser, not this codebase. With
`.swiftlint.yml`, which sets `included:` and excludes `.build`, the same tree
reports a few dozen warnings and no errors. The exact counts move with
dependency and SwiftLint versions; the magnitude is the point.

**A count in the thousands means the tool is reading the wrong tree.** Run it
from the repository root with the committed config, through the version
`mise.toml` pins (`mise x -- swiftlint lint`).

Paths passed explicitly ignore `excluded:` unless `--force-exclude` is given,
which is why the `hk.pkl` step passes it.
