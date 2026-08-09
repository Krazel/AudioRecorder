# VoiceRecorder / AudioRecorder — estado actual

Última revalidación: 2026-08-09.

> Estado vigente: iOS 1.0 build 5, con IDs reales de AdMob y siete niveles mensuales de apoyo, está subida y validada por Apple como `APP_STORE_ELIGIBLE` / `Lista para enviar`. Sigue sin seleccionarse en la versión 1.0 y no se ha añadido ni enviado nada a App Review. La publicación final permanece manual. La build 4 con anuncios demo continúa disponible en TestFlight interno. Las secciones cronológicas anteriores son históricas cuando contradigan esta actualización.

## Actualización de cierre para candidata pública - 2026-08-09

- El repositorio sigue en `agent/prepare-ios-test-build`; Android no tiene diferencias y `artifact/` permanece sin seguimiento e intacto.
- El código y el manifiesto iOS contienen exactamente siete productos mensuales: 0,99 / 3 / 5 / 10 / 15 / 30 / 49,99. Todos muestran `Sin anuncios` y `Apoyo mensual` en español, con equivalentes en `ca/de/en/es/fr/it/pt`, y conceden el mismo derecho mientras están activos.
- App Store Connect contiene exactamente esos siete productos en el grupo `22136463`. El nuevo nivel de 49,99 usa `com.dmkr.audio.support.monthly.50` y recurso Apple `6799674367`. Los productos heredados 50/100/300 anteriores se eliminaron por autorización expresa del propietario y sus identificadores no pueden reutilizarse.
- Los siete productos están configurados en el mismo nivel 1, como exige su servicio equivalente. Las 49 localizaciones remotas coinciden con `store/store-manifest.json`; el nuevo nivel está disponible en los 175 territorios y su precio base en España es 49,99 EUR.
- La ficha 1.0 conserva publicación manual, precio gratuito y disponibilidad mundial. Marketing y soporte apuntan a `https://krazel.github.io/audio-recorder/` y `/support/`; la política apunta a `/privacy/`.
- La web pública ya muestra el correo `coderappskrazel@gmail.com`. El `app-ads.txt` raíz responde 200 con el publicador real `pub-3425091654264901`.
- App Store Connect tiene clasificación 4+, acuerdos gratuito y de pago activos, banco activo y formularios fiscales activos. Mac con Apple Silicon y Vision Pro están deshabilitados; la app sigue siendo solo iPhone.
- Los datos obligatorios de contacto de App Review están guardados de forma privada en App Store Connect y no se reproducen en el repositorio. El contacto público se limita al alias `coderappskrazel@gmail.com`.
- Las siete suscripciones están sin notas opcionales y sin capturas privadas de revisión. La API oficial eliminó las cinco capturas antiguas que aún existían; las otras dos ya estaban vacías. App Store Connect mantiene habilitado `Añadir a revisión` sin esas capturas.
- AdMob conserva los IDs reales `ca-app-pub-3425091654264901~2340753104` y `ca-app-pub-3425091654264901/5497133550`. La app aún figura `Debe revisarse` porque todavía no puede enlazarse a una ficha pública. El mensaje europeo UMP está publicado, asociado a Voice Recorder y cubre inglés más los otros seis idiomas.
- Derechos de contenido está guardado como contenido de terceros con los derechos necesarios. DAC7 está activo con la respuesta de que ninguna app ofrece servicios personales. DSA está declarado como comerciante, pero Apple exige cargar documentación identificativa para verificar la dirección y continúa pendiente de esa acción humana.
- Validación local actual: manifiesto JSON, plist XML, 50 SKAdNetwork IDs, siete IDs coincidentes entre Swift/manifiesto, 127 claves idénticas en las siete localizaciones, scripts Node y `git diff --check` correctos. La puerta UMP/AdMob y las correcciones estructurales de segundo plano/rendimiento permanecen presentes. La prueba sostenida en iPhone sigue pendiente.

