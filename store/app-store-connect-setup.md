# App Store Connect Setup

App: Voice Recorder Pro - Audio K
Bundle ID: com.dmkr.audio
Version: 1.0
Primary locale preparada: es-ES

## Estado Local

- Icono iOS corregido desde el asset existente `Resources/ChatGPT Image 22 may 2026, 03_44_13.png`.
- Capturas iPhone 6.7 enlazadas en `store-manifest.json`.
- Nombre visible actualizado a `Voice Recorder Pro - Audio K`.
- Product IDs de StoreKit documentados en `store-manifest.json`.

## Capturas Ios

Usar estas capturas en App Store Connect para iPhone 6.7:

1. `store/app-store/es-ES/iphone-67-real/01-preparado-real.png`
2. `store/app-store/es-ES/iphone-67-real/02-grabando-real.png`
3. `store/app-store/es-ES/iphone-67-real/03-archivos-real.png`

Todas miden `1290x2796`.

## Suscripciones

Crear un grupo de suscripciones:

- Reference name: `Voice Recorder Pro - Audio K Support`

Crear estos productos dentro del grupo:

| Product ID | Reference name | Duracion | Precio objetivo |
| --- | --- | --- | --- |
| `com.dmkr.audio.support.monthly.099` | `Audio K Support Monthly 0.99` | 1 mes | 0.99 |
| `com.dmkr.audio.support.monthly.299` | `Audio K Support Monthly 2.99` | 1 mes | 2.99 |
| `com.dmkr.audio.support.monthly.499` | `Audio K Support Monthly 4.99` | 1 mes | 4.99 |

Localizacion inicial:

| Product ID | es-ES nombre | es-ES descripcion | en-US name | en-US description |
| --- | --- | --- | --- | --- |
| `com.dmkr.audio.support.monthly.099` | Sin anuncios mensual | Quita los anuncios de la app. | No Ads Monthly | Removes ads from the app. |
| `com.dmkr.audio.support.monthly.299` | Apoyo Plus mensual | Quita anuncios y apoya la app. | Support Plus Monthly | Removes ads and supports the app. |
| `com.dmkr.audio.support.monthly.499` | Apoyo Pro mensual | Quita anuncios y apoya mas. | Support Pro Monthly | Removes ads and supports more. |

## Pendiente En Apple

- Crear o verificar la app con Bundle ID `com.dmkr.audio`.
- Configurar App Information: nombre, categoria, edad, privacidad y soporte.
- Aceptar Paid Apps Agreement y completar banking/tax si las suscripciones aun no cargan.
- Crear el grupo de suscripciones y los tres productos anteriores.
- Subir la build a TestFlight/App Store Connect.
- Asociar las suscripciones a la version antes de enviarla a review.
- Completar App Privacy, Content Rights, Ads Identifier y review notes.

## API

Para subir metadata por API hay que definir:

```powershell
$env:ASC_KEY_ID="..."
$env:ASC_ISSUER_ID="..."
$env:ASC_PRIVATE_KEY_PATH="C:\ruta\AuthKey_XXXX.p8"
```

Luego ejecutar:

```powershell
node tools\store-publishing\scripts\appstoreconnect-check.mjs Audio\store\store-manifest.json
node tools\store-publishing\scripts\appstoreconnect-metadata.mjs Audio\store\store-manifest.json --upload
```
