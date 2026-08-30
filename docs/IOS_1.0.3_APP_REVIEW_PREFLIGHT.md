# VoiceRecorder iOS 1.0.3 — preflight de App Review

Fecha de preparación: 2026-08-30

Estado: **preparado pero bloqueado; no enviar a App Review**

## Binario disponible

| Comprobación | Evidencia | Estado |
|---|---|---|
| Fuente de la corrección | commit binario `3f3c9cf` | pasa |
| XCTest y Release para iPhone | GitHub Actions `33284953418` | pasa |
| Archive, firma, privacidad, IPA y validación Apple | GitHub Actions `33285208649` | pasa |
| Procesamiento Apple | build `702f442b-7c5e-4977-a3b4-6f08aa99cbde`, `VALID` | pasa |
| Audiencia | `INTERNAL_ONLY`; externo `NOT_APPLICABLE` | pasa para QA interno |
| TestFlight | `IN_BETA_TESTING`, grupo privado `Testers`, dos testers | pasa |
| Configuración de anuncios | IDs demo oficiales de Google | bloquea producción |

La build 1.0.3 (1) no es la candidata de App Review y no debe seleccionarse en
la versión de tienda. Sirve exclusivamente para comprobar la rotación continua
en hardware real.

## Metadata preparada

- App Store version 1.0.3: `PREPARE_FOR_SUBMISSION`.
- Publicación: `MANUAL`.
- Marketing URL persistida en las siete localizaciones:

  `https://krazel.github.io/audio-recorder/`
- Localizaciones verificadas: `ca`, `de-DE`, `en-US`, `es-ES`, `fr-FR`, `it`,
  `pt-PT`.
- `app-ads.txt`, Marketing URL, Privacy y Support deben responder públicamente
  antes del preflight final. `app-ads.txt` y Marketing URL respondieron HTTP
  200 el 2026-08-30.

## Puertas bloqueantes

### 1. QA físico de grabación

El propietario debe confirmar como mínimo:

- modo `Todo`, pantalla activa: superar el primer corte de 5 minutos y obtener
  dos archivos reproducibles sin que la sesión se detenga;
- modo `Todo`, pantalla bloqueada/background: al menos tres cortes consecutivos
  y 20 minutos de grabación;
- repetir el caso anterior conectado a corriente y sin ella;
- modo `Por sonido`: dos rotaciones con voz/silencio y conservación de la cola
  final;
- auriculares/Bluetooth: conectar y retirar durante una grabación;
- llamada/Siri/alarma: interrupción, conservación del fragmento y reanudación;
- background/foreground y bloqueo/desbloqueo alrededor del minuto 5;
- Stop solicitado frente a cualquier parada inesperada, revisando el código de
  diagnóstico local;
- grabación con poco espacio controlado, sin eliminar segmentos ya cerrados.

Una parada en el primer corte o una rotación con archivo corrupto falla la
puerta y prohíbe avanzar.

### 2. AdMob de producción

Estado actual: bloqueado. La cuenta/app/IDs reales no están activos y
verificables en vivo y AdMob todavía no reconoce Developer Website. La presencia
pública de `app-ads.txt` no sustituye la confirmación dentro de AdMob.

Antes de producción deben verificarse en la consola:

- cuenta activa;
- app iOS correcta y Developer Website detectado;
- `app-ads.txt` autorizado;
- App ID y banner unit reales pertenecen a esa app;
- mensaje europeo activo y mensaje IDFA sin publicar;
- flujo EEA rechazo/aceptación, ATT denegar/permitir, no EEA, reapertura y
  retirada posterior de consentimiento.

Después se compilará 1.0.3 build 2 con IDs reales. Nunca reutilizar la build 1
ni enviar una build demo a App Review.

### 3. Preflight contra el binario de producción exacto

La futura 1.0.3 (2) debe repetir:

- XCTest, archive y validación Apple;
- informe agregado de privacidad y comparación con
  `docs/IOS_DATA_INVENTORY.md` y App Privacy;
- coherencia de ATT/UMP/IDFA y `usesIdfa=true` si el binario realiza tracking;
- verificación de que el rechazo europeo no dispara ATT;
- estado y presentación de las siete suscripciones, restauración y gestión;
- scan de precio en nombre, subtítulo, keywords, texto promocional, capturas y
  las siete localizaciones;
- Privacy, Support, EULA, screenshots y Review Notes coherentes con la build;
- exactamente una versión de app, el grupo y las siete suscripciones en la
  submission cuando corresponda;
- build seleccionada 1.0.3 (2) y publicación `MANUAL`.

## Fuentes oficiales revalidadas

- Apple, User Privacy and Data Use: la app debe declarar también la conducta de
  SDKs de terceros y obtener ATT antes de tracking/IDFA.
- Apple, App Review Guidelines: metadata completa y precisa, servicios activos
  y explicación de funciones/compras no obvias antes de enviar.
- Apple, Submit an In-App Purchase y View/Edit In-App Purchase Information:
  productos requeridos deben estar configurados e incluidos conforme al estado
  real de la submission.

No se ejecutará la creación o envío de una submission hasta superar las puertas
físicas y de producción anteriores.