La candidata pública se generó desde el commit `213f86b` mediante el run `31322723025`. Pasaron firma, archive, verificación, exportación, validación de Apple y upload. Apple muestra build `2dfc3587-512f-41ff-ae92-998d78e53a9a`, versión 1.0 (5), binario validado, iPhone, iOS 16+, siete idiomas y cifrado no exento `No`. Los artefactos privados se conservan siete días. Próximo paso humano: completar la verificación documental DSA. Después, seleccionar la build 5 y las siete suscripciones para la versión 1.0 y revisar el envío; no se ha ejecutado ninguna de esas acciones.

## Resumen operativo

- Proyecto en cierre y auditoría del candidato iOS 1.0 (RC-001). La prioridad inmediata es una beta restringida a TestFlight interno con anuncios oficiales de prueba; AdMob real queda para una build pública posterior.
- Repositorio en agent/prepare-ios-test-build, con la preparación de firma publicada hasta fa4a051 en origin/agent/prepare-ios-test-build; draft PR #1 abierto contra main.
- `origin` apunta a `https://github.com/Krazel/AudioRecorder.git`.
- El workflow firmado, el script de secrets y la documentación de TestFlight interno están publicados en la rama de la PR. artifact/ sigue sin seguimiento y debe preservarse.
- `artifact/` conserva binarios históricos sin seguimiento y no forma parte del candidato. La build GitHub Actions `31271758443` valida el commit `db0d870` de la rama `agent/prepare-ios-test-build`.
- Android existe históricamente, pero su estado y sus diffs de trabajo e índice están vacíos. Permanece fuera de alcance.

## Estado iOS verificado

- Versión de marketing 1.0, build base 1, deployment target iOS 16.
- Idiomas conservados: `ca/de/en/es/fr/it/pt`; las siete tablas tienen las mismas 126 claves.
- Seis suscripciones mensuales locales: 0,99 / 3 / 5 / 10 / 15 / 30, con el mismo beneficio de retirar anuncios mientras exista derecho activo.
- Los códigos manuales ocultos permanecen por decisión expresa del propietario.
- La pantalla de apoyo muestra precio localizado de StoreKit, periodicidad mensual, renovación/cancelación, restauración, gestión de suscripción, Política de privacidad y EULA estándar de Apple.
- StoreKit recalcula derechos tras actualizaciones de transacción para no invalidar por error un desbloqueo manual vigente.
- El modo por sonido copia el buffer del tap y realiza análisis y escritura en una cola serial dedicada; la recuperación conserva el estado del segmento y un fallo de escritura detiene la grabación de forma veraz.
- `PrivacyInfo.xcprivacy` declara `CA92.1` para preferencias privadas y `C617.1` para metadatos de archivos del contenedor.
- UMP solicita una actualización en cada arranque, presenta el formulario si es necesario y no inicializa Mobile Ads ni crea el banner hasta que `canRequestAds` sea verdadero. La inicialización y la carga tienen guardas contra duplicados.
- Ajustes muestra `Opciones de privacidad` únicamente cuando UMP devuelve que son obligatorias; la presentación se inicia solo por una acción explícita del usuario.
- Los IDs de demostración de Google permanecen como valores locales para desarrollo/unsigned. `Info.plist` y el código admiten inyección separada del App ID y del Banner ad unit ID reales.
- `Info.plist` contiene los 50 `SKAdNetworkIdentifier` del ejemplo oficial de Google vigente el 2026-08-08; esta preparación no activa ATT.
- Google Mobile Ads queda fijado exactamente en 12.14.0 y UMP en 3.1.0 para que la resolución sea reproducible; el salto mayor a GMA 13 se reserva para compilación y regresión en Mac.
- El workflow firmado ofrece dos configuraciones explícitas: `test`, con el par demo oficial y exportación `TestFlight Internal Only`; y `production`, con secretos AdMob reales y rechazo del publicador demo.
- La configuración `test` exige confirmación adicional antes de cualquier upload y la opción de exportación de Apple impide usar esa build para TestFlight externo o para clientes. La configuración pública debe generar un archive nuevo con IDs reales.
- La build firmada exige un número positivo explícito, inspecciona identidad/versión/build, firma, provisioning, recursos, siete idiomas, familia de dispositivos, manifiesto y dSYM; conserva IPA y `.xcarchive` durante siete días.
- La validación con App Store Connect y la subida son opciones independientes, ambas desactivadas por defecto.
- Los workflows usan versión 1.0. Publicar una release unsigned o subir a App Store Connect requiere una opción manual explícita; `upload_to_app_store` permanece desactivado por defecto.

