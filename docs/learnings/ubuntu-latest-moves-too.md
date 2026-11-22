# `ubuntu-latest` moves too

The Linux jobs were treated as the stable part of CI. They are not: when
`ubuntu-latest` became Ubuntu 26.04, the `visual` job (a required check)
failed on every pull request with no change under `visual/`:

```
Cannot install dependencies for ubuntu26.04-x64 with Playwright 1.56.1!
Error: ERROR: Playwright does not support chromium on ubuntu26.04-x64
```

Playwright carries a per-distribution dependency table, and 1.56.1 predated
26.04. #511 fixed it by moving to a Playwright that knows the image (1.65.1),
not by pinning `ubuntu-24.04`. Nothing watched `visual/package.json` at the
time, so Playwright had fallen nine minor releases behind; Renovate's `npm`
manager now covers it (#512).

**When a Linux job goes red with no diff, look at the image first.** The run
log's "Runner Image" section names it. A tool that ships per-OS binaries or
dependency lists is the likely casualty, and the fix is usually a bump of that
tool rather than a pinned image.
