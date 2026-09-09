#!/bin/bash
# Artifact-Version: 2.0.1
# Release-Date: 2026-09-09
# Stability: Stable
# Change-Summary: Build the stable CLI from its consolidated source directory.
# SPDX-FileCopyrightText: 2026 igp76
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

SCRIPT_VERSION="2.0.1"
CLI_VERSION="2.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_ROOT="$PROJECT_ROOT/dist"
SOURCE_PATH="$SCRIPT_DIR/olk2mbox.py"
PACKAGE_PATH="$DIST_ROOT/OLK2MBOX-CLI-${CLI_VERSION}.py"
MANIFEST_PATH="$DIST_ROOT/OLK2MBOX-CLI-${CLI_VERSION}-release-manifest.json"
CHECKSUM_PATH="$DIST_ROOT/OLK2MBOX-CLI-${CLI_VERSION}-SHA256SUMS.txt"

usage() {
    echo "Usage: $0 [--version]"
    echo
    echo "Build the OLK2MBOX CLI ${CLI_VERSION} release inputs."
}

case "${1:-}" in
    "") ;;
    --version)
        echo "OLK2MBOX CLI release builder ${SCRIPT_VERSION} (CLI ${CLI_VERSION})"
        exit 0
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    *)
        echo "error: unknown option: $1" >&2
        usage >&2
        exit 2
        ;;
esac

[[ -f "$SOURCE_PATH" ]] || { echo "error: missing source: $SOURCE_PATH" >&2; exit 1; }
mkdir -p "$DIST_ROOT"
rm -f "$PACKAGE_PATH" "$MANIFEST_PATH" "$CHECKSUM_PATH"
rm -f "$PACKAGE_PATH.asc" "$MANIFEST_PATH.asc" "$CHECKSUM_PATH.asc"

install -m 0755 "$SOURCE_PATH" "$PACKAGE_PATH"

python3 -c 'import hashlib,json,sys; from pathlib import Path; package=Path(sys.argv[2]); Path(sys.argv[1]).write_text(json.dumps({"artifact":"OLK2MBOX CLI release","artifact_version":sys.argv[3],"release_date":"2026-09-09","stability":"Stable","change_summary":"Republish the current stable CLI from the consolidated clean-root source.","license":"GPL-3.0-or-later","corresponding_source":f"https://github.com/igp76/OLK2MBOX/tree/cli-v{sys.argv[3]}","runtime":"Python 3.10 or later","entry_point":package.name,"packages":[{"filename":package.name,"sha256":hashlib.sha256(package.read_bytes()).hexdigest()}],"openpgp_primary_fingerprint":"9A0D7C4D2286FB72B7FBBB71EF548834983D3094","openpgp_signing_subkey_fingerprint":"C8F51EAB8C7DB38C53DA8458927D2B68384F934C"},indent=2)+"\n",encoding="utf-8")' \
    "$MANIFEST_PATH" "$PACKAGE_PATH" "$CLI_VERSION"

{
    echo "# Artifact-Version: 2.0.0"
    echo "# Release-Date: 2026-09-09"
    echo "# Stability: Stable"
    echo "# Change-Summary: SHA-256 checksums for the republished clean-root OLK2MBOX CLI 2.0.0 release."
    echo "# SPDX-License-Identifier: GPL-3.0-or-later"
    shasum -a 256 "$PACKAGE_PATH" "$MANIFEST_PATH" | sed "s#  $DIST_ROOT/#  #"
} > "$CHECKSUM_PATH"

(cd "$DIST_ROOT" && shasum -a 256 -c "$(basename "$CHECKSUM_PATH")")

echo "CLI package: $PACKAGE_PATH"
echo "Release manifest: $MANIFEST_PATH"
echo "Checksums: $CHECKSUM_PATH"
