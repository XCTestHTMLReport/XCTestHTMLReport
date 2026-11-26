# A tag's shape reaches the package managers

The tag scheme is read by more than this repository's workflows. Each
consumer parses tags its own way, and moving from `X.Y.ZrcN` to
`vX.Y.Z-rc.N` (#473) changed what three of them do:

- **Mint** picks the highest tag `Version(tolerant:)` accepts, and that
  accepts pre-releases. `4.0.0rc1` was not semver, so Mint never saw it.
  `v4.0.0-rc.2` is, and it sorts above 3.0.0, so an unpinned
  `mint install` installs the candidate.
- **Homebrew's** `bump-formula-pr --version` builds the new `url` by
  replacing the old version string inside the old one. Going from
  `…/tags/3.0.0.tar.gz` to `4.0.0` gives a tag that does not exist, so the
  first v-prefixed final needs a formula bump made by hand.
- **reecetech/version-increment** reads only tags matching `^v?X.Y.Z$`, so
  it skips every pre-release, semver or not. That is why `bump_version`
  still does not run after a candidate.

**Before changing the tag shape, run each consumer's own parser over the new
tags.** Do not reason from "it's semver now".
