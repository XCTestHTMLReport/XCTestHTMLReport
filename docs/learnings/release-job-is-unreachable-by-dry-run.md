# The release job cannot be exercised by the dry run

`release.yml` can be run by hand (`workflow_dispatch`) as a dry run: it builds,
signs and packages. It is the way to check the signing credentials before a tag.

On `main` today, the `Notarize` step and the `release` and `bump_version` jobs
are guarded on `github.event_name == 'push'`, so a dry run skips all three.
Anything only they touch is unverified until a real tag.

This nearly bit once: a dependency bump moved `upload-artifact` to v7 and left
`download-artifact` behind. The build job uploads the signed binary and the
release job downloads exactly that artifact, so the two must stay compatible,
and no dry run can catch a mismatch. Their majors are versioned independently
(v7 and v8 today), so check the pairing, not the numbers.

**When changing the release path, ask what the dry run does not reach.** Then
say so in the pull request. Cutting a release candidate tag is the owner's
call, never an agent's.
