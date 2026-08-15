# VoiceRecorder / AudioRecorder — hechos y decisiones

Última actualización: 2026-08-11.

Este documento distingue hechos observados de decisiones del propietario. Un hecho puede cambiar al evolucionar el repositorio; una decisión permanece vigente hasta que el propietario la sustituya expresamente.

## Hechos verificados

### F-001 — Identidad del repositorio — 2026-08-08

- Ruta: `C:\Users\dmkra\Documents\Codex Apps\Audio`.
- Rama: `agent/prepare-ios-test-build`.
- Commit actual: `cdcce91`; draft PR `#1` contra `main`.
- Remoto `origin`: `https://github.com/Krazel/AudioRecorder.git`.

### F-002 — Estado del árbol — 2026-08-08

- Hay cambios locales sin commit en CI y documentación durable para TestFlight interno que deben preservarse.
- `artifact/` permanece sin seguimiento y se excluyó expresamente. La política, el procesador por sonido y el manifiesto de privacidad ya forman parte del commit candidato.
- Android no presenta cambios en el árbol ni en el índice.

### F-003 — Línea base iOS — 2026-08-08

- iOS declara versión 1.0, build base 1 y deployment target iOS 16.
- Existen siete localizaciones coherentes: `ca/de/en/es/fr/it/pt`.
- El código local carga seis suscripciones mensuales de apoyo: 0,99 / 3 / 5 / 10 / 15 / 30.
- App Store Connect conserva históricamente nueve productos; los tres niveles 50/100/300 no forman parte de la preparación local 1.0.
- AdMob usa todavía identificadores de demostración de Google. El workflow local permite ese par exacto únicamente para una exportación `TestFlight Internal Only`; la ruta de producción sigue exigiendo IDs reales y rechaza los demos.

### F-004 — Validación disponible — 2026-08-08

- Han pasado las comprobaciones locales de manifiesto, localizaciones, capturas, plist, enlaces, estructura de concurrencia y puerta estática UMP/AdMob. Las siete tablas contienen las mismas 126 claves.
- No existe toolchain Apple en este equipo Windows. El commit `db0d870` sí compiló correctamente en macOS mediante GitHub Actions; las pruebas en dispositivo y el archive firmado siguen pendientes.

### F-005 — Preparación UMP/AdMob — 2026-08-08

- UMP está declarado como dependencia directa y el flujo local ejecuta actualización, formulario requerido y comprobación de `canRequestAds` antes de iniciar Mobile Ads o cargar un banner.
- Ajustes expone las opciones de privacidad solo cuando UMP las marca como requeridas.
- El App ID y el Banner ad unit ID se inyectan por separado. El archivo firmado verifica los valores archivados; la ruta `production` valida formato y rechaza el publicador demo, mientras `test` acepta únicamente el par oficial y fuerza TestFlight interno.
- El workflow firmado se detiene con Xcode o SDK iOS anteriores a la versión 26 y mantiene la validación externa y la subida desactivadas por defecto.
- Exige un número de build positivo explícito, inspecciona el archive y conserva IPA, archive y dSYM como artefactos temporales.
- `Info.plist` incluye los 50 SKAdNetwork IDs del ejemplo oficial de Google vigente el 2026-08-08.

### F-006 — Bloqueo externo AdMob — 2026-08-08

- El propietario tuvo que crear una cuenta nueva de AdMob y Google mantiene pendiente su verificación.
- Mientras dure la verificación no están disponibles los dos IDs reales ni la configuración/publicación definitiva de mensajes UMP/CMP.
- No se crearon recursos externos ni se inventaron identificadores.

### F-007 — Build macOS unsigned verificada — 2026-08-08

- Rama: `agent/prepare-ios-test-build`; commits `1c79d7d` y `db0d870`; draft PR `#1`.
- GitHub Actions run `31271758443` completó generación, compilación, empaquetado y artefacto con publicación omitida.
- IPA: 6.600.734 bytes; SHA-256 `EF4FBB659AC69EF99904BF88E19DF7143012E30FD74FDDB23446B79931C14C11`.
- Se verificaron ambos frameworks Google, manifiesto de privacidad, assets y siete idiomas.
- Los avisos de `allowBluetooth` y destino ambiguo quedaron corregidos. Permanece el aviso de orientaciones, ligado a la decisión pendiente sobre iPhone/iPad.

