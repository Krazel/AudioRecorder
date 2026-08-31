# VoiceRecorder / AudioRecorder — estado actual

## Candidata de producción iOS 1.0.8 (1) — preparada para CI, carga y App Review — 2026-08-31

- El propietario aprobó las pruebas físicas: grabación prolongada y recuperación tras Siri funcionan. Una llamada aceptada puede suspender cualquier grabadora general; 1.0.8 conserva intención y reintenta en cuanto iOS vuelve a ejecutar el proceso o la app retorna a foreground, sin usar CallKit, PushToTalk, audio silencioso ni capacidades impropias.
- El watchdog recibe latidos desde la cola real de buffers y usa `DispatchSourceTimer`; detecta cinco segundos sin audio aunque `AVAudioEngine.isRunning` siga verdadero. El diario protegido conserva solo UUID aleatorio y fechas técnicas para clasificar conservadoramente una ejecución anterior; no contiene audio, rutas, nombres, hardware, cuentas ni red.
- Archivos, carpetas y raíz usan `completeUntilFirstUserAuthentication`; la biblioteca recupera archivos no indexados antes del autoarranque. La cola de audio usa `autoreleasepool` para reducir presión en sesiones largas.
- Se eliminan por completo Ajustes > `INTERNAL QA`, la exportación/JSON de diagnóstico y su almacenamiento. Solo queda Unified Log minimizado y el diario de ejecución no exportable.
- Se elimina todo scaffolding inactivo de subida a nube/servidor, incluidos endpoint/token y POST multipart; preferencias heredadas se purgan. Las grabaciones permanecen locales y solo se comparten mediante la hoja nativa elegida por el usuario.
- La fuente conserva IDs demo para desarrollo. El workflow de producción inyecta secrets y exige que coincidan exactamente con `ca-app-pub-3425091654264901~2340753104` y `ca-app-pub-3425091654264901/5497133550` dentro del archive.
- AdMob revalidado en vivo: app y banner reales, solicitudes e impresiones reales, mensaje europeo activo, mensaje IDFA sin publicar y Centro de Políticas sin problemas. La consola aún muestra verificación de aplicación pendiente, aunque App Store, landing y `app-ads.txt` responden HTTP 200 con la línea DIRECT correcta.
- `store/store-manifest.json`, inventario y preflight ya apuntan a 1.0.8 y contienen `What's New` en siete idiomas. La automatización nueva separa status, número libre, procesamiento, preparación y envío; exige publicación `MANUAL`, build exacta, siete localizaciones/capturas y siete suscripciones ya `APPROVED`.
- Pendiente operativo: integrar en `main`, ejecutar CI/XCTest/Release, firmar y validar el archive de producción, subirlo, verificar App Store Connect, seleccionar exclusivamente 1.0.8 (1) y enviarlo a App Review. La autorización vigente cubre esos pasos; nunca la publicación automática.

## TestFlight interno iOS 1.0.7 (1) — QA físico de Siri sin foreground aprobado — 2026-08-31

- El diagnóstico físico `voice-recorder-recording-diagnostics (2).json`, exportado desde 1.0.7 (1) en iOS 16.7.16, confirma la recuperación automática exigida. En la sesión `0F70F9D7-FEA3-4661-A7FA-12D57C7A7EF2`, la app estaba en background desde `01:37:22Z`; Siri interrumpió a `01:37:24Z`; iOS notificó el fin con permiso de reanudación a `01:37:26Z`; ese mismo segundo la sesión se activó, se reconstruyó e inició el engine y `recoveryFirstBufferObserved` confirmó escritura de audio. La app no volvió a foreground hasta `01:37:30Z`, cuatro segundos después. Por tanto, la recuperación ocurrió realmente en segundo plano y no fue provocada por reabrir VoiceRecorder.
- La interrupción de aproximadamente dos segundos mientras Siri posee el micrófono es comportamiento del sistema; los segmentos válidos anteriores y posteriores se conservan. La traza no muestra una parada solicitada ni pérdida de intención.
- El mismo archivo conserva una sesión anterior larga con dos rotaciones correctas en background a `00:17:10Z` y `00:32:10Z`, con `engineRunning=true`, lo que aporta evidencia adicional de continuidad al separar archivos.

