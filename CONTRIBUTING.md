# Contributing Guidelines

This document contains information and guidelines about contributing to this project.
Please read it before you start participating.

**Topics**

* [Reporting Issues](#reporting-issues)
* [Submitting Pull Requests](#submitting-pull-requests)

## Reporting Issues

A great way to contribute to the project
is to send a detailed issue when you encounter an problem.
I always appreciate a well-written, thorough bug report.

Check that the project issues database
doesn't already include that problem or suggestion before submitting an issue.
If you find a match, add a quick "+1" or "I have this problem too."
Doing this helps prioritize the most common problems and requests.

When reporting issues, please include the following:

* The version of Xcode you're using
* The version of iOS or OS X you're targeting
* The full output of the command
* An archive of the resultBundlePath (Whenever possible)
* Any other details that would be useful in understanding the problem

This information will help  review and fix your issue faster.

[Create an issue](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/new)

## Submitting Pull Requests

Pull requests are welcome, and greatly encouraged. When submitting a pull request, please add a description that explains what the changes are about. Link the ticket whenever possible.

* As usual, anyone can clone the repository. Then do the fixes/improvements as needed in own repository. When it is finished you can start the request to pull code from your own repo to XCTestHTMLReport repo. 

### Building and testing

The test suite runs against real `.xcresult` bundles. Generate them once, then
run the tests:

```bash
./prepareTestResults.sh   # builds the sample app and produces fixtures
swift test
```

`prepareTestResults.sh` picks the newest available iPhone simulator automatically.
No credentials or secrets are required — CI runs exactly these two commands, so a
green run locally means a green run on your pull request.

Regenerate fixtures after upgrading Xcode; `.xcresult` contents change between
Xcode versions.

### Optional: run the checks before committing

CI runs shellcheck, SwiftFormat, and SwiftLint. The same checks can run locally on
staged files, so you find problems before pushing:

```bash
git config core.hooksPath .githooks
```

That is opt-in on purpose — nothing installs it for you.

The hook only checks files you are actually committing, and skips a tool entirely
if it is not installed:

```bash
brew install shellcheck swiftformat swiftlint
```

It reports problems rather than rewriting your files, so a commit never contains
changes you have not read. To skip it for one commit:

```bash
git commit --no-verify
```



*Some of the ideas and wording for the statements above were based on [AFNetworking](https://github.com/AFNetworking/AFNetworking).
