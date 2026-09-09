---
title: "Firma e verifica della release — OLK2MBOX"
document_revision: "3.0.0"
revision_date: "2026-09-09"
locale: "it-IT"
status: "Stabile"
license: "GPL-3.0-or-later"
---

# Firma e verifica della release

[English](RELEASE_SIGNING.en-US.md) · **Italiano**

## Identità di fiducia

I commit Git di produzione, i tag annotati delle release, i pacchetti, i manifest e i file dei checksum usano questa identità OpenPGP:

| Campo | Valore |
|---|---|
| Identità | `igp76 <90463101+igp76@users.noreply.github.com>` |
| Impronta primaria | `9A0D7C4D2286FB72B7FBBB71EF548834983D3094` |
| Impronta della sottochiave di firma | `C8F51EAB8C7DB38C53DA8458927D2B68384F934C` |
| Data di scadenza | 2030-12-01 |

Non accettare mai un ID chiave abbreviato come equivalente all’impronta completa.

## Insieme firmato della release

La release `app-v2.0.0` contiene questi quattro input e le rispettive firme separate `.asc` con armatura ASCII:

- `OLK2MBOX-2.0.0-arm64.zip`
- `OLK2MBOX-2.0.0-arm64.dmg`
- `OLK2MBOX-2.0.0-release-manifest.json`
- `OLK2MBOX-2.0.0-SHA256SUMS.txt`

Il tag Git annotato è firmato separatamente. Il manifest identifica versioni, architettura, stato della distribuzione Apple, impronte OpenPGP attese e digest dei pacchetti.

La release `cli-v2.0.0` contiene lo script autonomo `OLK2MBOX-CLI-2.0.0.py`, il relativo manifest e il file dei checksum, ciascuno accompagnato da una firma `.asc` separata. Entrambi i tag firmati identificano lo stesso albero sorgente consolidato, conservando asset specifici per prodotto.

## Verificare i file scaricati

Importare la chiave pubblica tramite un canale fidato, controllarne l’impronta primaria completa, collocare tutti i file della release in una directory ed eseguire:

```bash
gpg --fingerprint 9A0D7C4D2286FB72B7FBBB71EF548834983D3094
gpg --verify OLK2MBOX-2.0.0-arm64.zip.asc OLK2MBOX-2.0.0-arm64.zip
gpg --verify OLK2MBOX-2.0.0-arm64.dmg.asc OLK2MBOX-2.0.0-arm64.dmg
gpg --verify OLK2MBOX-2.0.0-release-manifest.json.asc OLK2MBOX-2.0.0-release-manifest.json
gpg --verify OLK2MBOX-2.0.0-SHA256SUMS.txt.asc OLK2MBOX-2.0.0-SHA256SUMS.txt
shasum -a 256 -c OLK2MBOX-2.0.0-SHA256SUMS.txt
```

Ogni risultato OpenPGP deve indicare una firma valida dell’identità riportata sopra, tramite la sottochiave `C8F51EAB8C7DB38C53DA8458927D2B68384F934C`; ogni checksum deve indicare `OK`.

Verificare il tag firmato in un clone del repository:

```bash
git tag -v app-v2.0.0
git log --show-signature -1 app-v2.0.0
```

## Procedura del manutentore

Costruire l’intero insieme degli input di release, quindi firmarlo soltanto sul sistema locale autorizzato che conserva la chiave privata:

```bash
./app/build_olk2mbox.sh
./app/sign_olk2mbox_release.sh
./app/sign_olk2mbox_release.sh --verify-only
./cli/build_olk2mbox_cli_release.sh
./cli/sign_olk2mbox_cli_release.sh
./cli/sign_olk2mbox_cli_release.sh --verify-only
```

Il workflow cloud produce intenzionalmente input non firmati e non riceve mai la chiave privata.

## Stato della distribuzione Apple

> [!WARNING]
> La release 2.0.0 usa una firma Apple ad hoc e non è notarizzata. OpenPGP verifica provenienza dal progetto e integrità dei file; non sostituisce firma Apple Developer ID, runtime protetto o notarizzazione e non garantisce l’accettazione da parte di Gatekeeper.

Una release ufficiale per la distribuzione Apple richiederà un’identità Developer ID Application autorizzata e credenziali per la notarizzazione, in aggiunta al processo OpenPGP qui documentato.

## Cronologia

- Revisione documento 3.0.0 — 2026-09-09: comprende entrambe le release correnti dalla radice sorgente consolidata e firmata.
