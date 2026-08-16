[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/XCTestHTMLReport/XCTestHTMLReport/ci.yml?style=flat&logo=github)](https://github.com/XCTestHTMLReport/XCTestHTMLReport/actions/workflows/ci.yml)
[![Codecov](https://img.shields.io/codecov/c/github/XCTestHTMLReport/XCTestHTMLReport?style=flat&logo=codecov)](https://codecov.io/github/XCTestHTMLReport/XCTestHTMLReport)


[![](https://img.shields.io/endpoint?color=blue&style=flat&url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FXCTestHTMLReport%2FXCTestHTMLReport%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/XCTestHTMLReport/XCTestHTMLReport)
[![](https://img.shields.io/endpoint?color=blue&style=flat&url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FXCTestHTMLReport%2FXCTestHTMLReport%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/XCTestHTMLReport/XCTestHTMLReport)

![title](https://i.imgur.com/yTtjLP6.png)

## What is it?

Xcode-like HTML report for Unit and UI Tests

**[▶ Open a live report](https://xctesthtmlreport.github.io/XCTestHTMLReport/)** — rendered from this repository's own sample test run, republished on every merge to `main`. Past releases are at **[/v/](https://xctesthtmlreport.github.io/XCTestHTMLReport/v/)**.

![screenshot](https://i.imgur.com/NHRzoXG.jpg)

## Features

-   Supports parallel testing
-   Supports attachments:
    -   .png
    -   .jpeg
    -   .heic
    -   .txt
    -   .log
    -   .mp4
    -   .gif
-   Navigate through the report with the keyboard's arrow keys
-   Filter out successful, failed, skipped, or mixed-result tests
-   Displays information about the target device
-   Displays activity logs
-   Junit report(`-j` flag)
-   Json report(`--json` flag)
-   Shrink bundle size by removing unattached files
-   Automatically convert heic images to browser-friendly format
-   Render as a single html file with inline attachments or as a bundle
-   Downsize image attachments


## Installation

### Homebrew (recommended)

Install via [Homebrew](https://brew.sh/)

Install latest stable version

```bash
brew install xctesthtmlreport
```

Install latest from `main` branch

```
brew install xctesthtmlreport --HEAD
```

### Mint

Install via [Mint](https://github.com/yonaskolb/Mint)

Install latest stable version

```bash
mint install XCTestHTMLReport/XCTestHTMLReport
```

Install latest from `main` branch

```
mint install XCTestHTMLReport/XCTestHTMLReport@main
```

## Usage

Run your UI tests using `xcodebuild` without forgetting to specify the `resultBundlePath`

``` bash
$ xcodebuild test -workspace XCTestHTMLReport.xcworkspace -scheme SampleApp -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.0' -resultBundlePath TestResults
```

Then use the previously downloaded xchtmlreport tool to create the HTML report. Additionally, `-i` flag is also available to inline all resources, this is convenient for exporting the html file standalone. HTML file will be much heavier but much more portable.

``` bash
$ xchtmlreport TestResults.xcresult

Report successfully created at ./index.html
```

### Multiple Result Bundle Path

``` bash
$ xchtmlreport TestResults1 TestResults2

Report successfully created at ./index.html
```

This will create only one HTML Report in the path you passed with the -r option

### Progress

A large result bundle takes a while, and a silent run is hard to tell from a
hung one. When standard error is a terminal, each phase is reported as it
finishes, with the time it took:

``` bash
$ xchtmlreport TestResults.xcresult
    Exporting 2531 attachments          4.8s
  Reading TestResults.xcresult         18.2s
  Rendering 1284 tests                 12.4s
  Writing report                        0.9s
Wrote ./index.html (412 MB)            36.3s

Report successfully created at ./index.html
```

Those timings also answer "which part is slow?" on your own bundle rather than
in the abstract. Indented lines are nested inside the line below them —
attachment export happens during the read.

The rules are `git`'s. Progress goes to **standard error**, so a pipeline
reading the report path off stdout (`xchtmlreport … | xargs open`) is
unaffected. It is off when standard error is not a terminal, so scripts and CI
logs are unchanged. `--progress` forces it on anyway, and `--quiet` turns it
off.

### Generate Junit Reports

You can generate junit reports with the `-j` flag

``` bash
$ xchtmlreport -j TestResults1

Report successfully created at ./index.html

JUnit report successfully created at report.junit
```

### Generate JSON Reports

You can generate json reports with the `--json` flag

``` bash
$ xchtmlreport --json TestResults1

Report successfully created at ./index.html

JSON report successfully created at ./report.json
```

Starting in 4.0, `report.json` is our own documented, versioned schema —
[docs/json-schema.md](docs/json-schema.md) is the contract. The *schema* is
identical whichever result reader produced it: same keys, same nesting, same
`schemaVersion`. A few *values* legitimately differ between readers — the
four differences listed under "Choosing the result reader" below, plus
`testCase.arguments`, which only the modern reader can populate — and the
contract documents each one. Earlier versions dumped
`xcresulttool`'s legacy object graph verbatim; that graph is Apple's
internal shape and disappears together with the legacy commands, so 4.0
replaces it once, deliberately. The change is visible at a glance — before:

``` json
[{"_type":{"_name":"ActionsInvocationRecord"},"actions":{"_type":{"_name":"Array"},"_values":[...
```

after:

``` json
{
  "runs" : [ ... ],
  "schemaVersion" : "1.0.0"
}
```

Consumers should read `schemaVersion` first and follow the version policy in
the contract document.

### Choosing the result reader

`xcresulttool`'s legacy API — the way every version before 4.0 read result
bundles — is deprecated and will be removed from Xcode. `xchtmlreport` now
has two readers and picks one per run:

``` bash
$ xchtmlreport --result-reader auto TestResults.xcresult    # the default
```

- `auto` prefers `legacy` while the toolchain still offers the legacy
  commands, and falls back to `modern` once they are gone (or when the probe
  cannot tell).
- `modern` forces the new-format reader on any toolchain.
- `legacy` forces the legacy reader; if the toolchain no longer provides the
  legacy commands this is an error, never a silent substitution.

The `XCHR_RESULT_READER` environment variable sets the default when the flag
is absent — useful for forcing a whole CI job onto one reader.

Reports from the two readers are held byte-identical by a differential test
suite, up to a short declared list of differences the new format cannot
avoid:

- **Attachment display names.** The new format does not expose the
  user-supplied `XCTAttachment` name, so the modern reader labels
  attachments by their type (`Screenshot`, `Video`, `File`).
- **Failure title prefixes.** Legacy renders
  `Assertion Failure at File.swift:12: message`; modern renders
  `File.swift:12: message` — the new format pre-joins the string and drops
  the issue type.
- **Wrapper groups.** Legacy nests two extra levels
  (`All tests` / `Selected tests`, then `<target>.xctest`) that the new
  format does not have; the modern reader renders the natural flat tree.
- **Group durations.** The new format reports no duration for test suites
  and bundles, so the modern reader shows `(0.00s)` where legacy shows a
  real value.

`--json` output additionally carries `testCase.arguments` (Swift Testing
`@Test(arguments:)` values), which only the modern reader can populate — the
legacy format has no counterpart, so it is always `[]` there. See the
[schema contract](docs/json-schema.md) for how consumers should compare
reports across readers.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | No faults detected |
| 1 | The report could not be written |
| 3 | Report was generated but is **degraded** — some of the result bundle could not be fully processed |
| 64 | Invalid arguments |

Starting in 3.0, `xchtmlreport` exits non-zero when part of a result bundle cannot
be turned into a report. Earlier versions exited 0 and printed a success message
even when parts of the report were missing, so pipelines had no way to detect an
incomplete report.

Exit 0 means no faults were *detected*, which is not yet the same as a guaranteed
complete report: some XCResultKit decode failures are not surfaced as faults today
and are still only visible as messages on stderr. See
[#378](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/378) and the
follow-on work it tracks.

Exit 1 covers failures to write the output. A missing `-o` directory is not one of
them: it is created for you, intermediate components included, before any parsing
or rendering starts. A directory that cannot be created — no write permission on
the parent, or a file in the way — is an argument error (64), reported up front and
naming the path.

The report is still written when faults occur. To restore the pre-3.0 behaviour and
always exit 0 on faults, pass `--lenient`. `--lenient` does not affect exit 1 or 64.

## Fastlane Support

https://github.com/TitouanVanBelle/fastlane-plugin-xchtmlreport

## Contribution

Please create an issue whenever you find an issue or think a feature could be a good addition to XCTestHTMLReport. Always make sure to follow the [Contributing Guidelines](CONTRIBUTING.md). Feel free to take a shot at these issues.

## Special Thanks

Thank you to the original author of this tool, [TitouanVanBelle](https://github.com/TitouanVanBelle)! 🥳🎉

## License

XCTestHTMLReport is [available under the MIT license](https://github.com/XCTestHTMLReport/XCTestHTMLReport/blob/main/LICENSE).
