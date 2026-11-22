# The release job cannot be exercised by the dry run

A manual run of `release.yml` is always a dry run (`docs/releasing.md`). A
secret-free `build` job builds and uploads the unsigned binary as `unsigned`.
A separate `sign` job, in the `release` environment, downloads it, checks its
SHA-256 against the build's output, signs it, and uploads the archive as
`application`. With `-f notarize=true` it also notarizes and checks the
ticket. `sign` runs only from `main` or a release tag; GitHub refuses it on any
other ref before its first step.

The `release` and `bump_version` jobs, which attest, publish and bump, run on
a tag push only. Anything only they touch is unverified until a real tag.

That includes the second artifact hand-off. `release` downloads exactly the
`application` archive that `sign` uploaded, as `sign` downloads what `build`
uploaded, so `upload-artifact` and `download-artifact` must stay compatible.
The dry run exercises the first hand-off but not the second. Their majors are
versioned independently (v7 and v8 today), so check the pairing, not the
numbers. A dependency bump once moved one and not the other; it was caught by
reading `release.yml`.

**When changing the release path, ask what the dry run does not reach,** and
say so in the pull request. Cutting a release candidate tag is the owner's
call, never an agent's.