### F-008 — Firma y credenciales TestFlight — 2026-08-08

- GitHub tiene el environment `app-store-production` y los cuatro secrets Apple requeridos, cargados con autorización expresa sin mostrar sus valores. La Team API Key activa tiene rol Gestor de apps.
- App Store Connect se comprobó en vivo: app `6772278149`, bundle `com.dmkr.audio.B2X6D3A9J9`, cero builds, grupo interno `Testers` con un tester y un único usuario elegible. El build `1` está libre.
- El run 31275686032 validó secrets, toolchain, configuración test y dependencias, pero Xcode recibió HTTP 401 al consultar equipos y no obtuvo perfil App Store. La clave actual sí autentica contra la API pública y lee el Bundle ID; el bloqueo queda acotado a firma/provisioning automático.
- No se ejecutó validación Apple del IPA, upload ni distribución.
- La API lista un certificado IOS_DEVELOPMENT válido y un perfil IOS_APP_STORE caducado de otra app; no hay certificado/perfil de distribución reutilizable para VoiceRecorder.

## Decisiones vigentes

### D-001 — Plataforma exclusiva iOS — 2026-08-08

VoiceRecorder se completa primero y únicamente para iOS. Android queda fuera de alcance hasta una nueva orden expresa del propietario.

### D-002 — Excepción permanente de idiomas — 2026-08-08

Este proyecto conserva exactamente catalán, alemán, inglés, español, francés, italiano y portugués (`ca/de/en/es/fr/it/pt`). No se reduce a inglés y no se añaden idiomas nuevos sin una decisión posterior.

### D-003 — Cerebro permanente y delegación — 2026-08-08

Este chat mantiene el contexto durable, coordina VoiceRecorder y delega trabajo delimitado. El Brain general puede consultarlo y encargarle trabajo. Los turnos de coordinación deben cerrarse rápidamente mientras las tareas independientes continúan.

### D-004 — Propiedad única de implementación — 2026-08-08

Solo una tarea puede ser propietaria de implementación en cada momento. Lecturas, auditorías y pruebas no destructivas pueden ejecutarse en paralelo si no generan escrituras solapadas.

### D-005 — Puerta visual para pantallas nuevas — 2026-08-08

No se implementa ninguna pantalla nueva sin una imagen o mockup previamente aprobado por el propietario.

### D-006 — Monetización local de 1.0 — 2026-08-08

La escala preparada para 1.0 contiene seis niveles mensuales: 0,99 / 3 / 5 / 10 / 15 / 30. Todos conceden el mismo beneficio mientras el derecho está activo. Los niveles 50/100/300 quedan excluidos de la versión local 1.0.

### D-007 — Códigos manuales retenidos — 2026-08-08 (sustituida por D-032)

Esta decisión histórica queda sustituida por D-032 antes de la candidata pública 1.0 (6).

### D-008 — Publicación bajo autorización expresa — 2026-08-08

No publicar releases, subir builds, asociar suscripciones a revisión, enviar a App Review, aceptar contratos ni realizar acciones equivalentes sin autorización expresa y contemporánea del propietario. Compilar o validar no concede permiso para publicar.

### D-009 — Integridad del trabajo local — 2026-08-08

Preservar todos los cambios existentes. No borrar, revertir o reemplazar trabajo local sin autorización expresa en el momento y una verificación previa del objetivo exacto.

### D-010 — Beta interna antes de AdMob real — 2026-08-08 (sustituye la formulación anterior)

Se permite probar ahora con el par oficial de IDs demo de Google, exclusivamente en una build exportada como `TestFlight Internal Only`. Esa build no se reutiliza para TestFlight externo ni para clientes. Antes de cualquier candidata pública se generará un archive nuevo con IDs reales y mensajes UMP/CMP configurados y probados.

### D-011 — Consentimiento antes de anuncios — 2026-08-08

No se solicita ningún anuncio antes de que UMP permita hacerlo mediante `canRequestAds`. La aplicación debe ofrecer revisión o cambio de opciones de privacidad cuando UMP indique que corresponde.

