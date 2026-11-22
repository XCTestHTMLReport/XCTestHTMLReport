# Contributing Guidelines

This document contains information and guidelines about contributing to this project.
Please read it before you start participating.

**Topics**

* [Reporting Issues](#reporting-issues)
* [Submitting Pull Requests](#submitting-pull-requests)
* [AI-assisted contributions](#ai-assisted-contributions)

## Reporting Issues

A great way to contribute to the project
is to send a detailed issue when you encounter an problem.
I always appreciate a well-written, thorough bug report.

Check that the project issues database
doesn't already include that problem or suggestion before submitting an issue.

When reporting issues, please include the following:

* The version of Xcode you're using
* The output of `xchtmlreport --version`
* The full output of the command
* An archive of the resultBundlePath (Whenever possible)
* Any other details that would be useful in understanding the problem

This information will help  review and fix your issue faster.

[Create an issue](https://github.com/XCTestHTMLReport/XCTestHTMLReport/issues/new/choose)

## Submitting Pull Requests

Pull requests are welcome, and greatly encouraged. When submitting a pull request, please add a description that explains what the changes are about. Link the ticket whenever possible.

* As usual, anyone can clone the repository. Then do the fixes/improvements as needed in own repository. When it is finished you can start the request to pull code from your own repo to XCTestHTMLReport repo. 

If you want to take an open issue, comment on it first and I will assign it to
you. That costs you one line and guarantees your work gets read.

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
confusing error. A host-app launch failure does something subtler: the bundle is
full of tests, just not the ones hosted in the app.
`scripts/verify_fixtures.sh` — the same gate CI runs — catches both in a second:

```bash
./scripts/verify_fixtures.sh   # asserts each bundle holds its expected test count
```

It knows the shape of each fixture (21, 1 and 4 tests for the three healthy
ones), so a bundle that generated partially is rejected by name and count
rather than waved through. Adding or removing sample-app tests moves those
numbers: update the table at the top of the script in the same commit.

The fourth bundle, `CrashResults.xcresult`, is a broken run on purpose: the
script sets `XCHR_TRAP_AT_LAUNCH`, the sample app traps in
`didFinishLaunchingWithOptions`, and `SampleAppUnitTests` — hosted in that app
— dies with it. `SystemFailureCanaryTests` reads it to check that Apple still
calls the resulting group `System Failures`, which is the only handle the
`systemFailure` fault has. Expect one failing `xcodebuild` invocation during
generation; that is the fixture being made, not a problem.

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
  npx playwright install chromium   # on Linux, add --with-deps as CI does
  npx playwright test
  ```

  CI runs this as two jobs, mirrored above: a macOS job dumps the fixture,
  an ubuntu job installs Playwright's browsers and runs the assertions
  against it. See `docs/superpowers/specs/2026-08-13-report-visual-test-coverage-design.md`
  for the full design and its layers.

CI runs `prepareTestResults.sh`, `swift test`, and the `visual/` job above, so
a green run of all of it locally means a green run on your pull request.

### Optional: run the checks before committing

CI runs shellcheck, actionlint, SwiftFormat, and SwiftLint. The same checks can run
locally on staged files, so you find problems before pushing.

[mise](https://mise.jdx.dev) installs the versions pinned in `mise.toml` — the
same ones CI uses, so a linter release cannot fail your pull request on a file
you did not touch — and, as a side effect, the pre-commit hook itself:

```bash
brew install mise            # or https://mise.jdx.dev/installing-mise.html
mise trust && mise install
```

That is opt-in on purpose: nothing installs it for you, and `mise trust` is where
you agree to let the repository run its own setup.

The same file indexes the repository's runnable scripts: `mise tasks` lists
them (fixture generation and both comparison harnesses), and
`mise run <task> -- <flags>` runs one with its flags passed through.

The hook is defined in [`hk.pkl`](hk.pkl). It only checks files you are actually
committing, and reports problems rather than rewriting your files, so a commit
never contains changes you have not read. To skip it for one commit:

```bash
git commit --no-verify
```

If you set up the older `.githooks` directory, it is gone now, and the
`core.hooksPath` it left behind will stop the new hook from firing. Clear it
once:

```bash
git config --local --unset-all core.hooksPath
```

### Dependency updates

[Renovate](https://docs.renovatebot.com) proposes version bumps, so there is no
need to send one by hand. It runs weekly and covers the Swift packages, the
GitHub Actions pins, the tools in `mise.toml` and `hk.pkl`, and the npm packages
under `visual/`. Its Dependency Dashboard issue lists what is pending.
[`renovate.json`](renovate.json) says what it watches and what it deliberately
leaves alone. After editing that file, check it:

```bash
npx --yes --package renovate -- renovate-config-validator --strict
```

## AI-assisted contributions

Using an AI assistant to write a patch is fine. Much of this project's recent
work was written that way. What is not fine is submitting code you have not
read, have not run, or cannot explain.

If you used an assistant, say so in the pull request description. One line is
enough: which tool, and what it did.

Every pull request, however it was written, clears the same bar:

* You ran `./prepareTestResults.sh && swift test` and the suite passes.
* You read every line of the diff and can answer questions about it.
* The change addresses a problem you actually have, or an issue you asked for.

Pull requests that look like automated volume submissions are closed without
review. The signals are opening against issues you have no stake in, describing
verification you did not perform, and doing the same thing across many unrelated
repositories on the same day.

This is not a judgment about machine-written code. Reviewing a patch costs more
than generating one, and a maintainer's review time is the scarce resource here.
A patch nobody asked for spends that resource without consent, and it does so
whether or not the code is any good.
