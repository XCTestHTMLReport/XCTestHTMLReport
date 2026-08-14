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

The Swift test suite runs against real `.xcresult` bundles. Generate them once,
then run the tests:

```bash
./prepareTestResults.sh   # builds the sample app and produces fixtures
swift test
```

`prepareTestResults.sh` picks the newest available iPhone simulator automatically.
No credentials or secrets are required for this part.

If a simulator goes away mid-run, `xcodebuild` can leave an `.xcresult` behind
that looks complete but holds no tests, and the suite then fails with a
confusing error. `scripts/verify_fixtures.sh` — the same gate CI runs — catches
that in a second:

```bash
./scripts/verify_fixtures.sh   # asserts each bundle actually contains tests
```

Regenerate fixtures after upgrading Xcode; `.xcresult` contents change between
Xcode versions.

`swift test` also runs two other layers that need no `.xcresult` and no
simulator, because they render from a hand-written synthetic fixture instead:

- **Template snapshots** — `TemplateSnapshotTests` compares rendered HTML
  against committed goldens in `Tests/XCTestHTMLReportTests/Snapshots/`. If a
  template change is intentional, refresh the goldens and review the diff
  before committing:

  ```bash
  XCHR_UPDATE_SNAPSHOTS=1 swift test --filter TemplateSnapshotTests
  ```

  A refresh run always fails on purpose (`SnapshotSupport.swift`) — writing a
  golden proves nothing about whether the new content is correct. Re-run
  without the environment variable afterwards to get a real verdict.

- **Browser assertions** — `visual/` at the repository root is a separate npm
  project (Playwright + axe-core) checking things only a browser knows:
  computed token values, WCAG contrast in light and dark mode, accessibility
  violations, and interactive behaviour. It reads a report file rather than
  building one, so first dump the synthetic fixture:

  ```bash
  XCHR_VISUAL_DIR="$(pwd)/visual/fixtures" swift test --filter VisualFixtureDumpTests
  cd visual
  npm ci
  npx playwright test
  ```

  CI runs this as two jobs, mirrored above: a macOS job dumps the fixture,
  an ubuntu job installs Playwright's browsers and runs the assertions
  against it. See `docs/superpowers/specs/2026-08-13-report-visual-test-coverage-design.md`
  for the full design and its layers.

CI runs `prepareTestResults.sh`, `swift test`, and the `visual/` job above, so
a green run of all of it locally means a green run on your pull request.

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
