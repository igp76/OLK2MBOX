---
title: "Changelog — OLK2MBOX"
document_revision: "3.1.0"
revision_date: "2026-11-10"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Changelog

**English** · [Italiano](CHANGELOG.it-IT.md)

This project follows [Semantic Versioning](https://semver.org/). This clean-root repository intentionally records only the currently supported product generation.

## Unreleased — Build and security maintenance

- Update setuptools to 84.2.1, addressing GHSA-xmj3-9gf7-h52w, and update PyInstaller to 6.22.3 and its contributed hooks to 2026.9 while retaining exact versions and package hashes.
- Read the required PyInstaller version from the build requirements to prevent mismatches between installation and compilation.
- Update both CodeQL actions to 4.39.3 together, move Swift analysis to macOS 15, and group future CodeQL updates in Dependabot.
- Update setup-python to 7.1.0 and upload-artifact to 7.0.2, preserving full commit pins.
- These maintenance changes do not replace the published App 2.0.0 or CLI 2.0.0 release assets.

## App 2.0.0 / CLI 2.0.0 — Stable

### Application

- Native, bilingual SwiftUI interface for Apple Silicon and macOS 13 or later.
- Self-contained converter and Python runtime; Outlook and Python are not required on the destination Mac.
- Determinate conversion progress, elapsed and estimated remaining time, selectable live output, and four log-detail levels.
- Timestamped execution and error logs, atomic MBOX publication, and configurable recovery options.
- Apple ad-hoc code signature; Apple notarization has not been performed.

### Converter

- Read-only conversion of legacy Outlook for Mac 15 profile caches to standard MBOX.
- Preservation of folder hierarchy, available headers, text/HTML bodies, inline resources, and MIME attachments.
- Standalone Python 3.10+ operation using only the standard library.
- JSON conversion manifest, dry-run and folder-selection modes, filtering, atomic writes, and configurable error handling.

### Repository and supply chain

- Consolidated application and CLI sources on the single protected `main` branch.
- Application builds embed the canonical converter from `cli/olk2mbox.py`.
- Compiled packages are distributed only through the current `app-v2.0.0` and `cli-v2.0.0` releases.
- Production commits, annotated tags, packages, manifests, and checksums use verified OpenPGP signatures.
- GitHub Actions are pinned to immutable commit identifiers, build dependencies use exact hashes, and CodeQL covers Actions, Python, and Swift.
- Original project code and documentation are licensed under GPL-3.0-or-later.

## Document revision

- Revision 3.1.0 — 2026-11-10: document unreleased dependency, build, and security workflow maintenance.
- Revision 3.0.0 — 2026-09-09: establish the clean-root changelog for the consolidated current release.