- El propietario aclaró el criterio físico real de 1.0.6: al cerrar Siri sin volver manualmente a VoiceRecorder, el indicador naranja no reaparece y no hay captura. La traza demuestra que los intentos de background fallaron con `560557684` (`!int`, `AVAudioSession.ErrorCode.cannotInterruptOthers`) y que la primera activación válida ocurrió solo cuando la app comenzó a regresar al foreground. Por tanto, 1.0.6 repara el backend al volver, pero falla la continuidad automática exigida en segundo plano y no debe promoverse.
- Causa concreta: `playAndRecord` es no mezclable por defecto. Apple define `cannotInterruptOthers` como el intento de activar desde background una sesión no mezclable. El proyecto ya declara `UIBackgroundModes=audio`; el bloqueo restante era la configuración de la sesión, no el retry ni el engine.
- La candidata 1.0.7 (1) centraliza `RecordingAudioSessionPolicy` y usa `playAndRecord` con `[allowBluetoothHFP, defaultToSpeaker, mixWithOthers]`. Apple permite `mixWithOthers` con `playAndRecord`; así la reactivación ya no necesita interrumpir otra sesión desde background. Se conservan reconstrucción del engine, retries, Stop, Bluetooth y altavoz.
- XCTest determinista fija la categoría/modo, exige `mixWithOthers`, conserva Bluetooth/altavoz y prohíbe introducir `duckOthers` o `interruptSpokenAudioAndMixWithOthers`. El cambio puede permitir que audio de otras apps continúe mientras se graba y llegue acústicamente al micrófono; es el coste documentado de hacer cooperativa la sesión y la puerta necesaria para recuperar sin foreground.
- La fuente y el finalizador quedaron en `main` mediante `181fe83`. El run `33346790879` superó la arquitectura continua, todos los XCTest y Release para dispositivo. El run firmado `33347088605` superó Xcode 26.6, firma/perfil, puerta UMP/ATT, XCTest, archive, privacidad, siete idiomas, exportación IPA, validación de Apple y upload con IDs demo oficiales.
- El finalizador `33347538527` confirmó la build Apple `82c918a0-19e3-4528-858b-06dbb6912af1`: iOS 1.0.7 (1), `VALID`, `INTERNAL_ONLY`, `usesNonExemptEncryption=false`, `IN_BETA_TESTING`, externo `NOT_APPLICABLE`, grupo privado `Testers` con exactamente dos testers, acceso automático y relación activa; `selectedByAppStoreVersions=[]`.
- No hubo TestFlight externo, selección para App Store, App Review ni publicación. La build usa IDs demo y solo puede utilizarse para QA interno. La prueba principal de Siri sin foreground ya está aprobada; siguen siendo prudentes pruebas físicas separadas de llamada/alarma, bloqueo prolongado, Bluetooth/cambio de ruta y poco espacio antes de promover una futura candidata de producción.

## TestFlight interno diagnóstico iOS 1.0.6 (1) — recupera solo al volver a foreground — 2026-08-31

- El JSON físico exportado en iPhone con iOS 16.7.16 demuestra que 1.0.6 conservó la intención y escribió después de volver a la app. La sesión empezó a las `00:01:46Z`; Siri interrumpió a las `00:01:57Z` y el primer segmento se completó; iOS denegó `setActive` cuatro veces con `560557684` mientras la app seguía en segundo plano; a las `00:02:09Z`, durante el retorno a foreground, la activación tuvo éxito, se creó un engine nuevo y se abrió un segundo segmento; a las `00:02:10Z`, `recoveryFirstBufferObserved detailCode=1` confirmó escritura. Esto no satisface la reanudación automática sin abrir la app.

- El propietario probó 1.0.5 (1) en iPhone y confirmó el mismo resultado físico: Siri interrumpe la grabación y, al cerrarlo, la captura no vuelve. 1.0.5 queda fallida y no puede promoverse ni considerarse evidencia de resolución.
- Antes de 1.0.6, el código y los XCTest no permitían distinguir si faltaba `interruption ended`, si el `began` llegaba tarde por suspensión, si `setActive` fallaba, si el formato quedaba en cero, si el engine arrancaba sin buffers o si un retry se cancelaba. La instrumentación de 1.0.6 ya resolvió esa incertidumbre y demostró `cannotInterruptOthers` en background.
- La fuente local se versiona como iOS 1.0.6 (1) y amplía el diagnóstico acotado a 200 eventos. Registra `began/ended`, options, `AVAudioSessionInterruptionReasonKey`, `AVAudioSessionInterruptionWasSuspendedKey`, background/active, configuration change, intent, engine running, sample rate/canales, retries/cancelaciones, error domain/code y resultado por etapa `activateSession/rebuild/open/start`, incluido el primer callback de buffer tras recuperar.
- Ajustes muestra una sección provisional `INTERNAL QA` con `Exportar diagnóstico de grabación` solo cuando el binario contiene el App ID demo oficial de Google. Genera y comparte un JSON explícito con versión/build e iOS. No incluye audio, transcripciones, nombres/rutas de archivos, hardware identificable, cuentas ni red; no se transmite automáticamente.
- Pruebas deterministas amplían el esquema minimizado, el documento exportable, el límite del buffer, los datos de interrupción/estado y la compuerta que oculta la acción en builds con AdMob real.
- La instrumentación quedó en `main` mediante `7df0dea`. El run `33340707076` superó XCTest/Release y el run firmado `33340921074` superó archive, firma, IPA, validación Apple y upload con IDs demo; Apple aceptó la carga. No hubo TestFlight externo, App Review, selección ni publicación.
- El finalizador de solo lectura `33341464009` terminó correctamente. Apple build `53a1f112-27b7-4e31-be57-a2f5a130b73f`: iOS 1.0.6 (1), `VALID`, `INTERNAL_ONLY`, `usesNonExemptEncryption=false`, `IN_BETA_TESTING` y externo `NOT_APPLICABLE`. El grupo privado `Testers` (`9fb339bc-471a-438f-bc2e-f9961e974cee`) tiene dos testers, acceso automático a todas las builds y relación activa; `selectedByAppStoreVersions=[]`.
- No se seleccionó ninguna build, no se modificaron metadata/trains y no hubo TestFlight externo, App Review ni publicación. Android, `artifact/`, AdMob, localizaciones y los dos scripts previos se conservan intactos.
- QA exacto visible: instalar expresamente TestFlight 1.0.6 (1); elegir modo `Todo`; empezar a grabar y hablar 10 segundos; abrir Siri 10 segundos; cerrarlo sin pulsar Stop/Grabar; esperar 20 segundos y hablar otros 10; abrir Ajustes sin cerrar la app y compartir `INTERNAL QA > Exportar diagnóstico de grabación`; solo después detener. Guardar el JSON sin editar.
- Repetir en una sesión nueva con el iPhone bloqueado: grabar/hablar, bloquear, invocar y cerrar Siri, esperar 20 segundos, desbloquear, hablar y exportar antes de detener o reiniciar. Enviar ambos JSON indicando cuál es `visible` y cuál `bloqueado`. Si la grabación sí vuelve, anotar el tiempo aproximado; si no vuelve, no tocar controles antes de exportar.

