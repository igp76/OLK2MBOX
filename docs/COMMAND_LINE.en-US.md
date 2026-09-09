---
title: "Command-line converter — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Command-line converter

**English** · [Italiano](COMMAND_LINE.it-IT.md)

`cli/olk2mbox.py` 2.0.0 is the stable, standalone command-line edition of OLK2MBOX. It converts legacy Outlook for Mac 15 profiles into standard MBOX files using only Python’s standard library. The application and CLI are maintained together on `main`, and the app build embeds this same converter source.

The source profile is opened read-only. The converter is independent and does not modify or bypass commercial license controls.

## Requirements

- Python 3.10 or later.
- A legacy Outlook profile containing `Data/Outlook.sqlite`.
- Sufficient free space: allow at least 15% more than the message-size estimate.
- Outlook must be closed when converting an active profile; working from a copy is preferable.

The examined profile format contains `.olk15Message` and `.olk15MsgAttachment` files. This version does not directly convert `.olm` archives, New Outlook profiles, calendars, or contacts.

## Quick start

```bash
chmod +x cli/olk2mbox.py
./cli/olk2mbox.py --version
```

List folders and counts without writing output:

```bash
./cli/olk2mbox.py "/path/to/Main Profile" "/path/to/output" --list-folders
```

Preview a complete conversion:

```bash
./cli/olk2mbox.py "/path/to/Main Profile" "/path/to/output" --dry-run
```

Convert the entire profile:

```bash
./cli/olk2mbox.py "/path/to/Main Profile" "/path/to/output"
```

Convert one folder, for example folder ID `110`:

```bash
./cli/olk2mbox.py "/path/to/Main Profile" "/path/to/output" --folder-id 110
```

## Important options

- `--folder-id ID`: convert only the selected folder; may be repeated.
- `--limit N`: cap the total message count for a test.
- `--no-attachments`: omit attachments and embedded inline resources.
- `--exclude-hidden`: omit messages marked hidden.
- `--exclude-deleted`: omit messages marked for deletion.
- `--on-error skip`: continue after a damaged record and report it in the manifest.
- `--overwrite`: atomically replace destination MBOX files that already exist.
- `--progress-every N`: change the progress-reporting interval.
- `--quiet`: disable progress reporting.

Without `--overwrite`, an existing MBOX is never modified. The writer uses a `.partial` file and publishes the final MBOX only after completion and disk synchronization.

## Output

```text
output/
├── OLK2MBOX-conversion-manifest.json
└── Main Profile/
    ├── Exchange Account 101/
    │   └── Inbox.mbox
    └── On My Computer/
        └── Archive/
            └── 2026.mbox
```

The manifest records converter version, statistics, source, and errors. Messages include `X-Outlook-*` traceability headers. Available original headers, plain-text/HTML bodies, identifiers, folder structure, inline resources, and MIME attachments are preserved.

MIME is reconstructed and may not be byte-for-byte identical to the received message. Existing DKIM or S/MIME signatures might no longer verify. Partially downloaded messages contain the available data and an `X-Outlook-Partially-Downloaded` marker.

## Verification

```bash
python3 -m unittest discover -s cli/tests -v
```

The supplied profile validation recognized 136,709 messages in 38 non-empty folders. The Inbox sample preserved 18 attachment payloads across 5 messages; the `01Keep` sample preserved all 210 attachment blocks across 204 messages, without skipped messages or MIME parsing defects.

## License

The converter is copyright © 2026 igp76 and licensed under GNU GPL version 3 or later. See [`LICENSE`](../LICENSE), [`COPYING`](../COPYING), and the [licensing guide](LICENSING.en-US.md).

## Revision history

- Document revision 3.0.0 — 2026-09-09: document the canonical CLI source in the consolidated clean-root repository.
