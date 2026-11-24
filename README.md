[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/XCTestHTMLReport/XCTestHTMLReport/ci.yml?style=flat&logo=github)](https://github.com/XCTestHTMLReport/XCTestHTMLReport/actions/workflows/ci.yml)
[![Codecov](https://img.shields.io/codecov/c/github/XCTestHTMLReport/XCTestHTMLReport?style=flat&logo=codecov)](https://codecov.io/github/XCTestHTMLReport/XCTestHTMLReport)


[![](https://img.shields.io/endpoint?color=blue&style=flat&url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FXCTestHTMLReport%2FXCTestHTMLReport%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/XCTestHTMLReport/XCTestHTMLReport)
[![](https://img.shields.io/endpoint?color=blue&style=flat&url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FXCTestHTMLReport%2FXCTestHTMLReport%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/XCTestHTMLReport/XCTestHTMLReport)

![title](https://i.imgur.com/yTtjLP6.png)

## What is it?

Xcode-like HTML report for Unit and UI Tests

**[▶ Open a live report](https://xctesthtmlreport.github.io/XCTestHTMLReport/)** — rendered from this repository's own sample test run, republished on every merge to `main`, so it shows the upcoming 4.0 report rather than the 3.0.0 one.

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
-   Optionally shows equivalent devices as one (`--merge-destinations` flag)
-   Displays activity logs
-   Junit report (`-j` flag)
-   Json report (`--json` flag)
-   Shrink bundle size by removing unattached files (`-d` flag)
-   Render as a single html file with inline attachments (`-i` flag) or as a bundle
-   Downsize image attachments (`-z` flag, scaled by `--downsize-scale-factor`)
-   Convert .heic images to JPEG, but only when downsizing with `-z`. Without it
    they are left as .heic, which not every browser can display
    ([#322](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/322))

## Requirements

-   macOS 10.15 is the declared deployment target; nothing that old is tested.
-   Xcode, because result bundles are read through `xcrun xcresulttool`. The
    Homebrew formula needs Xcode 14 or later to build.
-   Every change is built with Xcode 16 and with the latest stable Xcode, and
    tested against result bundles produced by the latest stable Xcode, plus a
    newer released Xcode when GitHub's runners offer one ahead of the stable
    image. Bundles from older Xcode versions are not tested.

The latest release is **3.0.0**, and that is what Homebrew and Mint install.
Anything below marked **since 4.0** is on `main` only until 4.0 is released;
install from `main` to use it.


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

### Release binary

Each [release](https://github.com/XCTestHTMLReport/XCTestHTMLReport/releases)
has `xchtmlreport-<version>.zip` attached: a universal (arm64 and x86_64)
binary, signed with a Developer ID and notarized by Apple.

```bash
VERSION=3.0.0
curl -fLO "https://github.com/XCTestHTMLReport/XCTestHTMLReport/releases/download/${VERSION}/xchtmlreport-${VERSION}.zip" &&
  unzip "xchtmlreport-${VERSION}.zip" &&
  codesign --verify --strict --verbose \
    -R='anchor apple generic and certificate leaf[subject.OU] = "352UZEKYPP"' \
    release/xchtmlreport &&
  sudo mv release/xchtmlreport /usr/local/bin/ &&
  xchtmlreport --version
```

The zip extracts to `release/xchtmlreport`; move it anywhere on your `PATH`.
The `-R` requirement checks that the binary was signed by this project's
Developer ID (team `352UZEKYPP`), not just by some valid identity, and each
step runs only if the one before it succeeded.

## Usage

Run your own project's tests using `xcodebuild` without forgetting to specify the `resultBundlePath`.
Replace the project, scheme and destination with yours (`-workspace` instead of `-project` if you use one):

``` bash
$ xcodebuild test -project MyApp.xcodeproj -scheme MyApp -destination 'platform=iOS Simulator,name=<a simulator you have>' -resultBundlePath TestResults
```

That writes `TestResults.xcresult`. Then use the previously downloaded xchtmlreport tool to create the HTML report. Additionally, `-i` flag is also available to inline all resources, this is convenient for exporting the html file standalone. HTML file will be much heavier but much more portable.

``` bash
$ xchtmlreport TestResults.xcresult

Report successfully created at /path/to/index.html
```

The report is written next to the result bundle. Pass `-o <directory>` to put it somewhere else.

`xchtmlreport --help` lists every option.

### Multiple Result Bundle Path

``` bash
$ xchtmlreport TestResults1.xcresult TestResults2.xcresult

Report successfully created at /path/to/index.html
```

This creates one HTML report covering both bundles, next to the first bundle or in the directory given with `-o`.
Pass the bundles as arguments: the older `-r` option still works but is deprecated.

### Progress

**Since 4.0.** A large result bundle takes a while, and a silent run is hard to tell from a
hung one. When standard error is a terminal, each phase is reported as it
finishes, with the time it took:

``` bash
$ xchtmlreport TestResults.xcresult
    Exporting 2531 attachments          4.8s
  Reading TestResults.xcresult         18.2s
  Rendering 1284 tests                 12.4s
  Writing report                        0.9s
Wrote /path/to/index.html (412 MB)     36.3s

Report successfully created at /path/to/index.html
```

Those timings also answer "which part is slow?" on your own bundle rather than
in the abstract. Indented lines are nested inside the line below them —
attachment export happens during the read.

The rules are `git`'s. Progress goes to **standard error**, so a pipeline
reading the report path off stdout (`xchtmlreport … | xargs open`) is
unaffected. It is off when standard error is not a terminal, so scripts and CI
logs are unchanged. `--progress` forces it on anyway, and `--quiet` turns it
off.

### Merge Equivalent Destinations

Parallel testing clones the simulator it runs on, and merging bundles with
`xcrun xcresulttool merge` keeps each bundle's device, so one logical run can
arrive as several destinations — each holding an arbitrary slice of the suite.
`--merge-destinations` shows destinations with the same device model and OS
version as one, the way Xcode does:

``` bash
$ xcrun xcresulttool merge Shard1.xcresult Shard2.xcresult --output-path Merged.xcresult
$ xchtmlreport --merge-destinations Merged.xcresult
```

The Tests view holds every test from every merged destination, and the Logs
view holds each destination's log under its device name. Only the HTML report
is affected: JUnit and JSON output still have one entry per destination.

### Generate Junit Reports

You can generate junit reports with the `-j` flag

``` bash
$ xchtmlreport -j TestResults.xcresult

Report successfully created at /path/to/index.html

JUnit report successfully created at /path/to/report.junit
```

### Generate JSON Reports

You can generate json reports with the `--json` flag

``` bash
$ xchtmlreport --json TestResults.xcresult

Report successfully created at /path/to/index.html

JSON report successfully created at /path/to/report.json
```

**Since 4.0**, `report.json` is our own documented, versioned schema —
[docs/json-schema.md](docs/json-schema.md) is the contract. The *schema* is
identical whichever result reader produced it: same keys, same nesting, same
`schemaVersion`. A few *values* legitimately differ between readers — the
four differences listed under "Choosing the result reader" below, plus
`testCase.arguments`, which only the modern reader can populate — and the
contract documents each one. Earlier versions, 3.0.0 included, write
`xcresulttool`'s legacy invocation record as XCResultKit decodes it: an array
with one entry per bundle, `null` for a bundle it could not read, otherwise an
object with the keys `actions` (an array), `issues`, `metrics` and
`metadataRef`, in no fixed order. Only `metadataRef.referencedObject.json`
still holds `xcresulttool`'s own `_type`/`_value` JSON, base64-encoded. That
record is Apple's internal shape and disappears together with the legacy
commands, so 4.0 replaces it once, deliberately. The change is visible at a
glance — 3.0.0:

``` json
[{"metadataRef":{"referencedObject":{"json":"eyJzY2hlbWVJZGVudGlmaWVy..."},"targetType":{"name":"ActionsInvocationMetadata"},"id":"0~..."},"metrics":{...},"issues":{...},"actions":[...]}]
```

since 4.0:

``` json
{
  "runs" : [ ... ],
  "schemaVersion" : "1.0.0"
}
```

Consumers should read `schemaVersion` first and follow the version policy in
the contract document.

### Choosing the result reader

**Since 4.0.** `xcresulttool`'s legacy API — the way every version before 4.0 read result
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
  `Assertion Failure at File.swift:12:message`; modern renders
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

Starting in 3.0, `xchtmlreport` exits non-zero when it detects that part of a
result bundle could not be turned into a report. Earlier versions exited 0 and
printed a success message even when parts of the report were missing, so pipelines
had no way to detect an incomplete report.

What counts as detected has grown. 3.0.0 reports a bundle it cannot read at all,
an attachment with nothing behind it, and a failed attachment or log export.
**Since 4.0** more counts, including a run that stopped early: a host app that
crashes at launch gives a bundle that 3.0.0 renders and exits 0 on, and that
`main` exits 3 on.

Exit 0 means no faults were *detected*, which is not yet the same as a guaranteed
complete report: some XCResultKit decode failures are not surfaced as faults today
and are still only visible as messages on stderr. See
[#378](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/378) and the
follow-on work it tracks.

Exit 1 covers failures to write the output. In 3.0.0 that includes `-o` pointing
at a directory that does not exist. **Since 4.0** a missing `-o` directory is not one
of them: it is created for you, intermediate components included, before any parsing
or rendering starts. A directory that cannot be created — no write permission on
the parent, or a file in the way — is an argument error (64), reported up front and
naming the path.

The report is still written when faults occur. To restore the pre-3.0 behaviour and
always exit 0 on faults, pass `--lenient`. `--lenient` does not affect exit 1 or 64.

## Fastlane Support

There is a third-party plugin, https://github.com/TitouanVanBelle/fastlane-plugin-xchtmlreport,
but it is **unmaintained**: it was last updated in June 2021, and people have reported in
[#64](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/64) that it does not work for them.
Calling `xchtmlreport` from a lane with fastlane's `sh` action needs no plugin.

## Contribution

Please create an issue whenever you find an issue or think a feature could be a good addition to XCTestHTMLReport. Always make sure to follow the [Contributing Guidelines](CONTRIBUTING.md). Feel free to take a shot at these issues.

## Special Thanks

Thank you to the original author of this tool, [TitouanVanBelle](https://github.com/TitouanVanBelle)! 🥳🎉

## License

XCTestHTMLReport is [available under the MIT license](https://github.com/XCTestHTMLReport/XCTestHTMLReport/blob/main/LICENSE).
