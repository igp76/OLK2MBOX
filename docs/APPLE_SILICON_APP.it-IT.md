---
title: "App Apple Silicon — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# App Apple Silicon

[English](APPLE_SILICON_APP.en-US.md) · **Italiano**

## Contenuto della distribuzione

`OLK2MBOX.app` 2.0.0 è un’applicazione SwiftUI nativa stabile per Mac Apple Silicon. Include al proprio interno il convertitore 2.0.0 e il runtime Python necessario: sul Mac di destinazione non occorre installare Python o Outlook.

L’interfaccia consente di scegliere il profilo, la destinazione e le principali opzioni di conversione. Comprende una barra basata sui conteggi dei messaggi selezionati ed elaborati, tempo trascorso e tempo residuo stimato, log live navigabile e copiabile, scorrimento automatico disattivabile e quattro livelli di dettaglio. La conversione può essere interrotta in qualsiasi momento.

## Avanzamento e log di esecuzione

La barra è indeterminata mentre il motore analizza il profilo. Appena è disponibile il totale dei messaggi, diventa determinata. La stima del tempo residuo viene ricalcolata usando la velocità media osservata ed è quindi indicativa, soprattutto quando le dimensioni degli allegati variano.

Il log live consente navigazione verticale e orizzontale e selezione del testo. `Segui le ultime righe` mantiene visibile la riga più recente; disattivarlo permette di esaminare l’output precedente, mentre `Vai in fondo` riporta alla fine. Per mantenere fluida l’interfaccia, l’output eccezionalmente lungo viene troncato soltanto nella visualizzazione; il log di esecuzione completo rimane su disco.

Il controllo `Dettaglio log` regola la frequenza degli aggiornamenti:

| Livello | Intervallo di avanzamento |
|---|---:|
| Sintetico | 1.000 messaggi |
| Normale | 250 messaggi |
| Dettagliato | 50 messaggi |
| Estremo | Ogni messaggio |

Ogni esecuzione crea due file UTF-8 con data e ora direttamente nella destinazione MBOX selezionata:

- `OLK2MBOX-YYYYMMDD-HHmmss-execution.log`: output completo del motore, metadati dell’esecuzione, percorsi scelti e configurazione del log.
- `OLK2MBOX-YYYYMMDD-HHmmss-errors.log`: stato di avvio/conversione ed errori strutturati estratti da `OLK2MBOX-conversion-manifest.json`; un’esecuzione riuscita e senza problemi registra esplicitamente l’assenza di errori.

## Requisiti

- Mac con processore Apple Silicon (`arm64`).
- macOS 13 Ventura o successivo.
- Spazio libero sufficiente per gli MBOX prodotti.
- Profilo legacy Outlook per Mac 15 contenente `Data/Outlook.sqlite`.

## Build locale

```bash
./app/build_olk2mbox.sh
```

La build crea un ambiente temporaneo locale, installa la versione bloccata di PyInstaller e rimuove l’ambiente dopo la verifica. I risultati vengono prodotti in `dist/`:

```text
dist/
├── OLK2MBOX.app
├── OLK2MBOX-2.0.0-arm64.zip
├── OLK2MBOX-2.0.0-arm64.dmg
├── OLK2MBOX-2.0.0-release-manifest.json
└── OLK2MBOX-2.0.0-SHA256SUMS.txt
```

Il DMG presenta l’app insieme al collegamento `Applications`, per la consueta installazione tramite trascinamento. Lo script verifica automaticamente l’immagine disco dopo la creazione.

Per usare un certificato Apple Developer ID disponibile nel Portachiavi:

```bash
./app/build_olk2mbox.sh --identity "Developer ID Application: NAME (TEAMID)"
```

## Firma e Gatekeeper

Senza un’identità Developer ID, lo script applica una firma Apple ad hoc e ne verifica l’integrità. Questa firma è adatta a test e uso locale, ma non costituisce notarizzazione Apple. Per distribuire l’app ad altri Mac senza avvisi Gatekeeper occorrono un certificato Developer ID Application e la notarizzazione Apple.

OpenPGP firma il tag annotato della release e produce firme separate per ZIP, DMG, manifest di release e file dei checksum. Eseguire `./app/sign_olk2mbox_release.sh` nell’ambiente locale autorizzato, quindi usare `./app/sign_olk2mbox_release.sh --verify-only` per ripetere la verifica. Consultare [Firma e verifica della release](RELEASE_SIGNING.it-IT.md).

OpenPGP non firma un bundle macOS secondo il modello di fiducia Apple e non sostituisce `codesign`, runtime protetto, Developer ID o notarizzazione. La release 2.0.0 mantiene una firma Apple ad hoc e non è notarizzata.

## Licenza e codice sorgente corrispondente

L’applicazione e il codice originale sono distribuiti secondo GNU GPL versione 3 o successiva. Il DMG e il bundle contengono il testo completo della GPLv3, la pila di licenze di Python 3.14.7, avvisi bilingui sulle terze parti e l’indirizzo esatto del codice sorgente corrispondente. Il tag firmato `app-v2.0.0` identifica i sorgenti di questa release binaria; la build incorpora il convertitore canonico da `cli/olk2mbox.py`.

## Automazione GitHub

Il workflow `Build OLK2MBOX Apple Silicon App` viene eseguito su un runner macOS `arm64`, lancia i test, compila entrambe le componenti, verifica architettura, firma Apple ad hoc, immagine disco e checksum e pubblica gli input di release non firmati. La chiave privata OpenPGP non lascia mai l’ambiente locale autorizzato, che esegue firma e verifica finali prima della pubblicazione. Gli artefatti compilati non vengono aggiunti alla cronologia Git.

## Cronologia

- Revisione documento 3.0.0 — 2026-09-09: allinea build e documentazione dell’app al repository consolidato a radice pulita.

## Privacy

La conversione è interamente locale. L’app non carica messaggi, allegati o metadati su GitHub o su servizi esterni. Soltanto il codice sorgente e le configurazioni di build appartengono al repository.
