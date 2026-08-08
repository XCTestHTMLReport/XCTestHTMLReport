# SwiftLint lints `.build/checkouts` unless scoped

Run bare, `swiftlint lint` reports **tens of thousands of violations across roughly
a thousand files** — over 99% of them from SwiftSoup, XCResultKit, Rainbow,
SwiftFormat and swift-argument-parser under `.build/checkouts`, not from this
codebase. The exact count moves with dependency and SwiftLint versions; the
magnitude is the point.

With the committed `.swiftlint.yml`, which sets `included:` and excludes `.build`,
the same command reports **26 warnings and 0 errors**.

A count in the thousands is a signal the tool is looking at the wrong tree, not
that the codebase is in crisis.

`.swiftlint.yml` sets `included:` and excludes `.build`, so this is already
handled. Do not run SwiftLint without it and act on the output.