## Candidata interna iOS 1.0.5 (1): reconstrucción real tras Siri — 2026-08-30

- El propietario probó 1.0.4 (1) en iPhone: al abrir Siri la captura se detiene y no vuelve. La build queda considerada fallida y no puede promoverse ni reutilizarse como evidencia de estabilidad.
- La causa concreta es el desacople entre los tests de política y AVFoundation real. La recuperación de Siri, foreground y retry reactivaba `AVAudioSession`, pero pasaba `rebuildAudioObjects:false` y reutilizaba el mismo `AVAudioEngine`, `inputNode`, tap y formato. La app tampoco observaba `AVAudioEngineConfigurationChange`.
- Apple documenta que un cambio de sample rate o canales detiene y desinicializa el I/O unit del engine, conserva nodos con sus formatos anteriores y obliga a restablecer las conexiones si el formato cambia. También exige comprobar que el formato hardware del `inputNode` tenga sample rate y canales distintos de cero.
- La corrección local usa un `RecordingRecoveryDriver` inyectable y ordena cada intento: activar sesión; crear una generación nueva de `AVAudioEngine`; consultar el input y abrir el archivo; instalar tap e iniciar engine. Un fallo de input o start obliga a abandonar esa generación y reconstruir otra en el siguiente intento; un fallo de `setActive` reintenta sin tocar el engine hasta recuperar la sesión.
- Se observa `.AVAudioEngineConfigurationChange` para el engine vigente. El callback solo salta al main actor: no reconstruye dentro de la notificación. La identidad del objeto descarta eventos de generaciones antiguas y un ticket de invalidación impide que un intento en curso acepte éxito si su graph cambió; la política, `isPerformingRecovery` y el token del retry evitan backends o tareas duplicadas. Foreground continúa siendo una oportunidad independiente aunque un `Task.sleep` se haya suspendido.
- Interrupción, cambio de configuración, ruta, media-services y fallos reales conservan/finalizan el segmento válido una sola vez y reconstruyen el graph. Stop invalida el token y no toca un engine marcado como huérfano.
- Hay pruebas inyectadas del orden hardware, descarte de notificaciones de generaciones antiguas y fallos en `setActive`, input/formato cero y `engine.start`, además de los tests de política para fin omitido, foreground, Stop, preservación única de segmentos y no duplicación. La corrección se versiona como iOS 1.0.5 (1) porque cambia comportamiento después de 1.0.4 (1). Android, `artifact/`, AdMob, UI, localizaciones, temporizador futuro y los dos scripts previos permanecen intactos.
- Validación local Windows PASS: `git diff --check`, balance estructural de 35 Swift, manifiesto de privacidad, siete localizaciones con 129 claves idénticas/sin duplicados, ausencia del backend temporizado y cero diffs en Android o recursos iOS.
- La implementación está en `main` mediante `7072aee` y el ajuste de deduplicación mediante `b162787`. El primer run macOS `33326449264` detectó que una segunda notificación de fin podía abrir otra recuperación mientras la primera ya estaba recuperando; no se subió ningún binario desde ese run. La nueva fase `retryScheduled` cerró esa carrera.
- El run macOS `33326890651` terminó correctamente: prohibición de `AVAudioRecorder`/`record(forDuration:)`, 41 XCTest —incluidas generaciones/stale notification, invalidación durante recovery, fallos de `setActive`, formato cero, `engine.start`, finalización única y no duplicación— y compilación Release para dispositivo.
- El run firmado `33327128802` superó la puerta GDPR/ATT, archive y candidato firmados, exportación/verificación del IPA, validación de Apple y upload con `ad_configuration=test`. Apple procesó iOS 1.0.5 (1), recurso `549fc26d-3786-446d-a379-163485cbe57c`, como `VALID`, `INTERNAL_ONLY`, `IN_BETA_TESTING`, cifrado no exento `false` y testing externo `NOT_APPLICABLE`.
- El run `33327511155` confirmó disponibilidad automática en el grupo privado `Testers`, exactamente dos testers, acceso a todas las builds y `selectedByAppStoreVersions=[]`. No se creó ni modificó train de App Store, no hubo TestFlight externo, App Review ni publicación.
- 1.0.5 (1) usa IDs demo oficiales y existe solo para QA interno; no puede promoverse. La prueba física posterior falló de nuevo y queda sustituida como siguiente candidata de diagnóstico por 1.0.6 (1).