## Comprobaciones locales completadas

- JSON del manifiesto de tienda, plist y YAML parsean correctamente.
- Código y manifiesto coinciden exactamente en los seis productos y siete localizaciones.
- Todas las claves `L(...)` detectables existen en los siete idiomas.
- Las 21 capturas iOS declaradas existen y miden 1290 × 2796.
- La estructura estática confirma que análisis/escritura del modo por sonido no se envían al actor de interfaz.
- La revisión estática confirma un único arranque de Mobile Ads, una única carga inicial por instancia de banner, dependencia UMP directa y ambas operaciones detrás de `canRequestAds`.
- `Info.plist`, `PrivacyInfo.xcprivacy` y el JSON de tienda parsean correctamente; los siete archivos de traducción contienen exactamente las mismas 126 claves.
- Los 50 identificadores SKAdNetwork son únicos y coinciden en orden con la lista oficial revisada; las versiones SPM están fijadas exactamente.
- `git diff --check` no detecta errores.
- La build macOS unsigned `31271758443` generó el proyecto, resolvió GMA 12.14.0/UMP 3.1.0, compiló Swift, empaquetó y subió el artefacto privado; la publicación de release quedó omitida.
- La IPA final mide 6.600.734 bytes y tiene SHA-256 `EF4FBB659AC69EF99904BF88E19DF7143012E30FD74FDDB23446B79931C14C11`. Contiene GoogleMobileAds, UserMessagingPlatform, `PrivacyInfo.xcprivacy`, assets y las siete localizaciones.
- Android se revalidó sin cambios.
- Este Windows no dispone de toolchain Apple, pero el mismo commit ya compila en el runner macOS. Permanecen pendientes archive firmado, privacy report agregado y pruebas en dispositivo.

## Pruebas pendientes

- Generación y build limpia en macOS con Xcode 26+, SDK iOS 26+ y XcodeGen, primero unsigned con `publish_release=false`.
- Resolución y compilación reales de Google Mobile Ads 12.x y UMP 3.x; Windows no puede validar importación, enlace ni APIs Swift.
- Archivo firmado e inspección automatizada del archive con `ad_configuration=test`, `validate_with_app_store=false` y `upload_to_app_store=false`. Generar o inspeccionar además el privacy report agregado en Xcode Organizer; la validación externa sigue separada y desactivada por defecto.
- Prueba UMP/AdMob en dispositivo de prueba: instalación limpia EEE/Reino Unido, aceptar/rechazar, reapertura, opciones de privacidad, fuera de zona regulada, primer arranque sin red y sesión con consentimiento previo. Confirmar cero solicitudes antes de `canRequestAds`.
- Verificar que una suscripción o código manual activo elimina el banner y que su pérdida lo reactiva solo si UMP permite anuncios.
- Prueba real en iOS 16 y una versión actual: grabación continua y por sonido, rotación, segundo plano/bloqueo, reproducción, renombrado, favoritos, compartir y borrar.
- Interrupciones por llamada, Siri y alarma; cambios Bluetooth/ruta; reset de servicios multimedia; falta de espacio y fallo de escritura.
- Fluidez, cola de audio, batería y temperatura durante 30 minutos en modo continuo y 30 minutos por sonido.
- Selector completo y persistencia de `ca/de/en/es/fr/it/pt` en dispositivo.
- StoreKit Sandbox: compra, restauración, upgrade/downgrade, cancelación, expiración y revocación; interacción con desbloqueo manual.
- VoiceOver, Dynamic Type y apertura real de enlaces legales, suscripciones y soporte.

## Bloqueos humanos o externos