### D-012 — Recursos de consola bajo autorización — 2026-08-08

La verificación de cuenta, el alta de la app/unidad publicitaria y la configuración o publicación de mensajes en AdMob son acciones externas. No se crean, publican ni sustituyen con datos inventados; tras el desbloqueo el propietario proporcionará los dos IDs o autorizará expresamente la acción concreta.

### D-013 — ATT separado de UMP — 2026-08-08

UMP y anuncios sin IDFA no implican solicitar seguimiento. No se añade ATT, `NSUserTrackingUsageDescription` ni un mensaje IDFA sin una decisión expresa posterior y su correspondiente revisión de privacidad y pruebas. Esa decisión posterior se tomó el 2026-08-13 y queda registrada en D-030 para la candidata 1.0 (6).

### D-014 — Dependencias publicitarias reproducibles — 2026-08-08

Google Mobile Ads queda fijado en 12.14.0 y UMP en 3.1.0 para la candidata actual. No se adopta una versión mayor sin generar el proyecto, compilar y ejecutar regresión en macOS/dispositivo. Los 50 SKAdNetwork IDs oficiales pueden mantenerse localmente sin activar ATT.

### F-009 — Recursos de distribución manual — 2026-08-09

- Apple creó el certificado `DISTRIBUTION` `2K3G3RTCS5` y el perfil `IOS_APP_STORE` `2J3LC3G5U8`/UUID `e8c5f848-9776-484a-a955-ee1196048faf` específicos de VoiceRecorder. El certificado y el perfil vencen en 2027-08-08.
- El perfil corresponde al equipo, bundle y certificado esperados, no contiene dispositivos y declara `get-task-allow=false`.
- El commit `66d3465` sustituyó el aprovisionamiento automático fallido por firma manual verificada. Los tres secretos de identidad todavía no se han transferido a GitHub y no se ha ejecutado ni subido una build nueva.

### D-015 — Firma de distribución correcta — 2026-08-09

El propietario autorizó crear todos los recursos Apple necesarios para firmar VoiceRecorder correctamente. Se usa un certificado Apple Distribution moderno y un perfil App Store exclusivo de la app; no se reutilizan perfiles caducados, no se revocan recursos previos y la subida a TestFlight permanece separada de la preparación y verificación de la build.
### F-010 — Build firmada 1 verificada — 2026-08-09

- El run `31282363769` del commit `d02ec93` completó archive y exportación firmados para iOS 1.0 (build 1) con anuncios demo y barrera `TestFlight Internal Only`.
- El IPA pasó codesign estricto, perfil/certificado/equipo/bundle, siete idiomas, AdMob demo y comprobación dSYM. SHA-256 interno: `a21721c4b34203cc3ecb5387a8eb0760f09f9aaf84bfe6cdaacf0642b8d772ab`.
- Validación con App Store Connect y upload fueron omitidos. Los materiales temporales de firma se limpiaron.

### D-016 — Custodia de la identidad de firma — 2026-08-09

El propietario autorizó transferir la identidad a los secretos cifrados del environment GitHub tras ser informado del riesgo. El workflow solo la decodifica en `$RUNNER_TEMP`, usa un llavero efímero, valida certificado y perfil, y elimina el material temporal con `always()`. Ninguna clave privada se versiona ni se incluye en artefactos o registros.
### D-017 — VoiceRecorder 1.0 es iPhone-only — 2026-08-09

La versión 1.0 se distribuye únicamente para iPhone y conserva orientación vertical. Esta decisión sigue la definición histórica del MVP, textos, artefactos y capturas existentes, todos exclusivos de iPhone; evita declarar soporte iPad no diseñado ni probado. Cualquier ampliación futura a iPad requerirá diseño, capturas, cuatro orientaciones para multitarea y pruebas específicas.
### F-011 — Build 1 procesada para TestFlight interno — 2026-08-09

- El run `31283035466` subió iOS 1.0 (1) con anuncios demo como `TestFlight Internal Only`; Apple la procesó con estado `VALID` y audiencia `INTERNAL_ONLY`.
- El grupo interno `Testers` distribuye automáticamente todas las builds elegibles (`hasAccessToAllBuilds=true`) y contiene un tester. La build 1 permanece bloqueada con `internalBuildState=MISSING_EXPORT_COMPLIANCE`; no se respondió ninguna declaración legal. No se envió a App Review ni a testers externos.
- App Store Connect confirma marketing version `1.0` y build number `1`. El campo `usesNonExemptEncryption` sigue sin declarar.