## TestFlight interno iOS 1.0.4 (1) — fallido en reanudación física — 2026-08-30

- La prueba física de 1.0.3 (1) reveló un bloqueo adicional: si el fin de Siri u otra interrupción llegaba sin `shouldResume`, `RecordingContinuityPolicy` conservaba intención pero no recuperaba ni programaba retry. Si tampoco cambiaba `scenePhase`, la captura quedaba pausada indefinidamente.
- La corrección local finaliza una sola vez el segmento válido, intenta recuperar al finalizar cualquier interrupción mientras siga vigente la intención explícita de grabar y mantiene un único retry cancelable cada cinco segundos para el caso en que Apple omita la notificación de fin o la sesión aún no pueda activarse.
- Se solicita a iOS la preferencia `setPrefersNoInterruptionsFromSystemAlerts(true)` durante grabación para evitar algunas alertas interrumpibles. No evita Siri, llamadas aceptadas ni decisiones del sistema; en esos casos conserva lo grabado y reanuda en cuanto `AVAudioSession` y `AVAudioEngine` vuelven a estar disponibles.
- La revisión de metadata oficial confirma que `interruptionNotification` sigue vigente en iOS, `shouldResume` se depreca solo desde iOS 27 y su sustituta `resumptionRecommendationNotification` nace en iOS 27 beta. Con deployment iOS 16 y Xcode/SDK 26.6 no corresponde ni compila observar todavía esa API; queda registrada una migración dual condicionada para cuando exista SDK iOS 27 estable. `setPrefersNoInterruptionsFromSystemAlerts` existe desde iOS 14.5 y es compatible con esta candidata.
- Stop cancela todo retry y las señales tardías no pueden iniciar un segundo backend. Las pruebas deterministas cubren fin con y sin recomendación, ausencia de fin, fallos repetidos, foreground, Stop, interrupciones múltiples, finalización única y backend ya activo.
- La fuente está en `main` mediante `ff46277`. El run macOS `33317813454` superó la prohibición de `AVAudioRecorder`/`record(forDuration:)`, todos los XCTest deterministas y compilación Release para dispositivo. El run firmado `33318104211` superó GDPR/ATT, archive, firma, versión/privacidad, IPA, validación Apple y upload con IDs demo oficiales.
- Apple procesó 1.0.4 (1), recurso `47d060ec-9a1d-44ed-be8f-5d06c26a6a80`, como `VALID`, `INTERNAL_ONLY`, `IN_BETA_TESTING`, cifrado no exento `false` y testing externo `NOT_APPLICABLE`. El run `33318596898` confirmó disponibilidad automática en el grupo privado `Testers`, exactamente dos testers, y `selectedByAppStoreVersions=[]`.
- Esta build era exclusivamente QA interno y la prueba física de Siri falló. No se creó ni modificó un train/versión de App Store, no se seleccionó la build, no hubo TestFlight externo, App Review ni publicación. No debe promoverse. Android, `artifact/`, AdMob, UI, localizaciones y los dos scripts locales previos permanecieron intactos.

## TestFlight interno iOS 1.0.3 (1) — rotación continua real — 2026-08-30

- La prueba física del propietario demostró que 1.0.2 (1) seguía deteniéndose exactamente en el primer corte de cinco minutos. La máquina de estados reintentaba, pero el modo `Todo` todavía llamaba a `AVAudioRecorder.record(forDuration:)`, API que finaliza la captura al expirar; el segundo grabador solo podía abrirse después y dejaba una ventana real sin backend.
- 1.0.3 elimina `AVAudioRecorder` del motor. `Todo` y `Por sonido` comparten una única captura `AVAudioEngine` que permanece activa durante toda la sesión; la rotación cambia únicamente el `AVAudioFile`. `Todo` escribe todos los buffers, incluido silencio, y `Por sonido` conserva su filtro.
- Durante la apertura del siguiente archivo se retienen hasta 128 buffers FIFO y se drenan en orden al nuevo segmento. Un fallo de apertura reintenta cada 500 ms sin apagar el micrófono; el límite de memoria sigue siendo explícito y un desbordamiento pasa a recuperación completa.
- Se corrigió otra carrera: las tareas de retry canceladas ignoraban `CancellationError` y podían ejecutar recuperaciones tardías. `RecordingRetryGate` impide esa ejecución y tiene prueba asíncrona determinista.
- La corrección binaria quedó en `3f3c9cf` (`2cf75bd` para el motor y `3f3c9cf` para la aserción XCTest). El run macOS `33284953418` superó la prohibición del backend temporizado, todos los XCTest y compilación Release para dispositivo.
- El run firmado `33285208649` superó la puerta GDPR/ATT, archive, firma, versión/privacidad, exportación, validación Apple y upload. Apple procesó la build `702f442b-7c5e-4977-a3b4-6f08aa99cbde` como `VALID`, `INTERNAL_ONLY`, `IN_BETA_TESTING`, cifrado no exento `false` y testing externo `NOT_APPLICABLE`. El grupo privado `Testers` tiene acceso automático y dos testers.
- App Store Connect contiene la versión 1.0.3 en `PREPARE_FOR_SUBMISSION`, release manual. Los runs protegidos `33285857956` y `33286090956` verificaron sus siete localizaciones (`ca`, `de-DE`, `en-US`, `es-ES`, `fr-FR`, `it`, `pt-PT`) con `https://krazel.github.io/audio-recorder/` como Marketing URL y `selectedBuildId=null`: esta build interna no está seleccionada para App Review.
- AdMob de producción continúa bloqueado: la cuenta/app/IDs reales no están activos y verificables y AdMob no reconoce todavía Developer Website. `app-ads.txt` y la Marketing URL responden HTTP 200, pero eso no demuestra la verificación dentro de AdMob. La build 1 usa IDs demo oficiales y no es candidata de producción.
- `docs/IOS_1.0.3_APP_REVIEW_PREFLIGHT.md` deja constancia del preflight histórico. No hubo TestFlight externo, App Review ni publicación. La reanudación tras Siri requiere la nueva candidata 1.0.4 (1) interna con IDs demo y QA físico. Si el código no cambia después de ese QA, la candidata de producción deberá ser 1.0.4 (2), con AdMob real verificado y un preflight repetido contra ese binario exacto. Android, `artifact/` y los dos scripts locales previos permanecen intactos.