- La nueva cuenta AdMob del propietario está pendiente de verificación por Google. Esto no bloquea la beta interna con anuncios demo, pero sí bloquea la validación del CMP real y cualquier candidata pública monetizada.
- Tras la verificación se necesitan exactamente el App ID iOS (`ca-app-pub-…~…`) y el Banner ad unit ID (`ca-app-pub-…/…`) de la app con bundle `com.dmkr.audio.B2X6D3A9J9`, además de los mensajes aplicables publicados en `Privacy & messaging`.
- GitHub ya tiene el environment `app-store-production` y los cuatro secrets requeridos (`APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_BASE64`). Se cargaron desde los materiales locales sin mostrar sus valores; la Team API Key activa tiene rol Gestor de apps.
- App Store Connect se comprobó en vivo: existe `Voice Recorder Pro - Audio K` (`6772278149`, bundle `com.dmkr.audio.B2X6D3A9J9`), todavía no hay ninguna build y por tanto el build `1` está libre. Existe el grupo interno `Testers` con un único tester y cero builds.
- El run 31275686032 confirmó Xcode 26.6/iOS SDK 26.5, secrets legibles, par demo correcto, generación del proyecto y dependencias GMA 12.14.0/UMP 3.1.0. La API key también autentica en la API pública y lee app/Bundle ID.
- La firma automática está bloqueada: Xcode recibe HTTP 401 en listTeams.action y no obtiene un provisioning profile App Store. La Team API Key actual tiene rol Gestor de apps; crear una nueva clave Admin o certificados/perfiles manuales requiere autorización expresa adicional.
- La API muestra un único certificado iOS Development válido y un perfil IOS_APP_STORE antiguo, caducado y de otra app. No existe material de distribución reutilizable para VoiceRecorder.
- Los runs 31275416194, 31275507646 y 31275610317 diagnosticaron y resolvieron únicamente la codificación BOM del secret. Ninguno ejecutó upload.
- Solo hay un usuario en App Store Connect. Para la segunda persona habrá que invitar primero su Apple Account como usuario con acceso a la app y después añadirla al grupo interno; falta su dirección de cuenta.
- ATT/IDFA no se ha activado. Requiere una decisión expresa separada; si se adopta habrá que añadir su texto, localizarlo y probar el permiso antes de cargar anuncios personalizados.
- La política debe publicarse y verificarse desde una sesión cerrada antes de usar su URL pública.
- App Store Connect requiere comprobación humana de los seis productos elegidos; los productos 50/100/300 deben quedar fuera de venta y fuera de la versión 1.0.
- Quedan pendientes privacidad, edad, categorías, derechos de contenido, acuerdos, fiscalidad, banco, contacto de revisión y metadatos localizados en App Store Connect.
- Las notas de revisión deben describir fielmente el mecanismo de códigos manuales ocultos.
- Deben decidirse y verificarse cumplimiento de exportación y familia de dispositivos. La build superada mantiene un aviso porque solo declara orientación vertical mientras el destino puede incluir iPad; decidir iPhone-only, universal o pantalla completa antes del archive firmado.
- GitHub ejecuta ya el workflow actualizado de la rama. Ninguna ejecución de firma activó validación externa ni upload.
- Cualquier publicación, subida o envío requiere aprobación expresa independiente.

## Próximo paso coordinado

Obtener autorización para crear mediante la API un certificado Apple Distribution y un provisioning profile IOS_APP_STORE para VoiceRecorder, y guardar su material privado como secrets de GitHub para firma manual. Esto consume un hueco de certificado y crea recursos externos. Si la clave actual rechaza la creación, pedir entonces autorización para una Team API Key Admin. Después repetir build 1 con upload desactivado; no subir ni distribuir todavía.
## Actualización de firma manual — 2026-08-09

- Apple creó un certificado moderno `DISTRIBUTION` (`2K3G3RTCS5`) para el equipo `B2X6D3A9J9`, válido hasta 2027-08-08, sin revocar recursos anteriores.
- Apple creó el perfil `IOS_APP_STORE` `VoiceRecorder App Store 2026-08-09` (`2J3LC3G5U8`, UUID `e8c5f848-9776-484a-a955-ee1196048faf`) para `com.dmkr.audio.B2X6D3A9J9` y exactamente ese certificado.
- La clave privada, CSR, certificado, perfil y P12 protegido se conservan fuera del repositorio en `C:\Users\dmkra\Documents\Codex Apps\APIs\IOS\VoiceRecorder Distribution`. Ningún valor privado se mostró ni se versionó.
- Se verificaron sujeto/emisor/vigencia del certificado, correspondencia clave-certificado, firma CMS del perfil, equipo, prefijo, application identifier, `get-task-allow=false`, ausencia de dispositivos y coincidencia SHA-1 del certificado del perfil.
- El commit `66d3465` adapta el workflow a firma manual con llavero temporal, validación estricta de perfil/certificado, comprobación del IPA y dSYM, y limpieza `always()`. Se publicó en `agent/prepare-ios-test-build`; Android y `artifact/` no cambiaron.
- YAML, los 14 scripts shell embebidos, el script Node y `git diff --check` pasan localmente.
- Pendiente: transferir el P12, su contraseña y el perfil a los tres GitHub Secrets de firma. Esa transferencia expone a GitHub una identidad capaz de firmar apps y requiere confirmación explícita del propietario tras informar del riesgo. Después se repetirá build 1 con `ad_configuration=test`, validación y upload desactivados.
## Build firmada verificada — 2026-08-09