### F-012 — Baseline y propuestas de icono — 2026-08-09

- El asset de producción actual es un icono cósmico con átomo/órbitas y permanece sin cambios.
- Existen cuatro previews originales y sin texto en `docs/icon-proposals/`: record-wave, mic-arcs, ribbon-dot y meter-dot. La recomendación técnica provisional es `03-ribbon-dot.png`.
- Las páginas públicas de privacidad y soporte responden HTTP 200. El código iOS local y las siete fichas de tienda usan ya las URLs limpias; la build 1 todavía contiene el enlace histórico de privacidad de GitHub.

### D-018 — Aprobación visual antes de cambiar el icono — 2026-08-09

El icono de producción no se reemplaza hasta que el propietario apruebe expresamente una imagen concreta. Las propuestas son únicamente previews; tras la aprobación se preparará el asset final 1024 x 1024 y se generará una build nueva, manteniendo la versión visible 1.0 e incrementando el número de build.

### F-013 — Build 1 activa en TestFlight interno — 2026-08-09

- El propietario confirmó que VoiceRecorder no implementa cifrado propio/no exento. App Store Connect refleja `usesNonExemptEncryption=false`, `internalBuildState=IN_BETA_TESTING` y relación efectiva con el grupo interno `Testers`.
- `native-ios/Resources/Info.plist` declara `ITSAppUsesNonExemptEncryption=false` para evitar repetir la pregunta en builds futuras mientras la implementación no cambie.
- La build sigue marcada `INTERNAL_ONLY`; `externalBuildState=NOT_APPLICABLE`. No hubo App Review ni distribución externa.

### D-019 — Clasificación de cifrado — 2026-08-09

El propietario confirma que la app no usa cifrado propio/no exento. Se declara `usesNonExemptEncryption=false` para la build 1 y `ITSAppUsesNonExemptEncryption=false` para builds futuras. Si se añade criptografía propia o cambia el uso de cifrado, esta decisión debe reauditarse antes de distribuir.

### D-020 — Icono iOS variante 3 aprobado — 2026-08-09

El propietario aprueba `03-ribbon-dot.png` como icono iOS. El asset de producción se sustituye por una exportación opaca 1024 x 1024. El icono cósmico anterior se conserva byte por byte en `docs/icon-proposals/00-original-cosmic-backup.png`. Esta decisión sustituye la espera visual de D-018.

### F-014 - Build 2 activa en TestFlight interno - 2026-08-09

- El run `31285797462` del commit `a237172` subio iOS 1.0 (2) con anuncios demo como `TestFlight Internal Only`.
- Apple la proceso como `VALID`; esta `IN_BETA_TESTING`, con audiencia `INTERNAL_ONLY`, cifrado no exento declarado en falso y relacion efectiva con el grupo interno `Testers`.
- La build incluye el icono variante 3 aprobado, las URLs limpias de privacidad y soporte y la declaracion persistente de cifrado.
- No se habilito TestFlight externo, no se envio a Beta App Review o App Review y no se publico en App Store.

### D-021 - Titulo localizado de la ficha - 2026-08-09

Se conserva la localizacion del nombre de la ficha de App Store/TestFlight para los siete idiomas existentes. En espanol puede mostrarse `Grabadora de Voz Pro - Audio K`; esto es intencional y depende del idioma o storefront. No se altera el nombre bajo el icono de la app, que permanece en ingles en las siete localizaciones actuales.

### D-022 - Prueba interna del icono blanco - 2026-08-09

El propietario decide probar en TestFlight interno una variante del icono 3 con fondo blanco. El icono negro anterior se conserva byte por byte y puede restaurarse. Esta prueba visual no decide por si sola el icono de la candidata publica.

### F-015 - Build 4 activa en TestFlight interno - 2026-08-09

