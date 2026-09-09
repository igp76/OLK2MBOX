---
title: "Architettura — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# Architettura

[English](ARCHITECTURE.en-US.md) · **Italiano**

## Obiettivo

OLK2MBOX converte un profilo legacy Outlook per Mac 15 in una gerarchia di file MBOX senza dipendere da Outlook o da convertitori commerciali durante l’esecuzione.

## Flusso dei dati

```text
Main Profile/
├── Data/Outlook.sqlite ──► cartelle, messaggi, relazioni e metadati
├── Data/Messages/      ──► proprietà OLK15 dei messaggi
└── Data/Message Attachments/ ──► blocchi MIME e sorgenti originali
                                  │
                                  ▼
                         parser e ricostruzione MIME
                                  │
                                  ▼
                       un file .mbox per ogni cartella
                       + OLK2MBOX-conversion-manifest.json
                       + log di esecuzione/errori
```

## Componenti

| Componente | Responsabilità |
|---|---|
| Accesso SQLite | Apre `Outlook.sqlite` in sola lettura e recupera gerarchia, record e blocchi posseduti. |
| Parser OLK15 | Decodifica raccolte di proprietà, destinatari e blocchi `Attc`/`MSrc`. |
| Ricostruzione MIME | Conserva intestazioni, testo, HTML, risorse inline, allegati ed email allegate. |
| Writer MBOX | Protegge le righe `From ` e scrive prima un file `.partial`, poi lo sostituisce atomicamente. |
| Manifest | Registra versione, statistiche, origine ed eventuali errori. |

## Struttura dei sorgenti

```text
app/                  applicazione SwiftUI e strumenti di build Apple
cli/olk2mbox.py       convertitore canonico usato da entrambi i prodotti
cli/tests/            test unitari del convertitore
docs/                 documentazione sincronizzata in italiano e inglese
third_party/          testi delle licenze di terze parti richiesti
```

## Architettura dell’app

```text
OLK2MBOX.app (arm64)
├── Contents/MacOS/OLK2MBOX      interfaccia SwiftUI nativa
├── Contents/Helpers/olk2mbox   motore Python autosufficiente
└── Contents/Resources/OLK2MBOX-build-manifest.json
                                         provenienza build (oltre a icona/localizzazioni)
```

La build dell’app impacchetta `cli/olk2mbox.py` come helper autosufficiente. L’interfaccia avvia l’helper come processo figlio, gli passa soltanto i percorsi e le opzioni scelti dall’utente e invia il flusso combinato di output/errori standard sia a una vista live selezionabile sia a un log di esecuzione completo. Interpreta le righe con il conteggio dei messaggi per alimentare la barra di avanzamento e la stima del tempo. Al termine copia gli errori strutturati del manifest del convertitore nel log degli errori specifico dell’esecuzione. Lo stesso sorgente resta utilizzabile e verificabile separatamente come CLI.

## Proprietà di sicurezza

- Il database sorgente viene aperto con `mode=ro` e `query_only`.
- I percorsi letti dal database non possono uscire dalla directory `Data`.
- Nessun MBOX esistente viene sostituito senza `--overwrite`.
- Profili Outlook, email ed esportazioni sono esclusi dal controllo versione.

## Confini di compatibilità

Il motore stabile 2.0.0 supporta il formato cache dei profili Outlook per Mac 15 esaminato. Non interpreta direttamente archivi `.olm`, calendari, contatti o profili del “Nuovo Outlook”.

## Cronologia

- Revisione documento 3.0.0 — 2026-09-09: documenta la struttura consolidata dei sorgenti e il convertitore canonico condiviso.
