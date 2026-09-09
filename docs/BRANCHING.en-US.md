---
title: "Branch strategy — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Branch strategy

**English** · [Italiano](BRANCHING.it-IT.md)

OLK2MBOX maintains the current macOS application and CLI together on the protected `main` branch. The application remains the primary product presented by the repository.

| Path | Product | Stable version | Distribution |
|---|---|---:|---|
| `app/` | Native macOS application for Apple Silicon | 2.0.0 | DMG, ZIP, source archives, and `app-v*` tags |
| `cli/` | Python command-line script | 2.0.0 | Signed script, source archives, and `cli-v*` tags |

## Maintenance rules

- CLI and app versions may advance independently while sharing one source tree.
- The application build embeds the converter from `cli/olk2mbox.py`, eliminating parser drift.
- Development uses short-lived branches and pull requests targeting `main`.
- Italian and English documentation twins remain synchronized.
- Compiled binaries are not stored in Git history; they are distributed as GitHub Actions artifacts or GitHub Releases.
- Both product lines are licensed under GPL-3.0-or-later and use signed release tags.

## Version conventions

- CLI: version in `cli/olk2mbox.py`, tag `cli-vMAJOR.MINOR.PATCH`.
- App: `CFBundleShortVersionString`, tag `app-vMAJOR.MINOR.PATCH`.
- Embedded engine: recorded separately in the app documentation and build manifest.

## Revision history

- Document revision 3.0.0 — 2026-09-09: consolidate the current app and CLI under the single protected `main` branch.
