#!/bin/bash
# Checks every credential the Release workflow needs, and prepares the ones
# that pass for the steps after it. Run by .github/workflows/release.yml on a
# macOS runner; docs/releasing.md says what each secret is and how to renew it.
#
# WHY THIS EXISTS: the workflow used to hand the certificate to a third-party
# import action and then ask codesign for an identity by name. When the
# certificate expired, the import still succeeded, and the first sign of
# trouble was codesign's "no identity found" -- which is also what a wrong
# password, a certificate exported without its private key, and a missing
# secret look like. This script tells those apart and names the secret.
#
# It never stops at the first problem. A dry run exists to find out what is
# wrong before a release is cut, and being told about one expired secret per
# run is a slow way to learn about three.
#
# Reads from the environment (each one a repository or environment secret):
#   BUILD_CERTIFICATE_BASE64  base64 of a .p12 holding the Developer ID
#                             Application certificate AND its private key
#   P12_PASSWORD              the password that .p12 was exported with
#   ASC_KEY_ID                App Store Connect API key id (Team key)
#   ASC_ISSUER_ID             App Store Connect API issuer id
#   ASC_PRIVATE_KEY           that key's .p8, base64-encoded or pasted as PEM
#
# Optional:
#   RUNNER_TEMP               where the keychain and key are written
#                             (default: a fresh temporary directory)
#   EXPIRY_WARNING_DAYS       warn when the certificate has fewer days left
#                             than this (default 45)
#   SKIP_NOTARY_ONLINE_CHECK  set to 1 to skip the one network call, the
#                             authenticated read that proves Apple accepts
#                             the API key (for running this off a runner)
#
# On success, writes to $GITHUB_OUTPUT (when set):
#   keychain    path of the temporary keychain holding the identity
#   identity    SHA-1 of the Developer ID Application identity to sign with
#   notary_key  path of the decoded .p8
#
# No `set -x` anywhere, and nothing here echoes a secret's value: a decoded
# .p8 is multi-line PEM, and GitHub's log masking works line by line on the
# exact stored value, so a re-encoded or partial copy would not be masked.
set -euo pipefail

WORK="${RUNNER_TEMP:-$(mktemp -d)}"
KEYCHAIN="$WORK/release-signing.keychain-db"
P12="$WORK/release-signing.p12"
NOTARY_KEY="$WORK/release-notary-key.p8"
WARN_DAYS="${EXPIRY_WARNING_DAYS:-45}"
# The system LibreSSL, by path. A Homebrew OpenSSL 3 earlier in PATH refuses
# some of what is asked of it here without extra flags, and which one a
# runner image puts first is not something to depend on.
OPENSSL=/usr/bin/openssl

problems=0
problem() {
    echo "::error title=Release credentials::$*"
    problems=$((problems + 1))
}
warning() { echo "::warning title=Release credentials::$*"; }
note() { echo "ok - $*"; }

is_set() { [ -n "${!1:-}" ]; }

# --- 1. Is every secret there at all? ---------------------------------------
# An unset secret reaches a workflow as an empty string, not as an error, so
# this has to be asked outright.
missing=()
for name in BUILD_CERTIFICATE_BASE64 P12_PASSWORD ASC_KEY_ID ASC_ISSUER_ID ASC_PRIVATE_KEY; do
    is_set "$name" || missing+=("$name")
done
if [ "${#missing[@]}" -gt 0 ]; then
    problem "not set: ${missing[*]}. Each is a secret this workflow reads; a run from a fork, or from a ref the release environment does not admit, sees them all as empty."
fi

