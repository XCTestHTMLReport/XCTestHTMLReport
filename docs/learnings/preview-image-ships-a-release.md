# A "beta" runner image can hold the shipping Xcode

GitHub's `xcode-<N>` images are previews, and `toolchain-drift.yml` filed
everything from them under `drift-beta` as advance notice, deciding from the
runner label alone. When Xcode 27.1 (build `27A9275`, no beta suffix) reached
the `xcode-27` image, it was a release, the tool exited 3 on bundles it wrote,
and 49 assertions failed. The scheduled run stayed green and #478 collected
comments calling it "advance notice, not a regression" (#515).

Nothing on the image says when its Xcode stops being a beta, and build numbers
do not either: the image lists the released Xcode 27.0 as `27A266a`.

What #515 changed, so the label is never the answer again:

- The drift workflow reads `licenseType` from the running Xcode's
  `LicenseInfo.plist`. `GM` files under `drift` and fails its leg; anything
  else stays `beta`.
- `test.yml` runs pull requests on the newest preview image whose *default
  Xcode is a release*, found by `.github/actions/discover-preview-runner`
  with `require: release` from the image manifest. A beta never shows a pull
  request a red leg.

**Ask the Xcode, not the label.** When a preview leg fails, check
`Record toolchain` in its log for the license type before calling it a beta.
