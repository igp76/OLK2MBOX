---
title: "Third-party notices — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "en-US"
status: "Stable"
license: "GPL-3.0-or-later"
---

# Third-party notices

**English** · [Italiano](THIRD_PARTY_NOTICES.it-IT.md)

OLK2MBOX 2.0.0 embeds or uses the following third-party components. Those components retain their own licenses; this notice does not replace their complete license texts.

## Python 3.14.7

The self-contained converter embeds the CPython 3.14.7 runtime and Python standard library. Python is distributed under the Python Software Foundation License Version 2 and its historical license stack. The complete license stack shipped with the application is available at `Contents/Resources/Licenses/PYTHON-3.14.7-LICENSE.txt`; the repository copy is [`third_party/PYTHON-3.14.7-LICENSE.txt`](../third_party/PYTHON-3.14.7-LICENSE.txt).

Copyright notices in that file remain the property of their respective holders.

## SQLite

The converter accesses Outlook data through Python’s `sqlite3` module. SQLite has been dedicated to the public domain by its authors. See [SQLite Copyright](https://www.sqlite.org/copyright.html).

## PyInstaller 6.22.2

PyInstaller is a build-time tool used to create the self-contained converter. It is not a source dependency of OLK2MBOX. PyInstaller is distributed under GPLv2 with a bootloader exception, plus Apache-2.0 for identified files; its exception permits generated bundles to be distributed under the application’s license. See the [PyInstaller license documentation](https://pyinstaller.org/en/stable/license.html).

## Apple system frameworks

The macOS interface links dynamically to system-provided AppKit, SwiftUI, Combine, Foundation, and Swift runtime frameworks. These components are supplied by Apple as part of macOS and are not copied into this repository.

## Referenced interoperability projects

The Outlook data structures were independently implemented and cross-checked against public interoperability projects identified in the architecture documentation. No source from those projects is vendored into this repository.

## Revision history

- Document revision 3.0.0 — 2026-09-09: carry the current component inventory into the consolidated clean-root repository.
