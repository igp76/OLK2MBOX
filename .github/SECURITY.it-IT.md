---
title: "Politica di sicurezza — OLK2MBOX"
document_revision: "2.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# Politica di sicurezza

[English](SECURITY.en-US.md) · **Italiano**

## Versioni supportate

Le correzioni di sicurezza riguardano le release app e CLI `2.x` stabili correnti provenienti dal branch consolidato `main`. Questo repository a radice pulita non distribuisce release binarie storiche.

## Segnalare una vulnerabilità

Usare la [segnalazione privata delle vulnerabilità di GitHub](https://github.com/igp76/OLK2MBOX/security/advisories/new). Non divulgare una vulnerabilità irrisolta tramite issue pubbliche.

Indicare versione interessata, versione del sistema operativo o di Python, passaggi riproducibili, impatto ed eventuale mitigazione proposta. Non allegare mai profili Outlook reali, messaggi, credenziali, percorsi personali o altri dati privati. Usare soltanto campioni sintetici.

## Politica della catena di fornitura

I commit di produzione e i tag di release sono firmati OpenPGP. Pacchetti, manifest e checksum delle release dispongono di firme separate verificate. GitHub Actions è limitato alle azioni di proprietà GitHub fissate a identificativi di commit completi, i token dei workflow sono in sola lettura, le dipendenze Python di build sono fissate a versioni esatte e hash SHA-256 e l’analisi CodeQL estesa copre Actions, Python e Swift compilato manualmente.

Il pacchetto macOS rimane firmato Apple ad hoc e non notarizzato finché non saranno disponibili credenziali Developer ID autorizzate.

## Cronologia

- Revisione documento 2.0.0 — 2026-09-09: allinea versioni supportate e controlli al repository consolidato a radice pulita.
