---
title: "Security policy — OLK2MBOX"
document_revision: "2.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Security policy

**English** · [Italiano](SECURITY.it-IT.md)

## Supported versions

Security fixes target the current stable `2.x` app and CLI releases from the consolidated `main` branch. No historical binary releases are distributed by this clean-root repository.

## Reporting a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/igp76/OLK2MBOX/security/advisories/new). Do not disclose an unresolved vulnerability in a public issue.

Include the affected version, operating system or Python version, reproducible steps, impact, and any proposed mitigation. Never attach real Outlook profiles, messages, credentials, personal paths, or other private data. Use synthetic samples only.

## Supply-chain policy

Production commits and release tags are OpenPGP signed. Release packages, manifests, and checksums carry verified detached signatures. GitHub Actions are restricted to GitHub-owned actions pinned to full commit identifiers, workflow tokens are read-only, Python build dependencies are pinned to exact versions and SHA-256 hashes, and extended CodeQL analysis covers Actions, Python, and manually built Swift.

The macOS package remains Apple ad-hoc signed and not notarized until authorized Developer ID credentials are available.

## Revision history

- Document revision 2.0.0 — 2026-09-09: align supported versions and controls with the consolidated clean-root repository.
