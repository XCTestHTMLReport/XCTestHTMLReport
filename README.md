:warning: **Looking for collaborators to maintain XCTestHTMLReport**: Drop me a line :warning: 

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
- Navigate through the report with the keyboard's arrow keys
- Filter out successful or failed tests
- Displays information about the target device
- Displays activity logs
- Junit report

## Fastlane Support

https://github.com/TitouanVanBelle/fastlane-plugin-xchtmlreport

## Installation

### Homebrew

Install via [Homebrew](https://brew.sh/).

```bash
# Install latest stable version
$ brew install https://raw.githubusercontent.com/TitouanVanBelle/XCTestHTMLReport/develop/xchtmlreport.rb

# Install latest master branch
$ brew install --HEAD https://raw.githubusercontent.com/TitouanVanBelle/XCTestHTMLReport/develop/xchtmlreport.rb
```

### Alternate

Simply execute the following command to download the latest version of XCTestHTMLReport

``` bash
$ bash <(curl -s https://raw.githubusercontent.com/TitouanVanBelle/XCTestHTMLReport/master/install.sh)
```

You can also specify a branch or tag

``` bash
$ bash <(curl -s https://raw.githubusercontent.com/TitouanVanBelle/XCTestHTMLReport/master/install.sh) '1.0.0'
```

## Usage

Run your UI tests using `xcodebuild` without forgetting to specify the `resultBundlePath`

``` bash
$ xcodebuild test -workspace XCTestHTMLReport.xcworkspace -scheme XCTestHTMLReportSampleApp -destination 'platform=iOS Simulator,name=iPhone 7,OS=11.0' -resultBundlePath TestResults
```

Then use the previously downloaded xchtmlreport tool to create the HTML report. Additionally, `-i` flag is also available to inline all resources, this is convenient for exporting the html file standalone. HTML file will be much heavier but much more portable.

``` bash
$ xchtmlreport -r TestResults

Report successfully created at ./index.html
```

### Multiple Result Bundle Path

You can also pass multiple times the -r option.

``` bash
$ xchtmlreport -r TestResults1 -r TestResults2

Report successfully created at ./index.html
```

This will create only one HTML Report in the path you passed with the -r option

### Generate Junit Reports

You can generate junit reports with the `-j` flag

``` bash
$ xchtmlreport -r TestResults1 -j

Report successfully created at .index.html

JUnit report successfully created at TestResults1.xcresult/report.junit
```



## Contribution

Please create an issue whenever you find an issue or think a feature could be a good addition to XCTestHTMLReport. Always make sure to follow the [Contributing Guidelines](https://github.com/TitouanVanBelle/XCTestHTMLReport/blob/master/CONTRIBUTING.md). Feel free to take a shot at these issues.

## License

XCTestHTMLReport is [available under the MIT license](https://github.com/TitouanVanBelle/XCTestHTMLReport/blob/master/LICENSE).
