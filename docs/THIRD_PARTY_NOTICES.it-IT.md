---
title: "Avvisi sulle terze parti — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# Avvisi sulle terze parti

[English](THIRD_PARTY_NOTICES.en-US.md) · **Italiano**

OLK2MBOX 2.0.0 incorpora o utilizza i seguenti componenti di terze parti. Tali componenti conservano le rispettive licenze; questo avviso non sostituisce i testi integrali delle licenze.

## Python 3.14.7

Il convertitore autosufficiente incorpora il runtime CPython 3.14.7 e la libreria standard Python. Python è distribuito secondo Python Software Foundation License Version 2 e la relativa pila di licenze storiche. La pila completa inclusa nell’applicazione è disponibile in `Contents/Resources/Licenses/PYTHON-3.14.7-LICENSE.txt`; la copia nel repository è [`third_party/PYTHON-3.14.7-LICENSE.txt`](../third_party/PYTHON-3.14.7-LICENSE.txt).

Le indicazioni di copyright contenute nel file restano di proprietà dei rispettivi titolari.

## SQLite

Il convertitore accede ai dati Outlook tramite il modulo `sqlite3` di Python. Gli autori hanno dedicato SQLite al pubblico dominio. Consultare [SQLite Copyright](https://www.sqlite.org/copyright.html).

## PyInstaller 6.22.2

PyInstaller è uno strumento utilizzato in fase di build per creare il convertitore autosufficiente. Non è una dipendenza sorgente di OLK2MBOX. PyInstaller è distribuito secondo GPLv2 con eccezione per il bootloader, più Apache-2.0 per i file identificati; l’eccezione consente di distribuire i bundle generati secondo la licenza dell’applicazione. Consultare la [documentazione della licenza PyInstaller](https://pyinstaller.org/en/stable/license.html).

## Framework di sistema Apple

L’interfaccia macOS si collega dinamicamente ai framework AppKit, SwiftUI, Combine, Foundation e runtime Swift forniti dal sistema. Questi componenti vengono forniti da Apple come parte di macOS e non vengono copiati nel repository.

## Progetti di interoperabilità consultati

Le strutture dati Outlook sono state implementate in modo indipendente e confrontate con progetti pubblici di interoperabilità identificati nella documentazione dell’architettura. Nessun sorgente di tali progetti è incorporato nel repository.

## Cronologia

- Revisione documento 3.0.0 — 2026-09-09: trasferisce l’inventario corrente dei componenti nel repository consolidato a radice pulita.