- El commit `dafe2d5` contiene la variante blanca y la copia negra.
- El run `31288585155` subio iOS 1.0 (4) como `TestFlight Internal Only` con anuncios demo.
- Apple la proceso como `VALID`, `IN_BETA_TESTING` e `INTERNAL_ONLY`; esta disponible para el grupo privado `Testers`.
- No se envio a revision ni se publico en App Store.

### D-023 - Siete niveles de apoyo para iOS 1.0 - 2026-08-09 (sustituye D-006)

El propietario incorpora un séptimo nivel mensual de 49,99 EUR. La escala vigente es 0,99 / 3 / 5 / 10 / 15 / 30 / 49,99. Todos los niveles conceden exactamente el mismo beneficio, retirar anuncios mientras el derecho esté activo, y se configuran en el mismo nivel de grupo en App Store Connect. La app no presenta los importes altos como funciones superiores.

### F-016 - Limpieza y alta definitiva de suscripciones - 2026-08-09

- Por autorización expresa del propietario se eliminaron de App Store Connect los productos heredados `com.dmkr.audio.support.monthly.4999`, `.9999` y `.29999`. Apple no permite restaurarlos ni reutilizar esos identificadores.
- Se creó `com.dmkr.audio.support.monthly.50`, referencia interna `Audio K Support Monthly 50 v2`, recurso Apple `6799674367`, duración mensual, precio base 49,99 EUR y disponibilidad mundial.
- Los siete productos vigentes están en nivel 1 y sus 49 localizaciones remotas coinciden con el manifiesto.

### F-017 - Preparación externa previa a la candidata pública - 2026-08-09

- Las páginas de producto, soporte y privacidad están públicas. Soporte muestra `coderappskrazel@gmail.com`; `https://krazel.github.io/app-ads.txt` responde con la línea real del publicador de AdMob.
- App Store Connect tiene precio gratuito, 175 territorios, clasificación 4+, publicación manual, contratos gratuito/pago activos, banco activo y fiscalidad estadounidense activa.
- AdMob conserva los IDs reales correctos, pero la app aún no puede enlazarse con App Store hasta que exista ficha pública. El mensaje europeo permanece en borrador y no se ha publicado.
- Permanecen sin resolver las declaraciones legales de derechos de contenido, DSA rechazado y DAC7, además del teléfono de revisión y una captura real actual de las siete suscripciones.

### D-024 - Puertas finales de publicación - 2026-08-09

La build pública siguiente será 1.0 (5), con IDs reales de AdMob. Puede compilarse y validarse sin upload para comprobar el archive. Publicar el mensaje UMP, subir la build, asociar build/suscripciones, responder declaraciones legales o pulsar `Añadir a revisión`/`Enviar a revisión` requieren autorización contemporánea del propietario. La publicación final de App Store permanece manual incluso después de una eventual aprobación de Apple.

### F-018 - Limpieza de revisión y cumplimiento externo - 2026-08-09

- Por decisión del propietario, las siete suscripciones no conservan capturas privadas ni notas opcionales de revisión. Se eliminaron mediante la API oficial las cinco capturas antiguas que aún existían; las otras dos ya estaban vacías. No se creó ni subió ninguna captura simulada.
- App Store Connect permite `Añadir a revisión` para la suscripción de 49,99 EUR sin captura privada. Las capturas públicas de la ficha, la descripción, palabras clave y URLs de soporte no forman parte de esta limpieza.
- Derechos de contenido declara que la app accede a contenido de terceros y dispone de los derechos necesarios. DAC7 declara que ninguna app ofrece servicios personales y figura activo.
- DSA está seleccionado como comerciante. Apple exige documentación identificativa para verificar la información pública de contacto; no se inventó ni cargó ningún documento.
- El mensaje de Reglamentos europeos de AdMob está publicado para Voice Recorder en inglés y los otros seis idiomas. La app conserva UMP y el acceso de revocación/opciones de privacidad.
- La versión 1.0 está configurada para publicación manual después de la aprobación de Apple.

### F-019 - Build pública 1.0 (5) subida y validada - 2026-08-09

