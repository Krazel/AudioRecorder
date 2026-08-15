# VoiceRecorder / AudioRecorder — estado actual

## Estado de App Store Connect - 2026-08-15 15:38 CEST

- `Krazel/AudioRecorder` es público. La auditoría previa no encontró secretos, certificados, perfiles ni claves privadas alcanzables desde ramas o etiquetas; los secretos siguen protegidos fuera del repositorio.
- La build histórica iOS 1.0 (6), commit `fdcdb3f`, se construyó, firmó y subió mediante GitHub Actions run `31850317905`, pero Apple rechazó su manifiesto raíz con `ITMS-91064`.
- App Store Connect tiene subtítulo y texto promocional vacíos en los siete idiomas, dos capturas públicas reales por idioma, enlace EULA en las siete descripciones y la política pública actualizada.
- App Privacy conserva ATT/tracking para las categorías publicitarias aplicables. El archive exacto confirma el manifiesto de la app, Google Mobile Ads y UMP; `Device ID` es la categoría del SDK marcada para tracking y los datos de fallos/rendimiento no lo son.
- Las siete suscripciones tienen nivel 1, 49 localizaciones coherentes, precios y disponibilidad configurados, y una captura privada real procesada con estado `COMPLETE` en cada producto.
- Tras autorización expresa, se conserva una única submission `7e9fd837-4419-498a-a40a-7e8fbbd4422e` con exactamente nueve elementos: versión iOS 1.0, versión del grupo y siete versiones de suscripción.
- Apple comunicó el motivo exacto: `ITMS-91064`. El `PrivacyInfo.xcprivacy` de la build 6 contenía `NSPrivacyTracking=true` junto con `NSPrivacyTrackingDomains=[]`; Apple TN3181 define expresamente esa combinación como inválida. La firma, el ejecutable y la carga de la build 6 no estaban corruptos.
- La candidata 1.0 (7), commit `3e74d38`, corrige el manifiesto raíz a `NSPrivacyTracking=false` sin `NSPrivacyTrackingDomains`. ATT, UMP, `usesIdfa=true`, App Privacy y el manifiesto propio de Google Mobile Ads permanecen separados y coherentes. El workflow valida semánticamente todos los manifiestos tanto en fuente como en archive e IPA exportada para impedir otra subida con claves incompatibles.
- GitHub Actions run `31887343289` terminó correctamente: firma, archive, validadores de privacidad en fuente/archive/IPA, validación de Apple y upload pasaron. Apple procesó la build 7 como `VALID`, `APP_STORE_ELIGIBLE`, no caducada, iOS 16+, con ID `744404c3-5503-4e64-a796-bef3ce86cffe`.
- La build 7 está seleccionada en la versión 1.0, `usesIdfa=true` y publicación `MANUAL`. El elemento rechazado se marcó resuelto y la misma submission se reenvió el 15 de agosto de 2026 a las 15:38 CEST.
- App Store Connect muestra `Pendiente de revisión` para la submission y sus nueve elementos: app 1.0 (7), grupo y siete suscripciones. No se perdió ni recreó ningún producto.
- La app no está publicada; la publicación posterior a una eventual aprobación permanece manual.

Última revalidación: 2026-08-15.

> Estado vigente: la build 7 corregida está validada y los nueve elementos están pendientes de revisión. No queda ninguna acción inmediata: esperar la respuesta de Apple. Aunque Apple apruebe, la publicación permanece manual y no se hará pública automáticamente.

## Preparación de repositorio público y build 6 - 2026-08-15

- El propietario autorizó hacer público `Krazel/AudioRecorder` para usar GitHub Actions y completar la build 1.0 (6). La auditoría de ramas, etiquetas y archivos versionados no encontró claves privadas, certificados, perfiles, tokens ni contraseñas; los secretos de Apple y AdMob permanecen en el environment protegido `app-store-production`.
- Antes del cambio de visibilidad se retiró de iOS el mecanismo de códigos manuales y su acceso oculto. StoreKit pasa a ser la única vía para retirar anuncios; los desbloqueos manuales históricos se invalidan al actualizar y las suscripciones verificadas siguen funcionando.
- El primer intento de build 6, run `31849082511`, no llegó a asignar un runner ni a ejecutar pasos porque GitHub indicó un pago fallido o límite de gasto. No consumió el número de build en Apple. El siguiente paso es hacer público el repositorio y relanzar el mismo workflow desde la candidata actualizada.

