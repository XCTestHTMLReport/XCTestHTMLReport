![title](http://i.imgur.com/3eKi88j.jpg)

## What is it?

Xcode-like HTML report for UI Tests

![screenshot](https://i.imgur.com/NHRzoXG.jpg)

## Features

- Supports parallel testing
- Supports attachments:
  - .png
  - .jpeg
  - .txt
- Navigate through the report with the keyboard's arrow keys
- Filter out successful or failed tests
- Displays information about the target device
- Displays activity logs

## Installation

Simply execute the following command to download the latest version of XCUITestHTMLReport

``` bash
$ bash <(curl -s https://raw.githubusercontent.com/TitouanVanBelle/XCUITestHTMLReport/master/install.sh)
```

You can also specify a branch or tag

``` bash
$ bash <(curl -s https://raw.githubusercontent.com/TitouanVanBelle/XCUITestHTMLReport/master/install.sh) '1.0.0'
```

## Usage

Run your UI tests using `xcodebuild` without forgetting to specify the `resultBundlePath`

``` bash
$ xcodebuild test -workspace XCUITestHTMLReport.xcworkspace -scheme XCUITestHTMLReportSampleApp -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.0' -resultBundlePath TestResults
```

Then use the previously downloaded xchtmlreport tool to create the HTML report

``` bash
$ xchtmlreport -r TestResults

Report successfully created at TestResults/index.html
```

## Contribution

Please create an issue whenever you find an issue or think a feature could be a good addition to XCUITestHTMLReport. Always make sure to follow the [Contributing Guidelines](https://github.com/TitouanVanBelle/XCUITestHTMLReport/blob/master/CONTRIBUTING.md). Feel free to take a shot at these issues.

## License

XCUITestHTMLReport is [available under the MIT license](https://github.com/TitouanVanBelle/XCUITestHTMLReport/blob/master/LICENSE).