## Ideas futuras registradas

- Temporizador opcional de grabación: permitir que el usuario elija una duración antes de empezar y que la app detenga y guarde automáticamente la grabación al cumplirse. No está autorizado ni planificado para la corrección actual; deberá diseñarse y probarse después de cerrar la estabilidad y la publicación actuales.

## TestFlight interno iOS 1.0.2 (1) — estabilidad de grabación — 2026-08-30

- La auditoría completa de `RecorderService` demostró varias causas independientes. La rotación cerraba el segmento actual antes de asegurar el siguiente y cualquier fallo terminaba en `stop()`. El watchdog marcaba como correcto cualquier `AVAudioRecorder.isRecording == false`, se ignoraba el fallo de `prepareToRecord()`, no se distinguían motivos de route change ni `shouldResume`, media-services reset reutilizaba objetos huérfanos y el modo por sonido no acotaba buffers pendientes.
- La corrección mantiene separadas la intención del usuario y la salud del backend. Solo Stop borra la intención; rotación fallida, cierre inesperado, error de escritura o entrada detenida guardan el segmento válido, muestran error, registran causa local y reintentan cada cinco segundos. El watchdog usa uptime monotónico y cubre `AVAudioRecorder` y `AVAudioEngine`.
- Interrupciones, rutas, background/foreground y media services tienen políticas explícitas. Se finaliza antes de una interrupción, se respeta la recomendación `shouldResume`, foreground repara la ausencia de un fin de interrupción, las rutas relevantes reabren con el formato vigente y un reset desecha/recrea `AVAudioEngine` antes de recuperar la sesión ya iniciada.
- `RecordingDiagnostics` conserva como máximo 200 eventos en Caches/Unified Log sin audio, nombres/rutas de archivos, rutas de hardware, cuentas ni contenido del usuario; no existe transmisión. `SoundActivatedAudioProcessor` limita a 64 los buffers pendientes y convierte una saturación en fallo recuperable.
- Se añadió `RecordingContinuityPolicy` y XCTest determinista para rotación repetida, fallo del siguiente segmento, interrupción/reanudación, route change, background/foreground, stop solicitado frente a stop inesperado, fallo/reintento y media-services lost/reset. Otras pruebas fijan el límite y esquema minimizado de la telemetría. La evidencia técnica y la matriz física están en `docs/IOS_RECORDING_STABILITY.md`.
- El propietario autorizó commit, push, visibilidad pública, build y carga a TestFlight. El commit `eb72a56` está en `main` y `Krazel/AudioRecorder` permanece `PUBLIC`. El run `33278736558` superó Xcode 26.6, puerta GDPR/ATT, todos los XCTest —incluidas las pruebas nuevas de continuidad—, archive firmado, verificaciones de versión/firma/privacidad, exportación IPA, validación de Apple y upload.
- Apple procesó 1.0.2 (1), recurso `a4ab24e5-b69e-4940-a6b8-edcb479fe34e`, como `VALID`, `INTERNAL_ONLY` e `IN_BETA_TESTING`. Está enlazada automáticamente al grupo privado `Testers`, con dos testers y acceso a todas las builds. El estado externo es `NOT_APPLICABLE`; no se envió a App Review ni se publicó una actualización.
- La comprobación contemporánea de AdMob mostró la cuenta desactivada por inactividad. Para no certificar una configuración de producción no verificable, 1.0.2 (1) usa los IDs demo oficiales y queda limitada contractualmente a TestFlight interno. Reactivar AdMob o preparar un binario de producción requiere trabajo y autorización separados; no debe promoverse esta build a testing externo ni App Review.
- Validación local Windows: `git diff --check`, igualdad y ausencia de duplicados en las siete tablas de localización, balance estructural Swift, JSON/plist y revisión de alcance pasan. La validación macOS/XCTest/archivo firmado también pasó en el run; la matriz física completa sigue pendiente.
- Riesgos residuales: `AVAudioRecorder` puede dejar un hueco pequeño entre archivos; iOS puede terminar un proceso sin callbacks; Bluetooth, llamadas/Siri/alarmas, reset de media services, poco espacio y sesiones sostenidas requieren iPhone real. Android y `artifact/` permanecen intactos.