- Los tres secretos de firma manual están configurados en el environment `app-store-production`. El P12 y su contraseña se cargaron juntos mediante el modo dotenv oficial de GitHub CLI; la copia dotenv temporal fuera del repositorio se eliminó inmediatamente. Los valores no se mostraron.
- Run exitoso: `31282363769`, commit `d02ec93`, Xcode 26.6/iOS SDK 26.5, `ad_configuration=test`, `confirm_internal_testflight_only=true`, `validate_with_app_store=false`, `upload_to_app_store=false`.
- Pasaron: importación de identidad, perfil/equipo/prefijo/certificado, generación XcodeGen, dependencias GMA/UMP, archive firmado, codesign estricto, identidad 1.0 (1), anuncios demo, siete idiomas, provisioning App Store, exportación IPA, codesign del IPA y coincidencia ejecutable/dSYM.
- IPA `VoiceRecorderPro.ipa`: SHA-256 interno `a21721c4b34203cc3ecb5387a8eb0760f09f9aaf84bfe6cdaacf0642b8d772ab`.
- Artefacto GitHub `AudioRecorder-test-ipa-build-1`: 6.793.697 bytes, digest del ZIP `sha256:9404ee8211d31f44380b0049b068a31a9edbff5ff1d8e97d8c095f02fe404103`, disponible hasta 2026-08-15.
- Artefacto GitHub `AudioRecorder-test-archive-build-1`: 7.820.963 bytes, digest `sha256:966f48c414df60c9d74f23b867588aa9b9eac4a5c8bbf3b45c6885505203ec8f`, disponible hasta 2026-08-15.
- Los pasos `Validate exported IPA with App Store Connect` y `Upload to App Store Connect` quedaron expresamente omitidos. La limpieza temporal de llavero, P12 y perfil pasó.
- Los runs previos `31281870429`, `31281944971`, `31282034360`, `31282121034`, `31282165808`, `31282237293` y `31282289585` fueron diagnósticos fallidos antes de exportar; ninguno validó ni subió una build.
- Próximo paso rojo: autorización contemporánea para ejecutar validación App Store Connect y upload de una build `TestFlight Internal Only`. Después habrá que esperar procesamiento de Apple, asignarla al grupo `Testers` y obtener la Apple Account de la segunda persona.
## TestFlight interno y propuestas de icono — 2026-08-09

