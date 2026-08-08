# The release job cannot be exercised by the dry run

`release.yml` has a `workflow_dispatch` dry run that builds, signs and packages
without notarizing or publishing. It is genuinely useful — it caught that the
signing certificate was still valid before 3.0 was tagged.

But the `release` and `bump_version` jobs are guarded on
`github.event_name == 'push'`, so a dry run **skips them entirely**. Anything
that only those jobs touch is unverified until a real tag.

This nearly bit once: a Dependabot PR bumped `upload-artifact` 4→7 and left
`download-artifact` at v4. They are a matched pair — the build job uploads the
signed binary and the release job downloads exactly that artifact — and no dry
run could have caught the mismatch. It was spotted by reading `release.yml`
directly, before the PR merged.

**When changing anything in the release path, ask what the dry run does not
reach.** Prefer cutting an `rc` tag, which is treated as a prerelease and does
not reach Homebrew.