## TestFlight iOS 1.0.1 (1) - 2026-08-28

- La correccion del cambio de modo durante una grabacion se versiono como iOS `1.0.1` build `1` en el commit `7446eb6` y se subio a `main` y a `agent/prepare-ios-test-build`.
- GitHub Actions run `33193618292` termino correctamente. Pasaron la validacion de toolchain, firma, configuracion AdMob de produccion, puerta GDPR/ATT, XCTest —incluidas las nuevas pruebas de modo—, archive firmado, exportacion IPA, validacion de Apple y carga a App Store Connect.
- La carga fue aceptada por App Store Connect. La sesion web disponible no esta autenticada, por lo que el estado asincrono posterior de procesamiento y aparicion en TestFlight no se pudo consultar directamente desde esta tarea.
- El workflow solo cargo el binario; no lo envio a App Review ni publico una nueva version en App Store.
- Tras completar el run, `Krazel/AudioRecorder` volvio a visibilidad `PRIVATE`, como autorizo el propietario. Las paginas legales y `app-ads.txt` viven en `krazel.github.io` y no se ven afectadas.
- Android y `artifact/` permanecen intactos. Los cambios locales previos de documentacion y scripts se conservaron fuera del commit de la app.

## Correccion local del cambio de modo durante grabacion - 2026-08-28

- Se confirmo un fallo iOS al cambiar `Por sonido`/`Todo` con una grabacion activa: el selector actualizaba la preferencia y la interfaz, pero el backend continuaba en el modo anterior. En una rotacion, reanudacion o recuperacion podia mezclar `AVAudioEngine` y `AVAudioRecorder`, iniciar el backend equivocado o mantener `isRecording` sin un backend valido.
- La correccion local desactiva unicamente el selector de modo mientras se graba, conserva el modo inicial de la sesion en todos sus segmentos y recuperaciones, y muestra en la pantalla de grabacion el modo realmente activo. El modo puede cambiarse de nuevo al detener la grabacion y se aplicara al siguiente inicio.
- Se anadio `RecordingModeSessionPolicy` con pruebas para bloquear ambos sentidos (`Todo` a `Por sonido` y `Por sonido` a `Todo`) durante una sesion, manteniendo el modo configurado antes de comenzar.
- `git diff --check` no detecta errores. Windows no dispone de Xcode, por lo que quedan pendientes XCTest/compilacion en macOS y prueba fisica en ambos modos, incluyendo rotacion de segmento, segundo plano/primer plano e interrupcion de audio.
- En esa fase previa aun no se habia hecho commit, push ni build; la compilacion y carga posteriores quedan registradas en la seccion superior. Android y `artifact/` no se modificaron.

## Publicacion y verificacion de AdMob - 2026-08-25

- Apple publica iOS 1.0 en App Store con ID `6772278149`, bundle `com.dmkr.audio.B2X6D3A9J9` y URL `https://apps.apple.com/es/app/grabadora-de-voz-pro-audio-k/id6772278149`.
- AdMob ya tiene seleccionada y guardada esa ficha para la aplicacion `2340753104`. El App ID real es `ca-app-pub-3425091654264901~2340753104` y existe un unico bloque banner real `ca-app-pub-3425091654264901/5497133550`; ambos coinciden con la build publica.
- El Centro de Politicas de AdMob no muestra problemas. El mensaje de Reglamentos europeos conserva un mensaje activo y no se ha creado el mensaje explicativo remoto de IDFA, de acuerdo con la puerta local GDPR/ATT aprobada por Apple.
- La comprobacion inmediata de AdMob aun muestra `No hemos podido verificar` para `app-ads.txt`. La fuente publica de Apple declara `https://krazel.github.io/audio-recorder/` como sitio del desarrollador y `https://krazel.github.io/app-ads.txt` responde HTTP 200, `text/plain`, con exactamente `google.com, pub-3425091654264901, DIRECT, f08c47fec0942fa0`. Se solicito `Buscar actualizaciones`, pero Google todavia no ha propagado la verificacion; no falta ningun cambio local ni de la web.
- Hasta que AdMob complete el rastreo/verificacion y la revision de disponibilidad, la app puede enviar solicitudes pero recibir cero impresiones. El siguiente paso es volver a comprobar el estado tras la propagacion de Google, sin generar otra build.

## App Review - 2026-08-21