## Corrección del rechazo de App Review - 2026-08-13

- La fuente de build 6 mantiene UMP y `canRequestAds`, solicita ATT después de UMP y espera la respuesta antes de iniciar Google Mobile Ads. Si se autoriza, AdMob puede usar IDFA para anuncios personalizados y medición; si se rechaza, la app sigue funcionando y AdMob sirve anuncios sin IDFA ni tracking.
- El manifiesto local ya carecía de subtítulo en los siete idiomas. Las siete descripciones ahora incluyen el enlace funcional a la EULA estándar de Apple. También deja de seleccionar la tercera captura antigua que decía `free`/`gratis`, conservando los archivos y las dos capturas restantes de cada idioma.
- Se extrajo del vídeo físico real de build 5 una captura 1290 × 2796 que muestra los siete productos: `store/app-review/build-5/subscriptions-seven-levels-real.png`, SHA-256 `34dd93ff0b548f92d9cf3ec0b6237704e8072854dd86e032ab7766fd78e6d532`. Es evidencia privada de revisión, no imagen pública ni arte inventado.
- `store/app-review/REJECTION-2026-08-13.md` contiene el mapa de App Privacy, los pasos externos y la respuesta final preparada. `docs/IOS_DATA_INVENTORY.md` y `store/app-store-connect-setup.md` ya reflejan ATT, el comportamiento condicionado por la respuesta y la captura que Apple exige ahora.
- Sigue pendiente validar la compilación real con Xcode/macOS, generar el privacy report agregado y después, con autorización roja contemporánea: publicar la política actualizada, subir 1.0 (6), corregir App Privacy y metadatos remotos, cargar la captura en los siete productos, añadir grupo/productos al envío y reenviar. La publicación final permanece manual.

## Manifiesto visual canonico - 2026-08-11

- Existe `design/APPROVALS.md` como indice durable de maestras visuales, variantes provisionales y evidencia de runtime, con ruta, lienzo/dispositivo, orientacion, idioma, fecha y SHA-256.
- La maestra aprobada registrada es el icono negro `IOS-ICON-BLACK-001`, conservado en `design/approved/ios/app-icon/ribbon-dot-black-1024.png`.
- La candidata 1.0 (5) contiene el icono blanco, registrado honestamente como `PROVISIONAL_IN_BUILD`: el propietario autorizo probarlo en TestFlight, pero no consta una aprobacion expresa que sustituya al icono negro como maestra final.
- Las capturas reales historicas de Record listo, Record grabando y Archivos quedan inventariadas solo como evidencia de runtime, no como maestras aprobadas. Ajustes/apoyo dispone ahora de evidencia real privada extraída del vídeo de build 5, pero sigue sin tener una imagen completa aprobada como maestra. Esto no altera el binario ni autoriza una sustitución visual futura.
- Las propuestas siguen separadas en `docs/icon-proposals/`; `artifact/` y Android permanecen intactos.

## Auditoria de minimizacion y exactitud - 2026-08-11

