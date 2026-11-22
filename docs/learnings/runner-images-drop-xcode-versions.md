# Runner images drop old Xcode versions

`macos-latest` moved to `macos-26`, which ships only Xcode 26.x. Two workflows
pinned versions that no longer existed and failed with
`Could not find Xcode version that satisfied version spec`: `ci.yml` pinned
`15` and `release.yml` pinned `^16`. Neither had run in months, so neither
failure showed until CI was restarted.

**Do not assume a pinned Xcode is still on the image.** A leg that needs an
older toolchain pins the *image* as well as the Xcode. `ci.yml` and
`xcresult-schema-probe.yml` do: `macos-latest` with `latest-stable` for the
newest, `macos-15` with `16` for one major back. That pairing is the support
policy, which is why `renovate.json` deliberately leaves it alone.

Check `actions/runner-images` for what an image contains before pinning to it.
The other direction bites too: see
[ubuntu-latest-moves-too.md](ubuntu-latest-moves-too.md) and
[preview-image-ships-a-release.md](preview-image-ships-a-release.md).
