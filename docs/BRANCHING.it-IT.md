---
title: "Strategia dei branch — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# Strategia dei branch

[English](BRANCHING.en-US.md) · **Italiano**

OLK2MBOX mantiene insieme l’applicazione macOS e la CLI correnti nel branch protetto `main`. L’applicazione resta il prodotto principale presentato dal repository.

| Percorso | Prodotto | Versione stabile | Distribuzione |
|---|---|---:|---|
| `app/` | Applicazione macOS nativa per Apple Silicon | 2.0.0 | DMG, ZIP, archivi sorgente e tag `app-v*` |
| `cli/` | Script Python da riga di comando | 2.0.0 | Script firmato, archivi sorgente e tag `cli-v*` |

## Regole di manutenzione

- Le versioni CLI e app possono avanzare indipendentemente pur condividendo un unico albero sorgente.
- La build dell’app incorpora il convertitore da `cli/olk2mbox.py`, eliminando divergenze del parser.
- Lo sviluppo usa branch temporanei e pull request dirette a `main`.
- La documentazione italiana e inglese resta sincronizzata.
- I binari compilati non vengono inseriti nella cronologia Git: vengono distribuiti come artefatti di GitHub Actions o GitHub Releases.
- Entrambe le linee di prodotto sono distribuite secondo GPL-3.0-or-later e usano tag di release firmati.

## Convenzione delle versioni

- CLI: versione del file `cli/olk2mbox.py`, tag `cli-vMAJOR.MINOR.PATCH`.
- App: `CFBundleShortVersionString`, tag `app-vMAJOR.MINOR.PATCH`.
- Motore incorporato: registrato separatamente nella documentazione e nel manifest di build dell’app.

## Cronologia

- Revisione documento 3.0.0 — 2026-09-09: consolida app e CLI correnti nell’unico branch protetto `main`.
