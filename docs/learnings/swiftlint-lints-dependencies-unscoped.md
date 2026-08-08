# SwiftLint lints `.build/checkouts` unless scoped

Run bare, `swiftlint lint` reported **7,285 warnings and 2,570 errors** on this
project — the vast majority from SwiftSoup, XCResultKit, Rainbow, SwiftFormat and
swift-argument-parser under `.build/checkouts`, not from this codebase.

With the committed `.swiftlint.yml`, which sets `included:` and excludes `.build`,
the same command reports **26 warnings and 0 errors**.

A number in the thousands is a signal the tool is looking at the wrong tree, not
that the codebase is in crisis.

`.swiftlint.yml` sets `included:` and excludes `.build`, so this is already
handled. Do not run SwiftLint without it and act on the output.
