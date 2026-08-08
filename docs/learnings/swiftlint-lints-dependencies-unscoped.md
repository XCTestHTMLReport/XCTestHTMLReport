# SwiftLint lints `.build/checkouts` unless scoped

Run bare, `swiftlint lint` reported **7,285 warnings and 2,570 errors** on this
project. Scoped to real sources it reports 65 and 24 — the rest were SwiftSoup,
XCResultKit, Rainbow and swift-argument-parser.

A number that large is a signal the tool is looking at the wrong tree, not that
the codebase is in crisis.

`.swiftlint.yml` sets `included:` and excludes `.build`, so this is already
handled. Do not run SwiftLint without it and act on the output.
