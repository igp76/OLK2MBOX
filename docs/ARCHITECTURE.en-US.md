---
title: "Architecture — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Architecture

**English** · [Italiano](ARCHITECTURE.it-IT.md)

## Goal

OLK2MBOX converts a legacy Outlook for Mac 15 profile into a hierarchy of MBOX files without requiring Outlook or a commercial converter at runtime.

## Data flow

```text
Main Profile/
├── Data/Outlook.sqlite ──► folders, messages, relationships, and metadata
├── Data/Messages/      ──► OLK15 message properties
└── Data/Message Attachments/ ──► MIME blocks and original sources
                                  │
                                  ▼
                          parser and MIME rebuild
                                  │
                                  ▼
                         one .mbox file per folder
                         + OLK2MBOX-conversion-manifest.json
                         + execution/error logs
```

## Components

| Component | Responsibility |
|---|---|
| SQLite access | Opens `Outlook.sqlite` read-only and retrieves hierarchy, records, and owned blocks. |
| OLK15 parser | Decodes property collections, recipients, and `Attc`/`MSrc` blocks. |
| MIME rebuild | Preserves headers, text, HTML, inline resources, attachments, and attached emails. |
| MBOX writer | Protects `From ` lines and writes a `.partial` file before replacing the target atomically. |
| Manifest | Records version, statistics, source, and any errors. |

## Source layout

```text
app/                  SwiftUI application and Apple build tooling
cli/olk2mbox.py       canonical converter used by both products
cli/tests/            converter unit tests
docs/                 synchronized English and Italian documentation
third_party/          required third-party license texts
```

## Application architecture

```text
OLK2MBOX.app (arm64)
├── Contents/MacOS/OLK2MBOX      native SwiftUI interface
├── Contents/Helpers/olk2mbox   self-contained Python engine
└── Contents/Resources/OLK2MBOX-build-manifest.json
                                         build provenance (plus icon/localizations)
```

The app build packages `cli/olk2mbox.py` as its self-contained helper. The interface launches that helper as a child process, passes only the paths and options selected by the user, and streams combined standard output/error to both a selectable live view and a complete execution log. It parses message-count progress lines to drive the progress bar and time estimate. At termination, structured errors from the converter manifest are copied to the run-specific error log. The same source remains independently usable and testable as the CLI.

## Safety properties

- The source database is opened with `mode=ro` and `query_only`.
- Paths read from the database cannot escape the `Data` directory.
- No existing MBOX is replaced without `--overwrite`.
- Outlook profiles, email data, and generated exports are excluded from version control.

## Compatibility boundaries

Stable engine 2.0.0 supports the examined Outlook for Mac 15 profile-cache format. It does not directly parse `.olm` archives, calendars, contacts, or New Outlook profiles.

## Revision history

- Document revision 3.0.0 — 2026-09-09: document the consolidated source layout and canonical shared converter.
