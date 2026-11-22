# Releasing

A release is cut by pushing a tag. [`.github/workflows/release.yml`](../.github/workflows/release.yml)
does the rest: it builds a universal `xchtmlreport`, signs it with a Developer
ID Application certificate, has Apple notarize it, attests where it was built,
and publishes it as a GitHub release.

Homebrew and Mint both build from the tag's source, so the archive attached to
the release is for people who download the binary directly. Homebrew picks a
new release up on its own (see [`homebrew-bump.yml`](../.github/workflows/homebrew-bump.yml)).

## Cutting a release

1. Run a [dry run](#dry-run) from `main` and see it pass. The credentials below
   expire on Apple's schedule, not this project's, and a dry run is how you find
   that out before the tag exists rather than after.
2. If the version deserves hand-written notes, add
   `docs/release-notes/X.Y.Z.md`. A release candidate and its final release
   share the one file. Without it the release carries GitHub's generated notes
   alone.
3. Tag the commit and push the tag:

   ```bash
   git tag 4.0.0        # or 4.0.0rc1 for a candidate
   git push origin 4.0.0
   ```

   Tags are `X.Y.Z` or `X.Y.ZrcN`, with no `v` prefix. An `rc` tag is published
   as a pre-release and never becomes "Latest".
4. After a final release the workflow opens a pull request bumping
   `Version.swift` to the next patch version. Major and minor bumps are made by
   hand before tagging.

A release is not re-runnable over a published tag: `gh release create` refuses,
on purpose, rather than swap binaries people have already downloaded.

## Dry run

*Actions → Release → Run workflow*, or:

```bash
gh workflow run release.yml --ref main
gh workflow run release.yml --ref main -f notarize=true
```

A manual run is always a dry run: it builds, signs and packages version
`0.0.0-dryrun` and publishes nothing, whatever its inputs. Only a tag push
publishes.

It has to be run from `main`. The job that signs belongs to the `release`
environment ([below](#secrets)), which admits `main` and release tags only, so
a run from any other branch is refused before its first step.

It starts by checking every credential and reports each problem as an
annotation on the run that names the secret at fault:

| The annotation says | What to do |
| --- | --- |
| `not set: …` | Add the named secrets to the `release` environment ([below](#secrets)). |
| `the certificate in BUILD_CERTIFICATE_BASE64 EXPIRED on …` | [Renew the certificate](#renewing-the-signing-certificate). |
| `… expires on …, in under 45 days` (a warning) | The same, before that date. |
| `could not be imported with P12_PASSWORD` | The two secrets are not a matching pair; set both again. |
| `holds no Developer ID Application certificate` | The `.p12` is an Apple Development or Distribution certificate. Export the right one. |
| `but not its private key` | Export from *My Certificates* on the Mac that created the certificate. |
| `Apple's notary service rejected the App Store Connect API key` | [Replace the key](#replacing-the-notarization-key). |

With `notarize=true` it also submits the dry-run build to Apple and checks the
resulting ticket. That is as far as a dry run goes: attesting and publishing
happen in a job that only a tag push runs, so the first real exercise of those
two is a release (a release candidate is a cheap one). Notarizing a build
nobody ships is harmless.

The build and its version check run even when a credential is bad, so one dry
run says whether the release build works *and* whether it can be signed.

## What a released binary carries

- **A Developer ID signature**, with the hardened runtime and a secure
  timestamp. The timestamp is why a release stays valid after the certificate
  that signed it expires.
- **Notarization.** A ticket cannot be stapled to a bare executable or a zip,
  so Gatekeeper looks it up online the first time the binary runs. The
  workflow asks Apple the same question before publishing.
- **A build provenance attestation**: a signed statement, kept by GitHub, that
  the archive came out of this workflow at the tag's commit.

Anyone can check all three on a download:

```bash
unzip xchtmlreport-4.0.0.zip
codesign --verify --strict -vv release/xchtmlreport
codesign --verify -R="notarized" --check-notarization -vv release/xchtmlreport
gh attestation verify xchtmlreport-4.0.0.zip --repo XCTestHTMLReport/XCTestHTMLReport
```

Releases before attestation was added (4.0.0rc1 and earlier) have none.

## Secrets

All five are secrets of the **`release` environment**, not of the repository:

| Secret | What it is |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | A `.p12` holding the Developer ID Application certificate **and its private key**, base64-encoded. |
| `P12_PASSWORD` | The password that `.p12` was exported with. |
| `ASC_KEY_ID` | The id of an App Store Connect API key (a *Team* key). |
| `ASC_ISSUER_ID` | The issuer id shown above the key list in App Store Connect. |
| `ASC_PRIVATE_KEY` | That key's `.p8` file, base64-encoded. |

Set one with `--env release`:

```bash
gh secret set NAME --env release -R XCTestHTMLReport/XCTestHTMLReport
```

The environment is what keeps them from a branch. A repository secret can be
read by a workflow run from any ref, so anyone with write access could push a
branch that edits the workflow and take the Developer ID key, or dispatch the
workflow from that branch and download a signed, notarized build of it. The
`release` environment's deployment rule admits the `main` branch and tags
matching `*.*.*`, and GitHub refuses the signing job for anything else.
`*.*.*` covers `4.1.0` and `4.1.0rc1`, and would cover a `v4.1.0` or
`v4.1.0-rc.1` scheme too; a scheme with fewer than two dots would need its own
rule added under *Settings → Environments → release*.

A repository-level secret of the same name is still read when the environment
has none, which defeats the point. Once the five are set in the environment,
delete the repository-level ones, along with the three that notarization used
before it moved to an API key (and revoke that app-specific password at
[account.apple.com](https://account.apple.com)):

```bash
gh secret delete BUILD_CERTIFICATE_BASE64 -R XCTestHTMLReport/XCTestHTMLReport
gh secret delete P12_PASSWORD -R XCTestHTMLReport/XCTestHTMLReport
gh secret delete AC_USERNAME -R XCTestHTMLReport/XCTestHTMLReport
gh secret delete AC_PASSWORD -R XCTestHTMLReport/XCTestHTMLReport
gh secret delete AC_TEAM_ID -R XCTestHTMLReport/XCTestHTMLReport
```

Without `--env`, `gh secret delete` removes the repository-level secret and
leaves the environment's alone.

### Renewing the signing certificate

A Developer ID Application certificate lasts five years, and only the
developer account's **Account Holder** can create one — an Admin cannot, and
neither can an App Store Connect API key
([Apple's role table](https://developer.apple.com/help/account/access/roles/)).
The quickest route keeps the private key on the Mac that makes the request:

1. Xcode → Settings → Accounts → select the team → *Manage Certificates…* →
   **+** → *Developer ID Application*.
   (Or by hand: [create a certificate signing request](https://developer.apple.com/help/account/certificates/create-a-certificate-signing-request),
   then [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/add)
   → *Developer ID Application*, and double-click the download.)
2. Keychain Access → *login* → *My Certificates* → right-click
   *Developer ID Application: …* → *Export…* → format *Personal Information
   Exchange (.p12)*, with a new password. It must be exported from *My
   Certificates*, where the certificate has its private key under it.
3. Store both, then delete the file:

   ```bash
   base64 -i DeveloperID.p12 | gh secret set BUILD_CERTIFICATE_BASE64 --env release -R XCTestHTMLReport/XCTestHTMLReport
   gh secret set P12_PASSWORD --env release -R XCTestHTMLReport/XCTestHTMLReport   # prompts
   rm DeveloperID.p12
   ```

4. Run a dry run from `main`.

Apple allows five Developer ID Application certificates at once, so a new one
does not disturb the old. Do not revoke an old Developer ID certificate to tidy
up: revoking, unlike expiring, invalidates everything it ever signed.

### Replacing the notarization key

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/integrations/api)
   → *Team Keys* → **+**. Give it the **Developer** role, which is the least
   that can notarize. It must be a Team key: an Individual key cannot use
   `notarytool`.
2. Download the `.p8`. Apple offers it once.
3. Store the three values, then delete the file. The secret is the only copy
   worth keeping; if it is ever lost, make a new key.

   ```bash
   base64 -i AuthKey_XXXXXXXXXX.p8 | gh secret set ASC_PRIVATE_KEY --env release -R XCTestHTMLReport/XCTestHTMLReport
   gh secret set ASC_KEY_ID --env release -R XCTestHTMLReport/XCTestHTMLReport      # the XXXXXXXXXX in the filename
   gh secret set ASC_ISSUER_ID --env release -R XCTestHTMLReport/XCTestHTMLReport   # the UUID above the key list
   rm AuthKey_XXXXXXXXXX.p8
   ```

4. Run a dry run from `main` with `notarize=true`, then revoke the key it
   replaces.

A key made for this repository alone can be revoked without touching anything
else that talks to App Store Connect, which is the reason not to reuse one.