- `docs/IOS_DATA_INVENTORY.md` registra permisos, almacenamiento local, transmisiones iniciadas por el usuario, StoreKit, Google Mobile Ads/UMP, retencion/control y separacion entre contacto publico y privado para la fuente candidata 1.0 (6), todavía no archivada ni subida.
- Los permisos sensibles son micrófono, solicitado al iniciar una grabación, y ATT, solicitado tras UMP antes de iniciar anuncios con capacidad de tracking. No existen permisos de ubicación, cámara, fotos, contactos, salud, calendario, movimiento o notificaciones, ni cuenta/login o servidor del desarrollador.
- El manifiesto de tienda local deja vacios los campos opcionales de subtitulo, texto promocional, palabras clave y URL de marketing. Mantiene los campos necesarios de nombre, descripcion, soporte, privacidad y capturas. No se ha modificado App Store Connect.
- Las copias locales `docs/PRIVACY.md` y `docs/privacy.html` se ajustaron a la build real: banner condicionado por UMP/estado sin anuncios, categorias de Google, StoreKit, datos locales y retencion minima del correo de soporte. La pagina publica canonica vive en el repositorio compartido `krazel.github.io` y se sincronizo mediante la publicacion autorizada descrita abajo.
- El propietario autorizo el saneamiento del historial. La rama remota `agent/prepare-ios-test-build` fue reescrita con lease exacto de `31a1f67` a `1a7678f`; tanto la rama como `refs/pull/1/head` apuntan a la historia nueva y ningun commit alcanzable desde `main..HEAD` contiene el nombre o telefono privados. GitHub puede conservar temporalmente vistas/cache por SHA aunque ya no existan referencias activas; una purga de cache por soporte queda fuera de esta tarea.
- La build 5 integra GMA 12.14.0 y UMP 3.1.0. La politica enumera IP/ubicacion aproximada, identificadores, datos publicitarios, interaccion, fallos, rendimiento y diagnosticos, pero falta inspeccionar el informe de privacidad agregado del archive exacto y cotejar las respuestas vivas de App Store Privacy. El verificador central de GitHub devolvio `CENTRAL_RECHECK_REQUIRED`, por lo que esta tarea no accedio al artefacto ni pidio login al propietario.
- El codigo conserva infraestructura inactiva de subida cloud/servidor y preferencias de endpoint/token. La build 5 fuerza `uploadAutomatically=false` y no expone controles, por lo que no transmite esos valores; deben eliminarse y limpiarse en la siguiente build de codigo, sin afirmar que esa limpieza ya existe en build 5.
- `UIFileSharingEnabled` y apertura en sitio se conservan como acceso local controlado por el usuario a sus grabaciones; no constituyen recogida ni transmision al desarrollador.
- DSA trader permanece como requisito territorial material: se resuelve verazmente en el canal dedicado de Apple y no se duplica en paginas publicas salvo lo que Apple o la ley exijan.
- Las paginas publicas de privacidad y soporte se actualizaron en `krazel.github.io`, commit `3371a6d`, y ambas responden HTTPS 200 con el nombre exacto de la app; la politica muestra fecha 2026-08-11. Los cambios locales ajenos de Tarot existentes en ese repositorio se preservaron sin incluirlos en el commit.
- Los cambios de minimizacion, inventario y aprobaciones visuales quedaron publicados en la rama saneada de AudioRecorder. No se modificaron remotamente los campos de App Store Connect desde esta tarea.

## Solicitud de información de App Review - 2026-08-10

