---
title: "Apple Silicon app — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Apple Silicon app

**English** · [Italiano](APPLE_SILICON_APP.it-IT.md)

## Distribution contents

`OLK2MBOX.app` 2.0.0 is a stable native SwiftUI application for Apple Silicon Macs. It embeds converter 2.0.0 and the required Python runtime: Python and Outlook do not need to be installed on the destination Mac.

The interface provides profile, destination, and primary conversion-option selection. It includes a progress bar based on selected and processed message counts, elapsed time and estimated remaining time, a navigable/copyable live log, automatic scrolling that can be disabled, and four log-detail levels. The conversion can be stopped at any time.

## Progress and run logs

The bar is indeterminate while the engine scans the profile. As soon as the total message count is available, it becomes determinate. The remaining-time estimate is recalculated from the observed average rate and is therefore indicative, especially when attachment sizes vary.

The live log supports vertical and horizontal navigation and text selection. `Follow latest output` keeps the newest line visible; disable it to inspect earlier output, or use `Jump to latest` to return to the end. To keep the interface responsive, exceptionally long output is truncated only in the display; the complete execution log remains on disk.

The `Log detail` control maps reporting frequency as follows:

| Level | Progress interval |
|---|---:|
| Concise | 1,000 messages |
| Normal | 250 messages |
| Detailed | 50 messages |
| Extreme | Every message |

Each run creates two timestamped UTF-8 files directly in the selected MBOX destination:

- `OLK2MBOX-YYYYMMDD-HHmmss-execution.log`: complete engine output, run metadata, selected paths, and logging configuration.
- `OLK2MBOX-YYYYMMDD-HHmmss-errors.log`: launch/conversion status and structured errors extracted from `OLK2MBOX-conversion-manifest.json`; a successful clean run explicitly records that no errors were found.

## Requirements

- A Mac with an Apple Silicon (`arm64`) processor.
- macOS 13 Ventura or later.
- Sufficient free space for the generated MBOX files.
- A legacy Outlook for Mac 15 profile containing `Data/Outlook.sqlite`.

## Local build

```bash
./app/build_olk2mbox.sh
```

The build creates a local temporary environment, installs the pinned PyInstaller version, and removes the environment after verification. Results are produced in `dist/`:

```text
dist/
├── OLK2MBOX.app
├── OLK2MBOX-2.0.0-arm64.zip
├── OLK2MBOX-2.0.0-arm64.dmg
├── OLK2MBOX-2.0.0-release-manifest.json
└── OLK2MBOX-2.0.0-SHA256SUMS.txt
```

The DMG presents the app alongside an `Applications` link for the customary drag-to-install workflow. The build script automatically verifies the disk image after creation.

To use an Apple Developer ID certificate available in Keychain:

```bash
./app/build_olk2mbox.sh --identity "Developer ID Application: NAME (TEAMID)"
```

## Signing and Gatekeeper

Without a Developer ID identity, the script applies an Apple ad hoc signature and verifies its integrity. This signature is suitable for testing and local use, but it is not Apple notarization. Distribution to other Macs without Gatekeeper warnings requires a Developer ID Application certificate and Apple notarization.

OpenPGP signs the annotated release tag and detached signatures for the ZIP, DMG, release manifest, and checksum file. Run `./app/sign_olk2mbox_release.sh` in the authorized local environment, then use `./app/sign_olk2mbox_release.sh --verify-only` to repeat verification. See [Release signing and verification](RELEASE_SIGNING.en-US.md).

OpenPGP does not sign a macOS bundle in Apple’s trust model and does not replace `codesign`, hardened runtime, Developer ID, or notarization. Release 2.0.0 remains Apple ad-hoc signed and is not notarized.

## License and corresponding source

The application and original source are licensed under GNU GPL version 3 or later. The DMG and application bundle contain the complete GPLv3 text, the Python 3.14.7 license stack, bilingual third-party notices, and the exact corresponding-source address. The signed `app-v2.0.0` tag is the source for this binary release; the app build embeds the canonical converter from `cli/olk2mbox.py`.

## GitHub automation

The `Build OLK2MBOX Apple Silicon App` workflow runs on an `arm64` macOS runner, executes the tests, compiles both components, verifies architecture, the ad-hoc Apple signature, disk image, and checksums, and publishes unsigned release inputs. The private OpenPGP key never leaves the authorized local environment, which performs final signing and verification before publication. Compiled artifacts are not added to Git history.

## Revision history

- Document revision 3.0.0 — 2026-09-09: align the app build and documentation with the consolidated clean-root repository.

## Privacy

Conversion is entirely local. The app does not upload messages, attachments, or metadata to GitHub or external services. Only source code and build configurations belong in the repository.
