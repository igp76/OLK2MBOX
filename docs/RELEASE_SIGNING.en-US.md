---
title: "Release signing and verification — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Release signing and verification

**English** · [Italiano](RELEASE_SIGNING.it-IT.md)

## Trust identity

Production Git commits, annotated release tags, packages, manifests, and checksum files use this OpenPGP identity:

| Field | Value |
|---|---|
| Identity | `igp76 <90463101+igp76@users.noreply.github.com>` |
| Primary fingerprint | `9A0D7C4D2286FB72B7FBBB71EF548834983D3094` |
| Signing subkey fingerprint | `C8F51EAB8C7DB38C53DA8458927D2B68384F934C` |
| Expiration date | 2030-12-01 |

Never accept a shortened key ID as equivalent to the full fingerprint.

## Signed release set

Release `app-v2.0.0` contains these four inputs and their ASCII-armored detached `.asc` signatures:

- `OLK2MBOX-2.0.0-arm64.zip`
- `OLK2MBOX-2.0.0-arm64.dmg`
- `OLK2MBOX-2.0.0-release-manifest.json`
- `OLK2MBOX-2.0.0-SHA256SUMS.txt`

The annotated Git tag is signed separately. The manifest identifies the versions, architecture, Apple distribution status, expected OpenPGP fingerprints, and package digests.

Release `cli-v2.0.0` contains the standalone `OLK2MBOX-CLI-2.0.0.py`, its release manifest and checksum file, each accompanied by a detached `.asc` signature. Both signed tags identify the same consolidated source tree while preserving product-specific release assets.

## Verify downloaded files

Import the public key through a trusted channel, confirm its complete primary fingerprint, place all release files in one directory, and run:

```bash
gpg --fingerprint 9A0D7C4D2286FB72B7FBBB71EF548834983D3094
gpg --verify OLK2MBOX-2.0.0-arm64.zip.asc OLK2MBOX-2.0.0-arm64.zip
gpg --verify OLK2MBOX-2.0.0-arm64.dmg.asc OLK2MBOX-2.0.0-arm64.dmg
gpg --verify OLK2MBOX-2.0.0-release-manifest.json.asc OLK2MBOX-2.0.0-release-manifest.json
gpg --verify OLK2MBOX-2.0.0-SHA256SUMS.txt.asc OLK2MBOX-2.0.0-SHA256SUMS.txt
shasum -a 256 -c OLK2MBOX-2.0.0-SHA256SUMS.txt
```

Every OpenPGP result must report a good signature from the identity above, using signing subkey `C8F51EAB8C7DB38C53DA8458927D2B68384F934C`; every checksum must report `OK`.

Verify the signed tag in a cloned repository:

```bash
git tag -v app-v2.0.0
git log --show-signature -1 app-v2.0.0
```

## Maintainer workflow

Build the complete release input set, then sign it only on the authorized local system that holds the private key:

```bash
./app/build_olk2mbox.sh
./app/sign_olk2mbox_release.sh
./app/sign_olk2mbox_release.sh --verify-only
./cli/build_olk2mbox_cli_release.sh
./cli/sign_olk2mbox_cli_release.sh
./cli/sign_olk2mbox_cli_release.sh --verify-only
```

The cloud workflow intentionally produces unsigned inputs and never receives the private key.

## Apple distribution status

> [!WARNING]
> Release 2.0.0 is Apple ad-hoc signed and is not notarized. OpenPGP verifies project provenance and file integrity; it does not replace Apple Developer ID signing, hardened runtime, or notarization and does not guarantee Gatekeeper acceptance.

An official Apple distribution release will require an authorized Developer ID Application identity and notarization credentials in addition to the OpenPGP process documented here.

## Revision history

- Document revision 3.0.0 — 2026-09-09: cover both current releases from the consolidated signed source root.