- El run autorizado `31283035466` (commit `93056e9`) validó el IPA con Apple y subió iOS 1.0 (build 1) como `TestFlight Internal Only`. No hubo App Review, TestFlight externo ni publicación en App Store.
- App Store Connect confirma build resource `a79ddc21-5b41-4f2a-9b48-46cb4a9e5224`, `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `buildAudienceType=INTERNAL_ONLY`, versión visible `1.0` y build `1`.
- El grupo interno privado `Testers` tiene `hasAccessToAllBuilds=true`; la build ya aparece vinculada y disponible. El grupo contiene un tester. Para la segunda persona sigue faltando su Apple Account y alta como usuario interno de App Store Connect.
- El propietario confirmó que la app no usa cifrado propio/no exento. Apple refleja `usesNonExemptEncryption=false` y el código local añade `ITSAppUsesNonExemptEncryption=false` para futuras builds; esta clasificación deberá revisarse si cambia la implementación.
- La versión local es coherente: `native-ios/project.yml` declara `MARKETING_VERSION=1.0` y `CURRENT_PROJECT_VERSION=1`; `Info.plist` consume esos valores. La siguiente build conservará marketing 1.0 e incrementará solo el número de build.
- El propietario aprobó `03-ribbon-dot.png`; ya está instalado como icono iOS opaco 1024 x 1024. El icono cósmico anterior se conserva byte por byte en `docs/icon-proposals/00-original-cosmic-backup.png`.
- Las páginas limpias `https://krazel.github.io/audio-recorder/privacy/` y `https://krazel.github.io/audio-recorder/support/` responden HTTP 200. El código iOS local y las siete fichas del manifiesto ya usan esas URLs; la build 1 subida conserva el enlace histórico y la corrección llegará en una build nueva.
- Utilidad idempotente añadida localmente: `scripts/manage-testflight-internal.mjs`, con verificaciones de app, bundle, versión, build, audiencia, grupo interno y distribución automática. No muestra secretos.

Próximo paso: probar la build 1 ya activa en TestFlight. Los cambios locales posteriores (icono 3, URLs limpias e Info.plist de cifrado) requieren una build 2; no se subirá sin autorización separada.

## Build 2 activa en TestFlight interno - 2026-08-09

- El propietario autorizo expresamente crear y subir la build 2 exclusivamente a TestFlight interno.
- El commit `a237172` contiene el icono iOS variante 3 aprobado, conserva el icono anterior en `docs/icon-proposals/00-original-cosmic-backup.png`, declara `ITSAppUsesNonExemptEncryption=false` y usa las URLs limpias de privacidad y soporte.
- El run [31285797462](https://github.com/Krazel/AudioRecorder/actions/runs/31285797462) genero, firmo, verifico, valido con Apple y subio iOS `1.0` build `2` con anuncios demo oficiales y exportacion `TestFlight Internal Only`.
- App Store Connect confirma el recurso `35de428c-9d56-475a-9444-f69e82c1ce57`, `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `externalBuildState=NOT_APPLICABLE`, `buildAudienceType=INTERNAL_ONLY` y `usesNonExemptEncryption=false`.
- La build 2 ya esta vinculada automaticamente al grupo interno privado `Testers`; el grupo tiene un tester y acceso automatico a todas las builds elegibles.
- No hubo TestFlight externo, Beta App Review, App Review ni publicacion publica. Android y `artifact/` permanecen sin cambios.
- El nombre visible en App Store/TestFlight esta localizado por idioma o tienda; en espanol se muestra `Grabadora de Voz Pro - Audio K`. El nombre bajo el icono de la app permanece en ingles en las siete localizaciones.

Proximo paso: instalar y probar la build 2 desde TestFlight en un iPhone real. AdMob real y el CMP de produccion siguen pendientes antes de cualquier candidata publica.

## Build 4 con icono blanco activa en TestFlight interno - 2026-08-09

- El propietario solicito probar una variante del icono con fondo blanco conservando el icono negro anterior.
- El commit `dafe2d5` instala el icono blanco opaco de 1024 x 1024 y conserva una copia exacta del negro en `docs/icon-proposals/06-black-production-backup.png`.
- El run [31288585155](https://github.com/Krazel/AudioRecorder/actions/runs/31288585155) compilo, firmo, verifico, valido con Apple y subio iOS `1.0` build `4` con anuncios demo y exportacion `TestFlight Internal Only`.
- App Store Connect confirma `processingState=VALID`, `internalBuildState=IN_BETA_TESTING`, `externalBuildState=NOT_APPLICABLE`, `buildAudienceType=INTERNAL_ONLY` y `usesNonExemptEncryption=false`.
- La build 4 esta disponible automaticamente para el grupo interno `Testers`. No hubo TestFlight externo, App Review ni publicacion publica.
- La inspeccion de AdMob en el navegador integrado sigue bloqueada por un fallo del controlador local; se abrio una pestaña nueva, pero no se modifico ningun recurso de AdMob.

Proximo paso: instalar la build 4 desde TestFlight y comparar el icono blanco con el negro conservado. Antes de una candidata publica con AdMob real, verificar que el mensaje europeo de privacidad figure como publicado.