- Con autorización expresa del propietario se creó y publicó el commit `213f86b` en `agent/prepare-ios-test-build` y se ejecutó el run `31322723025` con `ad_configuration=production`, validación Apple y upload activados.
- El workflow superó firma manual, archive, comprobación de identidad 1.0 (5), IDs AdMob reales/no demo, siete idiomas, iPhone-only, exportación y validación. La subida terminó correctamente y no ejecutó App Review.
- App Store Connect muestra el recurso `2dfc3587-512f-41ff-ae92-998d78e53a9a` como binario validado, `APP_STORE_ELIGIBLE` y `Lista para enviar`; cifrado no exento `No`, iOS mínimo 16.0 y familia iPhone.
- La build 5 está visible para el grupo interno `Testers`, pero no está seleccionada en la versión 1.0 ni incluida en una revisión. La build 4 demo permanece separada como beta interna.
- La publicación final sigue siendo manual. Completar DSA, seleccionar build/suscripciones y pulsar `Añadir a revisión` o `Enviar a revisión` continúan siendo pasos separados.
- Artefactos privados: `AudioRecorder-production-ipa-build-5` (`sha256:61dda1c3a4788f6d6c5ccacd9c90aa0e8900e4a7986e93c3ca62bbf2076e44bb`) y `AudioRecorder-production-archive-build-5` (`sha256:138859a63c6353ac2753814bbcd06e4c5cf5a765e836970cbfd96d3a81a9b870`), con caducidad 2026-08-16.

### D-025 - La aprobación visual bloquea solo el acabado final - 2026-08-09

La aprobación visual expresa sigue siendo obligatoria antes de fijar el layout final, el arte o icono final, las capturas de tienda, las animaciones visuales principales o la experiencia visual definitiva. Esta puerta no impide avanzar en motor, reglas, datos, contenido, arquitectura, navegación interna, persistencia, pruebas, build/CI, privacidad, tienda, documentación ni prototipos internos provisionales. Los prototipos deben identificarse como no definitivos y las piezas estructurales o técnicas separables deben delegarse mientras se preparan las propuestas visuales. Esta decisión amplía y sustituye la interpretación restrictiva de D-005; no altera las aprobaciones visuales específicas ya registradas.

### D-026 - Patrón de apoyo voluntario - 2026-08-09

VoiceRecorder mantiene el apoyo voluntario dentro de Ajustes y conserva la aplicación utilizable gratuitamente. Los siete niveles mensuales son equivalentes: todos reconocen al usuario como supporter, agradecen su ayuda al mantenimiento y las actualizaciones y retiran anuncios mientras el derecho esté activo; no bloquean funciones principales ni se presentan como donaciones. Precio, duración, renovación, cancelación, restauración, privacidad y términos deben permanecer visibles antes de comprar. Las reseñas de App Store se gestionan por separado. Cualquier producto nuevo, configuración remota, build o envío de IAP a revisión continúa sujeto a autorización roja expresa.

### D-027 - Skill obligatoria para lanzamientos iOS - 2026-08-09

Toda organización o verificación de TestFlight, App Store Connect, App Review, AdMob, StoreKit/IAP, supporter subscriptions, privacidad, soporte, firma, workflows de subida, capturas, icono o checklist de publicación debe aplicar la skill durable `ios-app-launch` del Brain y sus referencias pertinentes. Esta guía estandariza el proceso, pero no autoriza crear productos, usar secretos nuevos, subir builds, aceptar acuerdos, enviar IAP o la app a revisión ni publicar; cada acción roja conserva su puerta de autorización expresa y contemporánea.

### D-028 - Custodia canonica de aprobaciones visuales - 2026-08-11

`design/APPROVALS.md` gobierna las referencias visuales completas aprobadas del producto iOS. Cada pantalla o estado registra ruta, dispositivo o lienzo, orientacion, idioma, fecha y SHA-256. Las propuestas no son maestras; una sustitucion aprobada se incorpora como nueva referencia vigente y la anterior se conserva marcada como reemplazada. Las imagenes de tienda toman direccion de arte de estas maestras, pero la captura base final siempre debe proceder de la build real y enlazarse con su build y referencia. La ausencia de una aprobacion se registra como tal y nunca se rellena por inferencia.

### D-029 - Minimizacion y separacion de informacion publica - 2026-08-11

