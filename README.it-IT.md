---
title: "OLK2MBOX per macOS"
document_revision: "4.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# OLK2MBOX per macOS

[English](README.en-US.md) · **Italiano**

![App](https://img.shields.io/badge/app_macOS-2.0.0_stabile-34C759?logo=apple)
![Motore](https://img.shields.io/badge/convertitore-2.0.0-blue)
![Piattaforma](https://img.shields.io/badge/Apple_Silicon-arm64-black?logo=apple)
![Licenza](https://img.shields.io/badge/licenza-GPL--3.0--or--later-blue)

OLK2MBOX è un’applicazione macOS nativa e autosufficiente che converte i profili legacy di Outlook per Mac 15 in file MBOX standard. Conserva la gerarchia originale delle cartelle, i messaggi, le intestazioni disponibili, i corpi HTML/testuali, le risorse inline e gli allegati, senza richiedere Outlook o un’installazione separata di Python.

> [!IMPORTANT]
> Non aggiungere mai al repository profili Outlook, database, messaggi, allegati, log o esportazioni MBOX. La conversione avviene localmente e il profilo sorgente viene aperto in sola lettura.

## Download

Scaricare la release stabile Apple Silicon da [OLK2MBOX 2.0.0](https://github.com/igp76/OLK2MBOX/releases/tag/app-v2.0.0). La release comprende:

- DMG con installazione tramite trascinamento in `Applications`;
- ZIP contenente `OLK2MBOX.app`;
- manifest di release e checksum SHA-256;
- firme OpenPGP separate per ogni input della release;
- archivi sorgente `.zip` e `.tar.gz` generati dal tag firmato.

Requisiti: Mac Apple Silicon (`arm64`) con macOS 13 Ventura o successivo.

L’edizione Python autonoma è disponibile nella release [OLK2MBOX CLI 2.0.0](https://github.com/igp76/OLK2MBOX/releases/tag/cli-v2.0.0).

> [!WARNING]
> L’applicazione corrente usa una firma Apple ad hoc e non è notarizzata. OpenPGP verifica provenienza dal progetto e integrità dei pacchetti, ma non sostituisce Developer ID e notarizzazione Apple.

## Uso dell’applicazione

1. Aprire il DMG e trascinare `OLK2MBOX.app` in `Applications`.
2. Selezionare la cartella `Main Profile` del profilo Outlook legacy oppure la relativa cartella `Data`.
3. Selezionare una destinazione con spazio libero sufficiente.
4. Scegliere le opzioni per allegati, filtri, gestione errori, sovrascrittura e dettaglio del log.
5. Avviare la conversione e controllare barra di avanzamento, tempo trascorso e tempo residuo stimato.

Il log live è scorrevole, selezionabile e copiabile. Disattivare `Segui le ultime righe` per esaminare le righe precedenti oppure usare `Vai in fondo` per tornare alla fine.

Ogni esecuzione scrive due file con data e ora accanto alla gerarchia MBOX generata:

- `OLK2MBOX-YYYYMMDD-HHmmss-execution.log` — output completo del motore e metadati dell’esecuzione;
- `OLK2MBOX-YYYYMMDD-HHmmss-errors.log` — errori strutturati della conversione oppure indicazione esplicita di esecuzione senza errori.

Il dettaglio varia dagli aggiornamenti sintetici ogni 1.000 messaggi all’output estremo per ogni messaggio elaborato. La vista mantiene una coda limitata per restare fluida; il log su disco rimane completo.

## Output

```text
destinazione/
├── OLK2MBOX-YYYYMMDD-HHmmss-execution.log
├── OLK2MBOX-YYYYMMDD-HHmmss-errors.log
├── OLK2MBOX-conversion-manifest.json
└── Main Profile/
    ├── Exchange Account 101/
    │   └── Inbox.mbox
    └── On My Computer/
        └── Archivio.mbox
```

Gli MBOX esistenti non vengono sostituiti salvo selezionare `Sostituisci i file MBOX esistenti`. Il convertitore scrive file `.partial` e pubblica atomicamente gli MBOX finali.

I nomi dei file MBOX mantengono intenzionalmente i nomi delle cartelle Outlook di origine, così la gerarchia recuperata resta riconoscibile; sono output di dati, non binari del prodotto.

## Documentazione

- [Guida all’applicazione Apple Silicon](docs/APPLE_SILICON_APP.it-IT.md)
- [Convertitore da riga di comando](docs/COMMAND_LINE.it-IT.md)
- [Architettura](docs/ARCHITECTURE.it-IT.md)
- [Strategia dei branch](docs/BRANCHING.it-IT.md)
- [Licenza](docs/LICENSING.it-IT.md)
- [Avvisi sulle terze parti](docs/THIRD_PARTY_NOTICES.it-IT.md)
- [Verifica delle firme della release](docs/RELEASE_SIGNING.it-IT.md)
- [Politica di sicurezza](.github/SECURITY.it-IT.md)
- [Cronologia delle modifiche](CHANGELOG.it-IT.md)

## Struttura del repository

| Percorso | Prodotto | Versione stabile |
|---|---|---:|
| `app/` | Applicazione macOS nativa e autosufficiente | 2.0.0 |
| `cli/` | Convertitore Python autonomo da riga di comando | 2.0.0 |
| `docs/` | Documentazione bilingue condivisa | 4.0.0 |

Entrambi i prodotti sono mantenuti insieme nel branch protetto `main`. I branch temporanei servono soltanto per modifiche di sviluppo sottoposte a revisione. I pacchetti compilati sono pubblicati come asset delle release e non vengono inseriti nella cronologia Git.

## Build dai sorgenti

```bash
python3 -m unittest discover -s cli/tests -v
./app/build_olk2mbox.sh
./cli/build_olk2mbox_cli_release.sh
```

La build produce applicazione, ZIP, DMG, manifest di release e file dei checksum in `dist/`. La firma della release viene eseguita soltanto nell’ambiente locale autorizzato:

```bash
./app/sign_olk2mbox_release.sh
./app/sign_olk2mbox_release.sh --verify-only
./cli/sign_olk2mbox_cli_release.sh
./cli/sign_olk2mbox_cli_release.sh --verify-only
```

## Licenza e indipendenza

Copyright © 2026 igp76. OLK2MBOX è distribuito secondo la [GNU General Public License, versione 3 o successiva](LICENSE). Il codice sorgente corrispondente completo accompagna ogni release binaria. I componenti di terze parti conservano le rispettive licenze compatibili.

Microsoft e Outlook sono marchi del gruppo Microsoft. OLK2MBOX è un progetto indipendente e non è affiliato, approvato o sponsorizzato da Microsoft. Il programma non modifica o aggira controlli di licenza commerciali.

## Cronologia

- Revisione documento 4.0.0 — 2026-09-09: pubblica il repository a radice unica contenente i sorgenti correnti dell’app e della CLI.
