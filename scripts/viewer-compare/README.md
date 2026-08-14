# viewer-compare

Puts Xcode's own test-report viewer and this project's report side by side over
the same `.xcresult`, and leaves behind a run directory that a comparison can
still be written from months later.

The question it answers is *"what does Apple's viewer show that ours does not,
and where have we drifted from what an Xcode user expects to see?"* — which is
worth re-asking every time Xcode's report viewer changes, and impossible to
answer from memory.

## When to run it

- **Every new Xcode release, and every beta worth a look.** Apple reworks the
  report viewer without announcing it; the last rework moved the summary from a
  list to a card with a ring, and the report only caught up afterwards.
- Before shipping a change to the summary header, the test tree or the Logs
  tab, when the point of the change is to match or deliberately diverge from
  what Xcode does.

This is the **visual/UX** half of new-Xcode coverage. The **functional** half —
does the tool still parse what the new `xcresulttool` emits — is
[`.github/workflows/toolchain-drift.yml`](../../.github/workflows/toolchain-drift.yml),
which runs twice a week against `macos-latest` and against the current beta
image, and files a `drift` issue when the stable leg breaks. That one is
automated because it can be; this one is not, and should not be. Driving Xcode's
GUI on a hosted runner is a flake generator, and a red check nobody trusts is
worse than a tool the maintainer runs deliberately.

## Why this lives in `scripts/` and not in `visual/`

It borrows [`visual/`](../../visual)'s Playwright — the same pinned version, the
same browser build, no second lockfile — but it is not part of that suite.
`visual/` is assertions that run on every pull request, on Linux, headless, with
no Xcode anywhere. This is a macOS-only, GUI-driving, screenshot-producing tool
that runs when a human decides to run it. Folding it in would put `osascript`
and `screencapture` inside a directory whose whole contract is "this runs in
CI", and the first person to add a `playwright test` glob would pick it up.

## Prerequisites

- macOS with Xcode installed (verified against Xcode 26.2).
- `node` and `python3` on `PATH`. Nothing else to install: Playwright is
  borrowed from [`visual/`](../../visual), and the first run does its `npm ci`.
- Two permissions, both for **whatever program runs the script** — your terminal
  app, not Xcode — in System Settings → Privacy & Security:
  - **Accessibility**, to drive Xcode's UI.
  - **Screen Recording**, for `screencapture`.

  Without Accessibility the run stops immediately and says so. Without Screen
  Recording you get black or empty PNGs, which is the more confusing failure —
  check one Xcode shot before trusting a run.
- A fixture bundle. The default is the repository's own:

  ```sh
  ./prepareTestResults.sh        # boots a simulator, a few minutes
  ```

## Usage

```sh
scripts/viewer-compare/viewer_compare.sh
```

That builds the current checkout, renders the fixture, captures our side
headlessly, then hands the screen to Xcode for its side.

**The Xcode half takes over the machine.** It moves a window, changes the system
appearance, and types into whatever is frontmost. Do not use the keyboard while
it runs. It puts the appearance back when it finishes, including on Ctrl-C.

It deliberately closes nothing, so report windows accumulate across runs — one
per run, all showing a bundle with the same filename. That is handled (the
harness addresses windows by the bundle they show, and takes the frontmost
match), but you will want to close them yourself eventually. Do it by hand:
System Events intermittently reports an **empty name for project windows too**,
so a script that closes every untitled Xcode window will happily close the
project you had open.

Useful variations:

```sh
# A bundle from somewhere else — a user's attached .xcresult, say
scripts/viewer-compare/viewer_compare.sh --fixture ~/Downloads/Theirs.xcresult

# Just re-shoot our side after a CSS change
scripts/viewer-compare/viewer_compare.sh --skip-xcode

# Compare the two result readers by running it twice
scripts/viewer-compare/viewer_compare.sh --result-reader legacy
scripts/viewer-compare/viewer_compare.sh --result-reader modern

# Add Xcode's Tests view with the All Tests filter (prompts you to switch it)
scripts/viewer-compare/viewer_compare.sh --with-tests-all
```

Each piece also runs on its own — `capture_ours.mjs`, `capture_xcode.sh` and
`make_manifest.py` all take `--help` or documented environment variables, which
is how to iterate when only one side needs re-shooting.

## Output

A timestamped directory under `.viewer-compare/` (git-ignored):

```text
.viewer-compare/20260814T203000Z/
├── manifest.json            # the point of the run — see below
├── report/                  # the rendered report, plus a copy of the bundle
│   ├── index.html
│   └── TestResults.xcresult
├── ours-summary-1440-light.png       ours: 4 views x 3 viewports
├── ours-overview-1440-light.png
├── ours-tests-1440-light.png
├── ours-logs-1440-light.png
│   ... 1440 dark, 375 light
├── xcode-summary-1440-light.png      xcode: 3 views x 2 appearances
├── xcode-tests-1440-light.png
├── xcode-logs-1440-light.png
│   ... and dark
├── ours-shots.json          # what each side recorded about its own capture
└── xcode-shots.json
```

`manifest.json` is what makes a run worth keeping. It records the Xcode and
`xcresulttool` versions, the OS, the commit and whether the tree was dirty, the
fixture's size and test counts and when it was generated, the exact render
command, and an inventory of every shot with its view, viewport, appearance,
pixel dimensions, SHA-256, and whether a human drove it. A comparison page can
be regenerated from any run directory using nothing else.

A run over the repository fixture is about 64 MB, nearly all of it the bundle
copy — it scales with the bundle, not with the number of shots. Delete old ones.

## What is automated, and what is not

Automated: opening the bundle, waiting for the report to load, pinning the
window to exactly 1440×900 points, switching the system appearance, moving the
Report navigator between Summary / Tests / Log, and every screenshot.

Guided by numbered prompt:

- **Xcode's Tests-view status filter** (`--with-tests-all`). The filter is a
  pull-down whose items carry live counts — `All Tests (21)` — so matching them
  by name is a guess that changes with the fixture.
- **Anything that stops working.** A failed view switch degrades to a prompt
  rather than aborting, and `xcode-shots.json` records `automated: false` for
  the shots a human drove, so a half-automated run is still honest.

`--manual` puts every view switch behind a prompt, which is the fallback when a
new Xcode moves the accessibility tree far enough that nothing matches.

## When a new Xcode breaks the automation

Everything version-fragile is in `xcode_ui.applescript`, and the paths worth
knowing are:

- The report window is found by the **first row of its Report navigator**, which
  is the bundle's filename. A window opened straight onto an `.xcresult` has an
  empty title, so a title match finds nothing — and when a project is already
  open, the bundle's window sits next to one named after the project.
- The navigator outline is at
  `outline 1 of scroll area 1 of group 1 of <window>`.
- Views are switched by **arrow keys on the focused outline**, with Xcode
  frontmost. Setting the row's AX `selected` attribute highlights it but does
  not navigate, and a synthetic `click at {x, y}` does not land. This was true
  in Xcode 26.2; check it first if the shots all come out identical.

To re-derive the tree after an Xcode update:

```sh
osascript scripts/viewer-compare/xcode_ui.applescript rows 1
osascript -l JavaScript scripts/viewer-compare/xcode_windows.js
```