- Apple pide que el vídeo comience lanzando la app y muestre el flujo normal: consentimiento UMP si aparece, permiso de micrófono, grabar/detener, archivos/reproducción/gestión, modo por sonido y acceso al flujo de suscripciones.
- El segundo vídeo `VoiceRecorder Grabacion.mp4` fue revisado localmente: dura 56 segundos, es un MP4 vertical de 384 × 848 y muestra el lanzamiento desde la pantalla de inicio en un iPhone 11 con iOS 26.6, consentimiento UMP, permiso de micrófono, grabación, archivo creado, gestión/favorito, configuración del modo por sonido, los siete niveles, hoja de compra TestFlight cancelable, enlaces legales, opciones de privacidad y versión 1.0 build 5. Es apto para adjuntar a la respuesta; no se ha transmitido todavía.
- La respuesta puede documentar de forma verificable que no hay cuentas ni login; las grabaciones se guardan localmente y solo se comparten por la hoja nativa; las funciones principales son gratuitas; las siete suscripciones mensuales equivalentes se encuentran en Ajustes y retiran anuncios; los servicios externos visibles son StoreKit, Google Mobile Ads y Google UMP.
- Los dispositivos declarables ya están confirmados: iPhone X con iOS 16 e iPhone 11 con iOS 26.6. El vídeo físico real existe en Descargas y fue revisado; no falta ese material.
- La candidata build 6 ya no contiene el antiguo campo oculto ni códigos manuales; no requieren instrucciones ni credenciales en las notas de revisión.
- Antes de reenviar, comprobar que la versión incluye la build 5 y que las siete suscripciones se añaden al envío inicial. Responder a Apple o volver a enviar continúa siendo una acción roja y no se ha ejecutado.

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
- Siete suscripciones mensuales locales: 0,99 / 3 / 5 / 10 / 15 / 30 / 49,99, con el mismo beneficio de retirar anuncios mientras exista derecho activo.
- StoreKit es la única vía de retirada de anuncios en la candidata pública; el mecanismo manual histórico se ha eliminado.
- La pantalla de apoyo muestra precio localizado de StoreKit, periodicidad mensual, renovación/cancelación, restauración, gestión de suscripción, Política de privacidad y EULA estándar de Apple.
- StoreKit recalcula derechos tras actualizaciones de transacción y restaura las suscripciones verificadas.
- El modo por sonido copia el buffer del tap y realiza análisis y escritura en una cola serial dedicada; la recuperación conserva el estado del segmento y un fallo de escritura detiene la grabación de forma veraz.
- `PrivacyInfo.xcprivacy` declara `CA92.1` para preferencias privadas y `C617.1` para metadatos de archivos del contenedor.
- UMP solicita una actualización en cada arranque, presenta el formulario si es necesario y no inicializa Mobile Ads ni crea el banner hasta que `canRequestAds` sea verdadero. La inicialización y la carga tienen guardas contra duplicados.
- Ajustes muestra `Opciones de privacidad` únicamente cuando UMP devuelve que son obligatorias; la presentación se inicia solo por una acción explícita del usuario.
- Los IDs de demostración de Google permanecen como valores locales para desarrollo/unsigned. `Info.plist` y el código admiten inyección separada del App ID y del Banner ad unit ID reales.
- `Info.plist` contiene los 50 `SKAdNetworkIdentifier` del ejemplo oficial de Google vigente el 2026-08-08. Esos identificadores no activan ATT por sí mismos; ATT se incorpora de forma separada y explícita en la candidata 1.0 (6).
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
- Verificar que una suscripción activa elimina el banner y que su pérdida lo reactiva solo si UMP permite anuncios.
- Prueba real en iOS 16 y una versión actual: grabación continua y por sonido, rotación, segundo plano/bloqueo, reproducción, renombrado, favoritos, compartir y borrar.
- Interrupciones por llamada, Siri y alarma; cambios Bluetooth/ruta; reset de servicios multimedia; falta de espacio y fallo de escritura.
- Fluidez, cola de audio, batería y temperatura durante 30 minutos en modo continuo y 30 minutos por sonido.
- Selector completo y persistencia de `ca/de/en/es/fr/it/pt` en dispositivo.
- StoreKit Sandbox: compra, restauración, upgrade/downgrade, cancelación, expiración y revocación.
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
- ATT/IDFA está implementado en la fuente candidata 1.0 (6), con texto base y localizaciones `ca/de/en/es/fr/it/pt`. Falta compilar y probar desde instalación limpia ambos resultados antes de cargar anuncios: autorizar permite IDFA/tracking; rechazar mantiene la app funcional y los anuncios sin IDFA/tracking.
- La política debe publicarse y verificarse desde una sesión cerrada antes de usar su URL pública.
- App Store Connect requiere comprobación humana de los seis productos elegidos; los productos 50/100/300 deben quedar fuera de venta y fuera de la versión 1.0.
- Quedan pendientes privacidad, edad, categorías, derechos de contenido, acuerdos, fiscalidad, banco, contacto de revisión y metadatos localizados en App Store Connect.
- Las notas de revisión deben indicar que las suscripciones verificadas por StoreKit son la única vía para retirar anuncios.
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