La build, sus SDKs y `docs/IOS_DATA_INVENTORY.md` son la fuente de verdad para privacidad y App Store Privacy. Solo se solicitan permisos y campos imprescindibles. El contacto publico se limita al alias de soporte; nombre completo, domicilio, telefono, cuentas personales, repositorio y contacto privado de App Review no se publican salvo obligacion concreta de Apple o de la ley. Los campos opcionales permanecen vacios si no cumplen una funcion real. Esta minimizacion no permite omitir AdMob, UMP, StoreKit ni sus datos reales. La declaracion DSA trader es una obligacion territorial separada y debe resolverse verazmente en el canal de Apple.

### F-020 - Exposicion historica del contacto privado - 2026-08-11

El commit remoto `213f86b` incluyo en `STATUS.md` el nombre completo y telefono privados usados para App Review. Con autorizacion expresa del propietario, se reconstruyeron ese commit y sus dos descendientes, se verifico que la nueva historia no contiene esos datos y se actualizo con `--force-with-lease` la rama `agent/prepare-ios-test-build` desde `31a1f67` hasta `1a7678f`. `refs/pull/1/head` tambien apunta a `1a7678f`. La reescritura elimina referencias activas de rama/PR, aunque GitHub puede conservar temporalmente caches accesibles por el SHA antiguo; una solicitud de purga a soporte seria una accion externa adicional.

### F-021 - Politica y soporte publicos minimizados - 2026-08-11

El repositorio compartido `krazel.github.io` publico el commit `3371a6d` con cambios limitados a `audio-recorder/privacy/index.html` y `audio-recorder/support/index.html`. Ambas URLs responden HTTPS 200, usan el nombre exacto `Voice Recorder Pro - Audio K`, publican solo el alias `coderappskrazel@gmail.com` y describen almacenamiento local, StoreKit, AdMob/UMP, controles y retencion sin servicios hipoteticos. No se tocaron los cambios locales ajenos de Tarot ni App Store Connect.

### D-030 - ATT y tracking condicionado para la candidata 1.0 (6) - 2026-08-13

Por decisión expresa posterior del propietario, la ruta transitoria sin tracking no se entrega. La candidata 1.0 (6) conserva UMP y anuncios reales, solicita ATT después del flujo UMP y espera su resolución antes de iniciar Google Mobile Ads. Si el usuario autoriza, AdMob puede usar IDFA para publicidad personalizada y medición; App Store Privacy declara las categorías aplicables como usadas para tracking. Si rechaza o tiene el permiso restringido, la app sigue plenamente utilizable y AdMob no recibe IDFA ni puede realizar tracking. El prompt, su orden y ambos resultados deben probarse desde instalaciones limpias antes del reenvío.

### D-031 - Captura privada obligatoria para las primeras suscripciones - 2026-08-13

La decisión anterior de dejar vacía la captura opcional de revisión queda sustituida para este envío porque Apple la exigió expresamente bajo Guideline 2.1(b). Se usa únicamente evidencia real de la build: `store/app-review/build-5/subscriptions-seven-levels-real.png`, extraída del vídeo físico del propietario y registrada en `design/APPROVALS.md` como evidencia no aprobada, no como arte público. Debe cargarse en los siete productos antes de añadirlos a revisión; no se admite ninguna captura inventada.

### D-032 - StoreKit como única vía para retirar anuncios - 2026-08-15

La decisión D-007 queda sustituida para la candidata pública 1.0 (6). Antes de hacer público el repositorio se retiran de iOS los códigos manuales y su acceso oculto: quedarían expuestos en el código fuente y constituyen un mecanismo propio de desbloqueo incompatible con la revisión de compras integradas. Desde esta candidata, los anuncios solo se retiran mediante una suscripción verificada por StoreKit. Al actualizar, cualquier desbloqueo manual histórico se invalida de forma explícita; una suscripción vigente se conserva o restaura normalmente.

### F-022 - Repositorio público y build 6 validada - 2026-08-15

Tras una auditoría de ramas, etiquetas e historia alcanzable, `Krazel/AudioRecorder` pasó a visibilidad pública sin exponer secretos. La candidata iOS 1.0 (6) se generó desde `fdcdb3f` mediante el run `31850317905`; superó firma, archive, comprobaciones ATT/AdMob, validación de Apple y upload. Apple la procesa como `VALID` y la versión conserva publicación manual.