# --- 2. The signing certificate ----------------------------------------------
identity=""
check_certificate() {
    if ! printf '%s' "$BUILD_CERTIFICATE_BASE64" | /usr/bin/base64 --decode > "$P12" 2>/dev/null \
        || [ ! -s "$P12" ]; then
        problem "BUILD_CERTIFICATE_BASE64 is not valid base64. It should be the output of: base64 -i DeveloperID.p12"
        return
    fi

    local keychain_password
    keychain_password="$($OPENSSL rand -hex 24)"
    security delete-keychain "$KEYCHAIN" >/dev/null 2>&1 || true
    security create-keychain -p "$keychain_password" "$KEYCHAIN"
    # No auto-lock on sleep or timeout shorter than the job could run.
    security set-keychain-settings -lut 21600 "$KEYCHAIN"
    security unlock-keychain -p "$keychain_password" "$KEYCHAIN"

    if ! security import "$P12" -k "$KEYCHAIN" -f pkcs12 -P "$P12_PASSWORD" \
        -T /usr/bin/codesign -T /usr/bin/security >/dev/null 2>&1; then
        problem "BUILD_CERTIFICATE_BASE64 could not be imported with P12_PASSWORD: the password does not match the .p12, or the secret is not a PKCS#12 export."
        return
    fi
    # Without `codesign:` in the partition list macOS answers codesign's use
    # of the key with a GUI prompt nobody is there to click, and the job hangs.
    security set-key-partition-list -S apple-tool:,apple:,codesign: \
        -s -k "$keychain_password" "$KEYCHAIN" >/dev/null 2>&1 || true
    # Appended to the search list, never replacing it: codesign builds the
    # chain to Apple's root from the keychains already there.
    local existing=()
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line#\"}"
        existing+=("${line%\"}")
    done < <(security list-keychains -d user)
    # (The ${x[@]+...} form is for the system bash 3.2, where expanding an
    # empty array under `set -u` is an error.)
    security list-keychains -d user -s "$KEYCHAIN" ${existing[@]+"${existing[@]}"}

    # Read the certificate itself rather than asking for a usable identity
    # first: an expired certificate is simply absent from `find-identity -v`,
    # which is how "expired" came to be reported as "not found".
    local pem_dir="$WORK/release-signing-certs" found=() cn pem
    rm -rf "$pem_dir"
    mkdir -p "$pem_dir"
    security find-certificate -a -p "$KEYCHAIN" \
        | awk -v dir="$pem_dir" '/-----BEGIN CERTIFICATE-----/ { n++ } { print > (dir "/" n ".pem") }'
    local developer_id=""
    for pem in "$pem_dir"/*.pem; do
        [ -f "$pem" ] || continue
        cn="$($OPENSSL x509 -in "$pem" -noout -subject -nameopt multiline 2>/dev/null \
            | sed -n 's/^ *commonName *= *//p')"
        found+=("${cn:-unnamed}")
        case "$cn" in
            "Developer ID Application:"*) developer_id="$pem" ;;
        esac
    done
    if [ -z "$developer_id" ]; then
        problem "BUILD_CERTIFICATE_BASE64 holds no Developer ID Application certificate. It holds: $(IFS=';'; echo "${found[*]:-nothing}"). A release is signed with a Developer ID Application certificate, not an Apple Development or Apple Distribution one."
        return
    fi

    local subject serial not_after
    subject="$($OPENSSL x509 -in "$developer_id" -noout -subject -nameopt multiline | sed -n 's/^ *commonName *= *//p')"
    serial="$($OPENSSL x509 -in "$developer_id" -noout -serial | sed 's/^serial=//')"
    not_after="$($OPENSSL x509 -in "$developer_id" -noout -enddate | sed 's/^notAfter=//')"
    if ! $OPENSSL x509 -in "$developer_id" -noout -checkend 0 >/dev/null; then
        problem "the certificate in BUILD_CERTIFICATE_BASE64 EXPIRED on ${not_after} (${subject}, serial ${serial}). Create a new Developer ID Application certificate and replace BUILD_CERTIFICATE_BASE64 and P12_PASSWORD: docs/releasing.md has the steps. Releases already published stay valid."
        return
    fi
    if ! $OPENSSL x509 -in "$developer_id" -noout -checkend "$((WARN_DAYS * 86400))" >/dev/null; then
        warning "the certificate in BUILD_CERTIFICATE_BASE64 expires on ${not_after}, in under ${WARN_DAYS} days (${subject}, serial ${serial}). Renew it before then: docs/releasing.md."
    fi

    identity="$(security find-identity -v -p codesigning "$KEYCHAIN" \
        | awk '/"Developer ID Application:/ { print $2; exit }')"
    if [ -z "$identity" ]; then
        # Without -v the listing includes identities macOS will not sign
        # with, and says why in a trailing parenthesis. No line at all means
        # there is a certificate but no private key to go with it.
        local unusable reason
        unusable="$(security find-identity -p codesigning "$KEYCHAIN" \
            | awk '/"Developer ID Application:/ { print; exit }')"
        if [ -z "$unusable" ]; then
            problem "BUILD_CERTIFICATE_BASE64 holds an unexpired Developer ID Application certificate (serial ${serial}) but not its private key, so it cannot sign. Export it again from the Mac that created it: Keychain Access > My Certificates, where the certificate has its key underneath it. docs/releasing.md has the steps."
        else
            reason="$(printf '%s' "$unusable" | sed -n 's/.*(\([A-Z_]*\))$/\1/p')"
            problem "BUILD_CERTIFICATE_BASE64 holds an unexpired Developer ID Application certificate (serial ${serial}) that macOS will not sign with: ${reason:-no reason given}. CSSMERR_TP_CERT_REVOKED means it was revoked and needs replacing; CSSMERR_TP_NOT_TRUSTED means the chain to Apple's root could not be built, which on a runner means Apple's Developer ID intermediate certificate is missing from the image."
        fi
        return
    fi
    note "signing certificate: ${subject}, serial ${serial}, valid until ${not_after}"
}
if is_set BUILD_CERTIFICATE_BASE64 && is_set P12_PASSWORD; then
    check_certificate
    # The keychain has what it needs; the .p12 has no reason to outlive this.
    rm -f "$P12"
    rm -rf "$WORK/release-signing-certs"
