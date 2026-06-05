# App Store Connect Setup

App: Voice Recorder Pro - Audio K
Bundle ID: com.dmkr.audio.B2X6D3A9J9
App Store Connect App ID: 6772278149
Version: 1.0
Primary locale preparada: es-ES

## Estado Local

- Icono iOS corregido desde el asset existente `Resources/ChatGPT Image 22 may 2026, 03_44_13.png`.
- Capturas iPhone 6.7 enlazadas en `store-manifest.json`.
- Nombre visible actualizado a `Voice Recorder Pro - Audio K`.
- Product IDs de StoreKit documentados en `store-manifest.json`.
- Metadata `es-ES` de la version 1.0 subida por App Store Connect API.
- Grupo de suscripciones y productos creados por App Store Connect API.
- Precios configurados en 175 territorios por producto.
- Disponibilidad configurada en 175 territorios por producto.
- Captura de revision de suscripciones subida y procesada.

## Capturas Ios

Usar estas capturas en App Store Connect para iPhone 6.7:

Screenshot set `APP_IPHONE_67`: `4f18f90b-d3cc-4d73-ad6d-ecb70b562a3a`

1. `store/app-store/es-ES/iphone-67-real/01-preparado-real.png` (`0fb9a6b1-ad82-4959-97dd-92847e8721e3`)
2. `store/app-store/es-ES/iphone-67-real/02-grabando-real.png` (`72f198b8-7b8e-4ca8-a82d-4e4f202f2c42`)
3. `store/app-store/es-ES/iphone-67-real/03-archivos-real.png` (`94016756-7d50-4158-851c-aea0de22f12b`)

Todas miden `1290x2796`.

## Suscripciones

Crear un grupo de suscripciones:

- Reference name: `Voice Recorder Pro - Audio K Support`
- App Store Connect ID: `22136463`

Crear estos productos dentro del grupo:

| Product ID | App Store Connect ID | Reference name | Duracion | Precio objetivo |
| --- | --- | --- | --- | --- |
| `com.dmkr.audio.support.monthly.099` | `6777118434` | `Audio K Support Monthly 0.99` | 1 mes | 0.99 |
| `com.dmkr.audio.support.monthly.299` | `6777118297` | `Audio K Support Monthly 2.99` | 1 mes | 2.99 |
| `com.dmkr.audio.support.monthly.499` | `6777118235` | `Audio K Support Monthly 4.99` | 1 mes | 4.99 |

Estado verificado:

| Product ID | Estado | Precios | Territorios | Review screenshot |
| --- | --- | --- | --- | --- |
| `com.dmkr.audio.support.monthly.099` | `READY_TO_SUBMIT` | 175 | 175 | `d1acda25-b487-438a-a461-b4f52ecb2845` |
| `com.dmkr.audio.support.monthly.299` | `READY_TO_SUBMIT` | 175 | 175 | `dc7d7113-6dc8-45e2-b47d-34e3687e7ca4` |
| `com.dmkr.audio.support.monthly.499` | `READY_TO_SUBMIT` | 175 | 175 | `4d4779bf-152e-4b20-87f2-2458c2d6ef04` |

Localizacion inicial:

| Product ID | es-ES nombre | es-ES descripcion | en-US name | en-US description |
| --- | --- | --- | --- | --- |
| `com.dmkr.audio.support.monthly.099` | Sin anuncios mensual | Quita los anuncios de la app. | No Ads Monthly | Removes ads from the app. |
| `com.dmkr.audio.support.monthly.299` | Apoyo Plus mensual | Quita anuncios y apoya la app. | Support Plus Monthly | Removes ads and supports the app. |
| `com.dmkr.audio.support.monthly.499` | Apoyo Pro mensual | Quita anuncios y apoya mas. | Support Pro Monthly | Removes ads and supports more. |

## Pendiente En Apple

- Configurar App Information pendiente no cubierta por el script: categoria, edad, privacidad y soporte.
- Aceptar Paid Apps Agreement y completar banking/tax si las suscripciones no permiten precio o venta.
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

## GitHub Actions App Store Build

Workflow creado:

```text
.github/workflows/upload-ios-appstore.yml
```

Secrets necesarios para ejecutarlo:

```text
APPLE_TEAM_ID=B2X6D3A9J9
ASC_KEY_ID=<Key ID de APIs/IOS/Key ID.txt>
ASC_ISSUER_ID=<Issuer ID de APIs/IOS/Issuer ID.txt>
ASC_PRIVATE_KEY_BASE64=<Coder Metadata App Manager.p8 codificado en base64>
```

El `gh` local tiene el token caducado, asi que estos secrets no se han podido cargar automaticamente desde esta sesion.
