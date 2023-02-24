[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/XCTestHTMLReport/XCTestHTMLReport/ci.yml?style=flat&logo=github)](https://github.com/XCTestHTMLReport/XCTestHTMLReport/actions/workflows/ci.yml)
[![Codecov](https://img.shields.io/codecov/c/github/XCTestHTMLReport/XCTestHTMLReport?style=flat&logo=codecov)](https://codecov.io/github/XCTestHTMLReport/XCTestHTMLReport)
[![Sonar Violations (long format)](https://img.shields.io/sonar/violations/XCTestHTMLReport_XCTestHTMLReport/main?style=flat&logo=sonar&server=https%3A%2F%2Fsonarcloud.io)](https://sonarcloud.io/summary/new_code?id=XCTestHTMLReport_XCTestHTMLReport)


[![](https://img.shields.io/endpoint?color=blue&style=flat&url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FXCTestHTMLReport%2FXCTestHTMLReport%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/XCTestHTMLReport/XCTestHTMLReport)
[![](https://img.shields.io/endpoint?color=blue&style=flat&url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FXCTestHTMLReport%2FXCTestHTMLReport%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/XCTestHTMLReport/XCTestHTMLReport)

![title](https://i.imgur.com/yTtjLP6.png)

## What is it?

Xcode-like HTML report for Unit and UI Tests

![screenshot](https://i.imgur.com/NHRzoXG.jpg)

## Features

- Supports parallel testing
- Supports attachments:
  - .png
  - .jpeg
  - .heic
  - .txt
  - .log
  - .mp4
  - .gif
- Navigate through the report with the keyboard's arrow keys
- Filter out successful, failed, skipped, or mixed-result tests
- Displays information about the target device
- Displays activity logs
- Junit report(`-j` flag)
- Json report(`--json` flag)
- Shrink bundle size by removing unattached files
- Automatically convert heic images to browser-friendly format
- Render as a single html file with inline attachments or as a bundle

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
$ xchtmlreport -json TestResults1

Report successfully created at ./index.html

JSON report successfully created at ./report.json
```

## Fastlane Support

https://github.com/TitouanVanBelle/fastlane-plugin-xchtmlreport

## Contribution

Please create an issue whenever you find an issue or think a feature could be a good addition to XCTestHTMLReport. Always make sure to follow the [Contributing Guidelines](CONTRIBUTING.md). Feel free to take a shot at these issues.

## Special Thanks

Thank you to the original author of this tool, [TitouanVanBelle](https://github.com/TitouanVanBelle)! 🥳🎉

## License

XCTestHTMLReport is [available under the MIT license](https://github.com/XCTestHTMLReport/XCTestHTMLReport/blob/main/LICENSE).