- Apple procesó iOS 1.0 (11), recurso `d68a22da-42b9-40c8-ab8e-e44eb4586937`, como `VALID`, `APP_STORE_ELIGIBLE` y no caducada. La candidata corresponde al commit `b86b73a` y al GitHub Actions run `32434875228`.
- La build 11 conserva el banner dinámico de la build 10 y hace desplazable la pantalla de grabación en cualquier dispositivo cuando la altura disponible no basta. En pantallas donde el contenido cabe, `minHeight` conserva la composición; el escalado de métricas solo actúa si un valor no cabe en una línea.
- El workflow superó XcodeGen, las pruebas GDPR/ATT, archive firmado, verificaciones de privacidad y AdMob, exportación, validación de Apple y upload.
- La versión 1.0 selecciona build 11, mantiene `usesIdfa=true` y publicación `MANUAL`. La submission `059cf56f-4f6d-48b0-baa8-14a8e8e719fb` está `WAITING_FOR_REVIEW` con exactamente nueve elementos: app, versión del grupo y las siete versiones de suscripción. No se duplicó ni recreó ningún producto.
- Las notas privadas explican la corrección de Guideline 4, las rutas de prueba de iPhone/iPad compatible, la puerta GDPR/ATT y el precio intencional de USD 44.99. La app todavía no está publicada y una eventual aprobación no la publicará automáticamente.
- Android permanece sin diferencias y `artifact/` sigue preservado sin seguimiento.

## Preparación previa de TestFlight y App Review - 2026-08-21

- Apple rechazó iOS 1.0 (9) bajo Guideline 4 por una interfaz inferior abarrotada o difícil de usar en iPhone 17 Pro Max y en el modo de compatibilidad iPhone de un iPad Air 11-inch (M3). La versión 1.0 sigue `REJECTED`, selecciona históricamente build 9 y conserva publicación manual.
- La causa local confirmada era doble: el banner se superponía a toda la `TabView` e ignoraba la zona segura; además, `RecorderView` era una pila vertical no desplazable que podía solaparse o truncarse en la ventana compatible del iPad.
- El commit reversible `f548298` corrige únicamente iOS. El banner se prepara sin ocupar espacio y, al recibir un anuncio real, reserva exactamente 50 puntos como hermano de la `TabView`, desplaza la barra inferior y deja de interceptarla. Si el anuncio falla o los anuncios se desactivan, el hueco vuelve automáticamente a cero.
- El diseño normal de iPhone conserva sus tamaños y composición. Solo en hardware iPad, detectado por idiom/modelo, la pantalla de grabación usa desplazamiento vertical y permite reducir el texto de las métricas para evitar el recorte observado.
- GitHub Actions run `32432124526` compiló y probó iOS 1.0 (10), commit `f548298`; firma, archive, privacidad, AdMob, IPA, validación de Apple y upload terminaron correctamente.
- Apple procesó build 10, recurso `f8bb39d4-b9f1-4522-b0f2-ff99f1670cb9`, como `VALID`, `APP_STORE_ELIGIBLE`, no caducada y `IN_BETA_TESTING`. El grupo privado interno `Testers` tiene acceso automático y dos testers; no existe enlace público ni se solicitó Beta App Review.
- Build 10 no está seleccionada en la versión de App Store y no se ha enviado a App Review. La siguiente acción es probar en iPhone el banner apareciendo/desapareciendo y, si es posible, repetir el caso en un iPad antes de preparar un nuevo envío.
- El estado anterior completo puede recuperarse revirtiendo únicamente `f548298`; su padre es `fb9a5fb`. Android y `artifact/` permanecen intactos.

## Estado de App Store Connect - 2026-08-18

- El icono blanco aprobado `IOS-ICON-WHITE-002` es el vigente en producción; el negro `IOS-ICON-BLACK-001` permanece preservado como predecesor. La build 9 contiene exactamente la maestra blanca aprobada.
- iOS 1.0 (9), commit `f722e1b`, superó XCTest, firma, archive, validaciones de privacidad, exportación, validación de Apple y carga mediante GitHub Actions run `32162795001`. Apple la procesó como `VALID`, `APP_STORE_ELIGIBLE` y no caducada; recurso `c68a13fd-94ea-4982-bffb-393d66c2f73b`.
- La versión 1.0 selecciona build 9, mantiene `usesIdfa=true` y `releaseType=MANUAL`. La nueva submission `059cf56f-4f6d-48b0-baa8-14a8e8e719fb` está `WAITING_FOR_REVIEW` con exactamente nueve elementos: versión de la app, versión del grupo y las siete versiones de suscripción.
- Las notas privadas de App Review se actualizaron a build 9 e incluyen una respuesta explícita a 5.1.1(iv), la ruta europea `Do not consent` sin ATT, los fallos cerrados, los caminos regionales y el precio mensual intencional de USD 44.99. La API pública de App Store Connect no permite publicar mensajes en el hilo de revisión y el control de navegador continúa bloqueado por el problema conocido del plugin; la respuesta sí está visible para revisión en las notas del nuevo envío.
- La publicación final permanece manual: una aprobación de Apple no hará pública la app automáticamente.
- La candidata iOS 1.0 (8), commit de aplicación `88bc460`, se compiló, probó, firmó, validó y subió mediante GitHub Actions run `32160772323`. Apple la procesó como `VALID`, `APP_STORE_ELIGIBLE` y no caducada; recurso de build `8c9700dc-6582-42c4-aa07-cf857c1d43d5`.
- Históricamente, la submission de build 8 se canceló antes de comenzar la revisión para corregir el icono. Apple la dejó `COMPLETE`; no se borró ningún producto ni se publicó la app.
- La política pública corregida responde HTTP 200 con el comportamiento de consentimiento vigente.
- Apple detuvo la revisión de iOS 1.0 (7) bajo 5.1.1(iv): en el flujo europeo, la app mostraba ATT inmediatamente después de que el usuario pulsara `Do not consent` en UMP.
- Causa confirmada: `canRequestAds` permite iniciar algún modo de anuncios, incluidos limitados/no personalizados, pero la build 7 lo trataba incorrectamente como consentimiento para pedir tracking y llamaba directamente a `ATTrackingManager.requestTrackingAuthorization`.
- La candidata local 1.0 (8) sustituye esa condición incorrecta por una puerta explícita y conservadora. En Europa solo solicita ATT cuando las señales TCF posteriores a UMP autorizan almacenamiento, perfil y selección de publicidad personalizada, las bases operativas y Google como proveedor 755. Rechazo, ausencia, error o valor malformado implican cero ATT. `canRequestAds` queda limitado a iniciar Google Mobile Ads.
- La ayuda oficial de AdMob indica que publicar el mensaje IDFA puede hacer que el propio mensaje europeo se muestre inmediatamente antes de ATT. Para no repetir el rechazo, el mensaje IDFA permanece sin publicar y la app controla la solicitud ATT con la puerta anterior. Fuera del ámbito europeo puede solicitar ATT después de actualizar UMP.
- Se añadieron pruebas unitarias para rechazo europeo, consentimiento completo, región ausente, propósitos incompletos y proveedor Google incompleto. El workflow ejecuta esas pruebas antes del archive e impide una subida de producción si no se confirma que el mensaje IDFA sigue sin publicar.
- La política local y la copia pública de GitHub Pages describen la secuencia corregida.
- El icono público vigente es la maestra blanca `IOS-ICON-WHITE-002`; la maestra negra `IOS-ICON-BLACK-001` se conserva sin borrar.
- Android y `artifact/` permanecen fuera de alcance e intactos. La publicación final continúa manual.

