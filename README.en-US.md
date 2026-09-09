---
title: "OLK2MBOX for macOS"
document_revision: "4.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# OLK2MBOX for macOS

**English** · [Italiano](README.it-IT.md)

![App](https://img.shields.io/badge/macOS_app-2.0.0_stable-34C759?logo=apple)
![Engine](https://img.shields.io/badge/converter-2.0.0-blue)
![Platform](https://img.shields.io/badge/Apple_Silicon-arm64-black?logo=apple)
![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)

OLK2MBOX is a native, self-contained macOS application that converts legacy Outlook for Mac 15 profiles into standard MBOX files. It preserves the original folder hierarchy, messages, available headers, HTML/plain-text bodies, inline resources, and attachments without requiring Outlook or a separate Python installation.

> [!IMPORTANT]
> Never add Outlook profiles, databases, messages, attachments, logs, or MBOX exports to this repository. Conversion is local and the source profile is opened read-only.

## Download

Download the stable Apple Silicon release from [OLK2MBOX 2.0.0](https://github.com/igp76/OLK2MBOX/releases/tag/app-v2.0.0). The release provides:

- a drag-to-`Applications` DMG;
- a ZIP containing `OLK2MBOX.app`;
- a release manifest and SHA-256 checksums;
- detached OpenPGP signatures for every release input;
- source `.zip` and `.tar.gz` archives generated from the signed tag.

Requirements: Apple Silicon Mac (`arm64`) running macOS 13 Ventura or later.

The standalone Python edition is available from [OLK2MBOX CLI 2.0.0](https://github.com/igp76/OLK2MBOX/releases/tag/cli-v2.0.0).

> [!WARNING]
> The current application is Apple ad-hoc signed and is not notarized. OpenPGP verifies project provenance and package integrity but does not replace Developer ID signing or Apple notarization.

## Using the application

1. Open the DMG and drag `OLK2MBOX.app` to `Applications`.
2. Select the legacy Outlook `Main Profile` folder, or its `Data` folder.
3. Select a destination with enough free space.
4. Choose attachment, filtering, error-handling, overwrite, and log-detail options.
5. Start the conversion and monitor the progress bar, elapsed time, and estimated remaining time.

The live log is scrollable, selectable, and copyable. Disable `Follow latest output` to inspect earlier lines, or use `Jump to latest` to return to the end.

Each run writes two timestamped files beside the generated MBOX hierarchy:

- `OLK2MBOX-YYYYMMDD-HHmmss-execution.log` — complete engine output and run metadata;
- `OLK2MBOX-YYYYMMDD-HHmmss-errors.log` — structured conversion errors, or an explicit clean-run result.

Log detail ranges from concise updates every 1,000 messages to extreme output for every processed message. The on-screen tail is bounded for responsiveness; the disk log remains complete.

## Output

```text
destination/
├── OLK2MBOX-YYYYMMDD-HHmmss-execution.log
├── OLK2MBOX-YYYYMMDD-HHmmss-errors.log
├── OLK2MBOX-conversion-manifest.json
└── Main Profile/
    ├── Exchange Account 101/
    │   └── Inbox.mbox
    └── On My Computer/
        └── Archive.mbox
```

Existing MBOX files are not replaced unless `Replace existing MBOX files` is selected. The converter writes `.partial` files and publishes final MBOX files atomically.

MBOX filenames intentionally retain the source Outlook folder names so that the recovered mailbox hierarchy remains recognizable; they are data outputs, not product binaries.

## Documentation

- [Apple Silicon application guide](docs/APPLE_SILICON_APP.en-US.md)
- [Command-line converter](docs/COMMAND_LINE.en-US.md)
- [Architecture](docs/ARCHITECTURE.en-US.md)
- [Branch strategy](docs/BRANCHING.en-US.md)
- [Licensing](docs/LICENSING.en-US.md)
- [Third-party notices](docs/THIRD_PARTY_NOTICES.en-US.md)
- [Release signature verification](docs/RELEASE_SIGNING.en-US.md)
- [Security policy](.github/SECURITY.en-US.md)
- [Changelog](CHANGELOG.en-US.md)

## Repository layout

| Path | Product | Stable version |
|---|---|---:|
| `app/` | Native self-contained macOS application | 2.0.0 |
| `cli/` | Standalone Python command-line converter | 2.0.0 |
| `docs/` | Shared bilingual documentation | 4.0.0 |

Both products are maintained together on the protected `main` branch. Short-lived branches are used only for reviewed development work. Compiled packages are published as release assets and are not committed to Git history.

## Build from source

```bash
python3 -m unittest discover -s cli/tests -v
./app/build_olk2mbox.sh
./cli/build_olk2mbox_cli_release.sh
```

The build produces the application, ZIP, DMG, release manifest, and checksum file in `dist/`. Release signing is performed only in the authorized local environment:

```bash
./app/sign_olk2mbox_release.sh
./app/sign_olk2mbox_release.sh --verify-only
./cli/sign_olk2mbox_cli_release.sh
./cli/sign_olk2mbox_cli_release.sh --verify-only
```

## License and independence

Copyright © 2026 igp76. OLK2MBOX is licensed under the [GNU General Public License, version 3 or later](LICENSE). Complete corresponding source is supplied with every binary release. Third-party components retain their own compatible licenses.

Microsoft and Outlook are trademarks of the Microsoft group of companies. OLK2MBOX is an independent project and is not affiliated with, endorsed by, or sponsored by Microsoft. The program does not modify or bypass commercial license controls.

## Revision history

- Document revision 4.0.0 — 2026-09-09: publish the clean single-root repository containing the current app and CLI source trees.
