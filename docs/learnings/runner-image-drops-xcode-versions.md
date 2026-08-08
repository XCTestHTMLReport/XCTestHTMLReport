# `macos-latest` silently drops old Xcode versions

`macos-latest` moved to `macos-26`, which ships only Xcode 26.x. Two workflows
had pinned versions that no longer existed and failed with
`Could not find Xcode version that satisfied version spec`.

`ci.yml` pinned `15`; `release.yml` pinned `^16`. Neither had run in months, so
neither failure was visible until CI was restarted.

**Do not assume a pinned Xcode still exists on the runner.** `macos-15` still
carries 16.x, so a leg that needs an older toolchain must pin the *image* too,
not just the Xcode version. `ci.yml` does this: `macos-latest` + `latest-stable`
for the newest, `macos-15` + `16` for one major back.

Check `actions/runner-images` for what an image actually contains before pinning.
