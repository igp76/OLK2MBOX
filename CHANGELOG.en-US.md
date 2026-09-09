---
title: "Changelog — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Changelog

**English** · [Italiano](CHANGELOG.it-IT.md)

This project follows [Semantic Versioning](https://semver.org/). This clean-root repository intentionally records only the currently supported product generation.

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

- Revision 3.0.0 — 2026-09-09: establish the clean-root changelog for the consolidated current release.