### F-023 - Correcciones remotas del rechazo y envío conjunto - 2026-08-15

Se sincronizaron las siete descripciones con EULA, se vaciaron subtítulos y texto promocional, se eliminaron las terceras capturas públicas con referencias a `free`/`gratis`, se corrigió App Privacy y se cargó la captura privada real en los siete productos. Tras una primera asociación separada, el propietario autorizó cancelar y rearmar el envío. La submission `7e9fd837-4419-498a-a40a-7e8fbbd4422e` contiene exactamente la versión iOS 1.0 (6), la versión del grupo y las siete versiones de suscripción. La versión quedó posteriormente `REJECTED`/`INVALID_BINARY`; el grupo y las siete suscripciones permanecen `READY_FOR_REVIEW`. La publicación final permanece manual.

### D-033 - La declaración IDFA debe acompañar a ATT - 2026-08-15

Toda versión pública que conserve ATT y permita a AdMob usar IDFA cuando el usuario autoriza debe declarar `usesIdfa=true` en App Store Connect y comprobar que el valor ha quedado persistido antes de enviarse. Esta declaración remota forma parte del preflight obligatorio junto con `NSUserTrackingUsageDescription`, App Privacy y la prueba del flujo ATT. El antiguo recurso detallado `idfaDeclarations` está retirado y no debe inventarse una pantalla o configuración que la interfaz vigente ya no ofrece. Si una versión futura elimina por completo el uso de IDFA, la declaración solo podrá cambiarse después de reconciliar código, SDKs, política y App Privacy.

### F-024 - `INVALID_BINARY` afecta al envío, no al archivo validado - 2026-08-15

El primer envío conjunto de 1.0 (6) quedó en `INVALID_BINARY` mientras `appStoreVersions.usesIdfa` era `null`, aunque el binario incluye ATT y Google Mobile Ads. Apple mantuvo la build 6 `VALID`, `APP_STORE_ELIGIBLE`, no caducada y sin diagnósticos de carga. Se corrigió el booleano a `true`, pero los reenvíos posteriores también regresaron a `INVALID_BINARY`. El aviso técnico posterior identificó la causa real como `ITMS-91064`: el manifiesto raíz combinaba `NSPrivacyTracking=true` con `NSPrivacyTrackingDomains=[]`, configuración que Apple TN3181 declara inválida. No se alteró Android y la publicación sigue siendo manual.

### D-034 - Manifiesto raíz sin dominios de tracking propios - 2026-08-15

La candidata 1.0 (7) declara `NSPrivacyTracking=false` en el manifiesto de la app y elimina `NSPrivacyTrackingDomains`. No se inventan dominios de Google: Google Mobile Ads y UMP incluyen sus propios manifiestos, mientras ATT, la declaración remota `usesIdfa=true` y App Privacy siguen describiendo el uso condicionado de IDFA por el SDK. CI debe rechazar cualquier manifiesto con `tracking=true` y dominios ausentes/vacíos, o con dominios presentes sin `tracking=true`, tanto en fuente como en archive e IPA.

### F-025 - Corrección `ITMS-91064` publicada en la rama - 2026-08-15

El commit `324ef91` contiene la corrección del manifiesto y el validador semántico de todos los `PrivacyInfo.xcprivacy` en fuente, archive e IPA exportada. Se subió a `origin/agent/prepare-ios-test-build`; Android y `artifact/` quedaron intactos.

### F-026 - Build 7 validada y envío completo reenviado - 2026-08-15

El run `31887343289`, desde el commit `3e74d38`, superó firma, archive, validación semántica de privacidad en fuente/archive/IPA, validación de Apple y upload. Apple procesó 1.0 (7), recurso `744404c3-5503-4e64-a796-bef3ce86cffe`, como `VALID` y `APP_STORE_ELIGIBLE`. La build 7 sustituyó a la 6 en la versión 1.0; `usesIdfa=true` y publicación manual permanecen vigentes. Se resolvió el único ítem rechazado y se reenvió la submission existente `7e9fd837-4419-498a-a40a-7e8fbbd4422e` con sus nueve elementos originales. App Store Connect muestra la app 1.0 (7), el grupo y las siete suscripciones en `WAITING_FOR_REVIEW`. La app no está publicada.