## Estado anterior de App Store Connect - 2026-08-15 15:38 CEST

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

Última revalidación: 2026-08-18.

> Estado histórico: la build 7 superó la validación binaria y se envió con nueve elementos, pero Apple detuvo después la revisión por el orden UMP/ATT descrito arriba.

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

## Candidata local de produccion iOS 1.0.8 (1) - 2026-08-31

- La fuente local integra el watchdog basado en buffers reales, proteccion de archivos y recuperacion de segmentos no indexados de la candidata 1.0.8. No hay commit, push, Actions, build ni subida.
- Se elimino de Ajustes toda la seccion `INTERNAL QA`, su boton, alertas, hoja de compartir y la generacion/exportacion del JSON. La app de produccion no conserva un fichero de 200 eventos ni expone diagnostico al usuario.
- La observabilidad restante se limita a codigos tecnicos fijos en Unified Log. No escribe audio, contenido, nombres/rutas, UUID de sesion, hardware, cuentas ni datos de llamadas. El diario minimo de ejecucion permanece local y protegido para reconocer una ejecucion anterior terminada sin Stop; solo contiene UUID aleatorios y fechas.
- `native-ios/project.yml` conserva los IDs demo oficiales para que una ejecucion de desarrollo nunca genere clics reales. El workflow de App Store selecciona `production` por defecto, inyecta los IDs reales desde secrets protegidos, valida formato, rechaza IDs demo y vuelve a comprobar los IDs dentro del archive.
- UMP continua siendo la puerta de anuncios (`canRequestAds`); Mobile Ads no arranca antes. ATT solo se solicita cuando las senales TCF permiten tracking y nunca inmediatamente despues de retirar/rechazar consentimiento. Ajustes conserva opciones de privacidad cuando UMP las exige.
- StoreKit conserva siete productos mensuales verificados, restauracion, gestion/cancelacion, privacidad y EULA; cualquier suscripcion activa retira anuncios.
- `PrivacyInfo.xcprivacy` declara unicamente File Timestamp y UserDefaults como Required Reason APIs, sin dominios de tracking propios. `Info.plist` conserva microfono, ATT, background audio, IDs AdMob parametrizados y cifrado no exento `false`.
- Se elimino el scaffolding compilado pero inactivo de nube: cola, proveedores, iCloud/Drive/OneDrive, endpoint de servidor, token Bearer y POST multipart. Al iniciar se borran las cuatro preferencias heredadas; compartir grabaciones sigue siendo local mediante la hoja de iOS.
- Riesgo externo pendiente: antes de distribuir hay que demostrar en CI macOS/XCTest/Release que la fuente exacta compila y que los secrets protegidos contienen los mismos IDs reales. La consola AdMob/UMP y la ficha App Privacy deben verificarse contra el binario exacto; eso no puede certificarse desde Windows.

Proximo paso coordinado: integrar esta fuente sin los dos scripts ajenos ni `artifact/`, ejecutar CI macOS con `ad_configuration=production` y sin upload primero, revisar el archive exacto y completar QA fisico. Las llamadas aceptadas pueden suspender una app general; la recuperacion automatica solo puede ejecutarse cuando iOS vuelve a darle tiempo de proceso o al regresar a foreground.
