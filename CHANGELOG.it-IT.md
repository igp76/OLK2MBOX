---
title: "Cronologia delle modifiche — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# Cronologia delle modifiche

[English](CHANGELOG.en-US.md) · **Italiano**

Il progetto segue il [Versionamento Semantico](https://semver.org/lang/it/). Questo repository a radice pulita registra intenzionalmente soltanto la generazione di prodotto attualmente supportata.

## App 2.0.0 / CLI 2.0.0 — Stabile

### Applicazione

- Interfaccia SwiftUI nativa e bilingue per Apple Silicon e macOS 13 o successivo.
- Convertitore e runtime Python autosufficienti; Outlook e Python non sono richiesti sul Mac di destinazione.
- Avanzamento determinato, tempo trascorso e residuo stimato, output live selezionabile e quattro livelli di dettaglio del log.
- Log di esecuzione ed errore con data e ora, pubblicazione atomica degli MBOX e opzioni di recupero configurabili.
- Firma Apple ad hoc; la notarizzazione Apple non è stata eseguita.

### Convertitore

- Conversione in sola lettura dei profili legacy Outlook per Mac 15 in MBOX standard.
- Conservazione della gerarchia, delle intestazioni disponibili, dei corpi testuali/HTML, delle risorse inline e degli allegati MIME.
- Funzionamento autonomo con Python 3.10+ usando soltanto la libreria standard.
- Manifest JSON, modalità anteprima e selezione cartelle, filtri, scrittura atomica e gestione configurabile degli errori.

### Repository e catena di fornitura

- Sorgenti di applicazione e CLI consolidati nell’unico branch protetto `main`.
- Le build dell’app incorporano il convertitore canonico da `cli/olk2mbox.py`.
- I pacchetti compilati sono distribuiti soltanto tramite le release correnti `app-v2.0.0` e `cli-v2.0.0`.
- Commit di produzione, tag annotati, pacchetti, manifest e checksum usano firme OpenPGP verificate.
- Le GitHub Actions sono fissate a identificativi di commit immutabili, le dipendenze di build usano hash esatti e CodeQL copre Actions, Python e Swift.
- Codice e documentazione originali del progetto sono distribuiti secondo GPL-3.0-or-later.

## Revisione del documento

- Revisione 3.0.0 — 2026-09-09: introduce la cronologia a radice pulita per la release corrente consolidata.
