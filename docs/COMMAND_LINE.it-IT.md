---
title: "Convertitore da riga di comando — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# Convertitore da riga di comando

[English](COMMAND_LINE.en-US.md) · **Italiano**

`cli/olk2mbox.py` 2.0.0 è l’edizione stabile e autonoma da riga di comando di OLK2MBOX. Converte i profili legacy Outlook per Mac 15 in file MBOX standard usando soltanto la libreria standard di Python. Applicazione e CLI sono mantenute insieme su `main` e la build dell’app incorpora questo stesso sorgente del convertitore.

Il profilo sorgente viene aperto in sola lettura. Il convertitore è indipendente e non modifica o aggira controlli di licenza commerciali.

## Requisiti

- Python 3.10 o successivo.
- Profilo Outlook legacy contenente `Data/Outlook.sqlite`.
- Spazio libero sufficiente: prevedere almeno il 15% in più rispetto alla stima della dimensione dei messaggi.
- Outlook deve essere chiuso quando si converte un profilo attivo; è preferibile lavorare su una copia.

Il formato di profilo esaminato contiene file `.olk15Message` e `.olk15MsgAttachment`. Questa versione non converte direttamente archivi `.olm`, profili del “Nuovo Outlook”, calendari o contatti.

## Avvio rapido

```bash
chmod +x cli/olk2mbox.py
./cli/olk2mbox.py --version
```

Elencare cartelle e conteggi senza scrivere output:

```bash
./cli/olk2mbox.py "/percorso/Main Profile" "/percorso/output" --list-folders
```

Simulare una conversione completa:

```bash
./cli/olk2mbox.py "/percorso/Main Profile" "/percorso/output" --dry-run
```

Convertire l’intero profilo:

```bash
./cli/olk2mbox.py "/percorso/Main Profile" "/percorso/output"
```

Convertire una cartella, per esempio quella con ID `110`:

```bash
./cli/olk2mbox.py "/percorso/Main Profile" "/percorso/output" --folder-id 110
```

## Opzioni importanti

- `--folder-id ID`: converte soltanto la cartella indicata; può essere ripetuto.
- `--limit N`: limita il numero totale di messaggi per una prova.
- `--no-attachments`: omette allegati e risorse inline incorporate.
- `--exclude-hidden`: omette i messaggi contrassegnati come nascosti.
- `--exclude-deleted`: omette i messaggi contrassegnati per l’eliminazione.
- `--on-error skip`: continua dopo un record danneggiato e lo registra nel manifest.
- `--overwrite`: sostituisce atomicamente gli MBOX di destinazione già esistenti.
- `--progress-every N`: modifica la frequenza degli aggiornamenti.
- `--quiet`: disattiva gli aggiornamenti di avanzamento.

Senza `--overwrite`, un MBOX esistente non viene mai modificato. Il writer usa un file `.partial` e pubblica l’MBOX finale soltanto dopo completamento e sincronizzazione su disco.

## Output

```text
output/
├── OLK2MBOX-conversion-manifest.json
└── Main Profile/
    ├── Exchange Account 101/
    │   └── Inbox.mbox
    └── On My Computer/
        └── Archivio/
            └── 2026.mbox
```

Il manifest registra versione del convertitore, statistiche, origine ed errori. I messaggi includono header `X-Outlook-*` per la tracciabilità. Vengono conservati intestazioni originali disponibili, corpi testuali/HTML, identificativi, struttura delle cartelle, risorse inline e allegati MIME.

Il MIME viene ricostruito e potrebbe non essere identico byte-per-byte al messaggio ricevuto. Le firme DKIM o S/MIME preesistenti potrebbero non risultare più valide. I messaggi scaricati parzialmente contengono i dati disponibili e il marcatore `X-Outlook-Partially-Downloaded`.

## Verifica

```bash
python3 -m unittest discover -s cli/tests -v
```

La validazione sul profilo fornito ha riconosciuto 136.709 messaggi in 38 cartelle non vuote. Il campione Inbox ha conservato 18 payload allegato in 5 messaggi; il campione `01Keep` ha conservato tutti i 210 blocchi allegato in 204 messaggi, senza messaggi saltati o difetti di parsing MIME.

## Licenza

Il convertitore è copyright © 2026 igp76 ed è distribuito secondo GNU GPL versione 3 o successiva. Consultare [`LICENSE`](../LICENSE), [`COPYING`](../COPYING) e la [guida alla licenza](LICENSING.it-IT.md).

## Cronologia

- Revisione documento 3.0.0 — 2026-09-09: documenta il sorgente CLI canonico nel repository consolidato a radice pulita.
