#!/bin/bash
# Artifact-Version: 2.0.1
# Release-Date: 2026-09-09
# Stability: Stable
# Change-Summary: Support the consolidated CLI source directory.
# SPDX-FileCopyrightText: 2026 igp76
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SCRIPT_VERSION="2.0.1"
CLI_VERSION="2.0.0"
PRIMARY_FINGERPRINT="9A0D7C4D2286FB72B7FBBB71EF548834983D3094"
SIGNING_SUBKEY_FINGERPRINT="C8F51EAB8C7DB38C53DA8458927D2B68384F934C"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_ROOT="$PROJECT_ROOT/dist"
VERIFY_ONLY=false

FILES=(
    "$DIST_ROOT/OLK2MBOX-CLI-${CLI_VERSION}.py"
    "$DIST_ROOT/OLK2MBOX-CLI-${CLI_VERSION}-release-manifest.json"
    "$DIST_ROOT/OLK2MBOX-CLI-${CLI_VERSION}-SHA256SUMS.txt"
)

usage() {
    echo "Usage: $0 [--verify-only] [--version]"
    echo
    echo "Create or verify detached OpenPGP signatures for OLK2MBOX CLI ${CLI_VERSION}."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify-only) VERIFY_ONLY=true; shift ;;
        --version)
            echo "OLK2MBOX CLI release signer ${SCRIPT_VERSION} (CLI ${CLI_VERSION})"
            exit 0
            ;;
        --help|-h) usage; exit 0 ;;
        *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

command -v gpg >/dev/null || { echo "error: gpg is required" >&2; exit 1; }
for release_file in "${FILES[@]}"; do
    [[ -f "$release_file" ]] || { echo "error: missing release file: $release_file" >&2; exit 1; }
done

KEY_DETAILS="$(gpg --batch --with-colons --list-secret-keys "$PRIMARY_FINGERPRINT")"
[[ "$KEY_DETAILS" == *"$PRIMARY_FINGERPRINT"* ]] || {
    echo "error: required primary secret key is unavailable: $PRIMARY_FINGERPRINT" >&2
    exit 1
}
[[ "$KEY_DETAILS" == *"$SIGNING_SUBKEY_FINGERPRINT"* ]] || {
    echo "error: required signing subkey is unavailable: $SIGNING_SUBKEY_FINGERPRINT" >&2
    exit 1
}

(cd "$DIST_ROOT" && shasum -a 256 -c "OLK2MBOX-CLI-${CLI_VERSION}-SHA256SUMS.txt")

for release_file in "${FILES[@]}"; do
    signature_file="${release_file}.asc"
    if [[ "$VERIFY_ONLY" == false ]]; then
        gpg --batch --yes --armor --detach-sign \
            --local-user "${SIGNING_SUBKEY_FINGERPRINT}!" \
            --output "$signature_file" \
            "$release_file"
    fi
    [[ -f "$signature_file" ]] || { echo "error: missing signature: $signature_file" >&2; exit 1; }
    gpg --batch --verify "$signature_file" "$release_file"
done

echo "All OLK2MBOX CLI release checksums and OpenPGP signatures are valid."
