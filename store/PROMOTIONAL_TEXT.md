# App Store promotional text

Prepared on 2026-09-01 for the active Voice Recorder Pro - Audio K listing.
These texts describe the current iOS build and stay below Apple's 170-character
limit. They are separate from version-specific `What's New` release notes.

| Locale | Characters | Text |
| --- | ---: | --- |
| `ca` | 125 | Grava notes de veu, reunions i idees amb modes continu o per so, segments configurables i una biblioteca local de gravacions. |
| `de-DE` | 135 | Nimm Sprachnotizen, Besprechungen und Ideen im Dauer- oder Klangmodus auf – mit einstellbaren Segmenten und lokaler Aufnahmebibliothek. |
| `en-US` | 133 | Record voice notes, meetings and ideas with continuous or sound-activated modes, configurable segments and a local recording library. |
| `es-ES` | 133 | Graba notas de voz, reuniones e ideas con modos continuo o por sonido, segmentos configurables y una biblioteca local de grabaciones. |
| `fr-FR` | 130 | Enregistrez notes vocales, réunions et idées en mode continu ou activé par le son, avec segments réglables et bibliothèque locale. |
| `it` | 126 | Registra note vocali, riunioni e idee in modalità continua o attivata dal suono, con segmenti configurabili e libreria locale. |
| `pt-PT` | 122 | Grave notas de voz, reuniões e ideias em modo contínuo ou ativado por som, com segmentos configuráveis e biblioteca local. |

Evidence: counts are Unicode code-point counts. `store/store-manifest.json`
contains the same canonical strings under each iOS locale. GitHub Actions run
`33451128043` updated only `promotionalText` through the official App Store
Connect API and read every localization back successfully. The version remained
`WAITING_FOR_REVIEW`; its build, `What's New`, submission and release settings
were not changed.