fi

# --- 3. The App Store Connect API key, which notarization authenticates with -
notary_ok=""
check_notary_key() {
    ( umask 077; : > "$NOTARY_KEY" )
    case "$ASC_PRIVATE_KEY" in
        *"-----BEGIN"*) printf '%s\n' "$ASC_PRIVATE_KEY" > "$NOTARY_KEY" ;;
        *)
            if ! printf '%s' "$ASC_PRIVATE_KEY" | /usr/bin/base64 --decode > "$NOTARY_KEY" 2>/dev/null; then
                problem "ASC_PRIVATE_KEY is neither a PEM private key nor valid base64. It should be the output of: base64 -i AuthKey_XXXXXXXXXX.p8"
                return
            fi
            ;;
    esac
    if ! $OPENSSL pkey -in "$NOTARY_KEY" -noout >/dev/null 2>&1; then
        problem "ASC_PRIVATE_KEY does not decode to a private key. It should be the .p8 file App Store Connect let you download once, base64-encoded."
        return
    fi
    if [ "${SKIP_NOTARY_ONLINE_CHECK:-}" = 1 ]; then
        note "App Store Connect API key parses; Apple was not asked about it (SKIP_NOTARY_ONLINE_CHECK)"
        notary_ok=1
        return
    fi
    # An authenticated read of the team's notarization history: it submits
    # nothing, and it fails exactly when a submission would fail to
    # authenticate. The listing itself is discarded.
    local answer
    if ! answer="$(xcrun notarytool history --key "$NOTARY_KEY" --key-id "$ASC_KEY_ID" \
        --issuer "$ASC_ISSUER_ID" --output-format json 2>&1)"; then
        problem "Apple's notary service rejected the App Store Connect API key (ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY): $(printf '%s' "$answer" | tr '\n' ' '). The three must belong to one Team key that is still active and has at least the Developer role; an Individual key cannot notarize. See docs/releasing.md."
        return
    fi
    note "App Store Connect API key: accepted by Apple's notary service"
    notary_ok=1
}
if is_set ASC_KEY_ID && is_set ASC_ISSUER_ID && is_set ASC_PRIVATE_KEY; then
    check_notary_key
fi

# --- Verdict -----------------------------------------------------------------
if [ "$problems" -gt 0 ]; then
    echo "error: $problems problem(s) with the release credentials, listed above. docs/releasing.md describes each secret and how to replace it." >&2
    exit 1
fi
# Unreachable with a problem count of zero unless the logic above is wrong;
# refuse to hand an empty identity to codesign, which would then sign ad hoc.
[ -n "$identity" ] && [ -n "$notary_ok" ] || { echo "error: internal: no problems recorded, but no identity or key either" >&2; exit 1; }

if [ -n "${GITHUB_OUTPUT:-}" ]; then
    {
        echo "keychain=$KEYCHAIN"
        echo "identity=$identity"
        echo "notary_key=$NOTARY_KEY"
    } >> "$GITHUB_OUTPUT"
fi
echo "ok - release credentials are usable"
