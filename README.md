# XCUITestHTMLReport

Xcode-like HTML report for UI Tests

## Installation

Simply go to your iOS project and download the latest version of XCUITestHTMLReport

``` bash
$ curl -o xchtmlreport https://raw.githubusercontent.com/TitouanVanBelle/XCUITestHTMLReport/master/xchtmlreport
```

or download a specific version

``` bash
$ curl -o xchtmlreport https://raw.githubusercontent.com/TitouanVanBelle/XCUITestHTMLReport/1.0.0/xchtmlreport
```

## Usage

Run your UI tests using `xcodebuild` without forgetting to specify the `resultBundlePath`

``` bash
$ xcodebuild test -workspace XCUITestHTMLReport.xcworkspace -scheme XCUITestHTMLReportSampleApp -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.0' -resultBundlePath TestResults
```

Then use the previously downloaded xchtmlreport tool to create the HTML report

``` bash
$ ./xchtmlreport -r TestResults
```

## Contribution

Please create an issue whenever you find an issue or think a feature could be a good addition to XCUITestHTMLReport. Also feel free to take a shot at these issues.

## License

XCUITestHTMLReport is [available under the MIT license](https://github.com/TitouanVanBelle/XCUITestHTMLReport/blob/master/LICENSE).
