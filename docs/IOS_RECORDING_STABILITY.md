# VoiceRecorder iOS — estabilidad de grabación y candidata 1.0.7

Fecha de auditoría: 2026-08-30
Alcance: `native-ios/`; Android, distribución y servicios externos fuera de alcance.

## Causa demostrada en 1.0.6: `!int` impide recuperar desde background

La traza física distingue recuperación al volver a foreground de continuidad
real en background. Siri comenzó a las `00:01:57Z`; los intentos de activación
de `00:01:57Z`, `00:02:02Z`, `00:02:03Z` y `00:02:08Z` fallaron con
`560557684` (`0x21696E74`, `!int`). Apple define ese valor como
[`AVAudioSession.ErrorCode.cannotInterruptOthers`](https://developer.apple.com/documentation/coreaudiotypes/avaudiosessionerrorcode/avaudiosessionerrorcodecannotinterruptothers):
una app en background intentó activar una sesión no mezclable. La activación
solo tuvo éxito a las `00:02:09Z`, al comenzar el retorno de la app; el primer
buffer escrito llegó a las `00:02:10Z`. El propietario confirma que, si no abre
la app, el indicador naranja no reaparece y no se graba.

`playAndRecord` es no mezclable por defecto. Apple permite hacerla cooperativa
con
[`mixWithOthers`](https://developer.apple.com/documentation/avfaudio/avaudiosession/categoryoptions-swift.struct/mixwithothers),
y el proyecto ya declara `UIBackgroundModes=audio`. La candidata 1.0.7 (1)
centraliza estas opciones:

```swift
[.allowBluetoothHFP, .defaultToSpeaker, .mixWithOthers]
```

Esto evita que la reactivación necesite interrumpir otra sesión desde
background. No elimina la exclusividad del micrófono mientras Siri lo usa: el
primer segmento se conserva y el retry continúa hasta que Siri libere la ruta.
El coste es que audio de otras apps puede seguir reproduciéndose y entrar por
el micrófono. No se añaden `duckOthers` ni
`interruptSpokenAudioAndMixWithOthers`.

QA físico obligatorio: empezar en modo Todo, hablar 10 segundos, abrir Siri,
cerrarlo y no volver a VoiceRecorder durante 20 segundos. El indicador naranja
debe reaparecer estando todavía fuera de la app. Después volver, hablar 10
segundos, exportar el diagnóstico, pulsar Stop y reproducir ambos segmentos. El
segundo debe contener esa voz. Repetir con pantalla bloqueada y con Bluetooth
HFP conectado/desconectado. Stop durante Siri no debe reactivar nada.

La candidata quedó en `main` mediante `181fe83`. `33346790879` pasó XCTest y
Release y `33347088605` pasó firma, archive, privacidad, IPA, validación Apple y
upload con IDs demo. El finalizador `33347538527` confirmó la build Apple
`82c918a0-19e3-4528-858b-06dbb6912af1` como `VALID`, `INTERNAL_ONLY` e
`IN_BETA_TESTING`, asignada automáticamente al grupo privado de dos testers y
sin ninguna versión App Store seleccionándola. No hubo App Review ni
publicación.

## Fallo físico confirmado en 1.0.5 (1): evidencia insuficiente del dispositivo

El propietario repitió la prueba en iPhone: Siri detiene la captura y cerrarlo
no la reactiva. Por tanto 1.0.5 (1) queda fallida. Los tests demostraron la
máquina de estados y el orden de closures inyectados, pero no pueden probar qué
notificaciones, errores ni formatos entrega AVFoundation en el dispositivo. Aún
no se puede afirmar si falta el `ended`, si el `began` llegó retrasado por una
suspensión, si falla `setActive`, si el input queda a cero, si `engine.start()`
termina sin producir buffers o si una señal cancela el retry.

## Instrumentación diagnóstica local 1.0.6 (1)

La candidata local amplía el rastro acotado y privado con:

- tipo y options de la interrupción, `AVAudioSessionInterruptionReasonKey` y
  `AVAudioSessionInterruptionWasSuspendedKey`;
- background y active, configuration change y generación del engine;
- intención, `engine.isRunning`, último sample rate/canales observado,
  estado interrumpido/recovering y existencia de retry;
- intento y resultado de `activateSession`, rebuild, apertura del segmento e
  instalación del tap/`engine.start()`, con domain/code numérico del error;
- programación, deduplicación, disparo y cancelación de retries;
- primer callback de buffer tras recuperar y si ya había escritura en esa
  primera vuelta.

`RecordingDiagnostics` conserva como máximo 200 eventos. La exportación crea un
JSON con esquema 1, fecha, versión, build e iOS. No contiene audio,
transcripciones, nombres o rutas, identificadores de hardware, cuentas ni datos
introducidos por el usuario, y no tiene transporte. La acción provisional
`INTERNAL QA > Exportar diagnóstico de grabación` vive en Ajustes y solo se
muestra cuando el binario usa el App ID demo oficial de Google; una build con
AdMob real no puede mostrarla.

Procedimiento de evidencia: comenzar a grabar, esperar unos segundos, abrir
Siri, mantenerlo activo, cerrarlo, esperar al menos 15 segundos y exportar el
JSON inmediatamente. Repetir una vez con la app visible y otra bloqueada. No
reiniciar ni reinstalar entre el fallo y la exportación.

La fuente diagnóstica quedó en `7df0dea`. `33340707076` pasó XCTest y Release;
`33340921074` archivó, firmó, validó y subió 1.0.6 (1) con IDs demo. El
finalizador de solo lectura `33341464009` confirmó el recurso Apple
`53a1f112-27b7-4e31-be57-a2f5a130b73f` como `VALID`, `INTERNAL_ONLY`,
`IN_BETA_TESTING`, cifrado no exento falso y externo `NOT_APPLICABLE`. El grupo
privado `Testers` (`9fb339bc-471a-438f-bc2e-f9961e974cee`) tiene dos testers,
acceso automático a todas las builds y relación activa; ninguna versión App
Store selecciona el binario. No hubo testing externo, Review ni publicación.

### QA exacto para obtener dos trazas comparables

1. En TestFlight, instalar y abrir expresamente **1.0.6 (1)**. No usar 1.0.5.
2. Seleccionar modo `Todo`, iniciar la grabación y hablar durante 10 segundos.
3. Abrir Siri, mantenerlo activo 10 segundos y cerrarlo. No pulsar Stop ni
   Grabar durante la interrupción o la espera.
4. Esperar 20 segundos completos y hablar otros 10 segundos.
5. Sin cerrar ni reiniciar la app, entrar en Ajustes y usar
   `INTERNAL QA > Exportar diagnóstico de grabación`. Guardar/compartir el JSON
   sin editar y etiquetarlo como `visible`.
6. Solo después de exportar, detener la grabación.
7. Iniciar una sesión nueva y repetir: hablar, bloquear el iPhone, invocar Siri,
   cerrarlo, esperar 20 segundos, desbloquear, hablar y exportar antes de
   detener. Etiquetar este JSON como `bloqueado`.

Si la captura vuelve, anotar aproximadamente cuántos segundos tardó. Si no
vuelve, no intentar arreglarla tocando controles antes de exportar: esos eventos
son precisamente la evidencia necesaria. Los dos JSON, no capturas de pantalla,
permitirán comparar notificaciones, suspensión, etapas y primer buffer.

## Causas demostradas en la fuente 1.0.1

1. La rotación no era transaccional. `startNewSegment()` completaba el segmento
   vigente antes de demostrar que el nuevo destino se podía crear. Cualquier
   error posterior terminaba en `rotateSegment() -> catch -> stop()`, borraba la
   intención persistida y convertía un fallo recuperable de apertura/escritura
   en una parada total.
2. El watchdog de `AVAudioRecorder` trataba cualquier `isRecording == false`
   como final correcto. Una interrupción, un cierre del backend o un error sin
   callback a tiempo se clasificaban como rotación normal y podían dejar al
   usuario sin una causa útil.
3. Se ignoraba el resultado booleano de `prepareToRecord()`. Un archivo que no
   se pudiera preparar solo se detectaba tarde, al intentar grabar.
4. Las interrupciones no leían `AVAudioSessionInterruptionOptionShouldResume`.
   Los cambios de ruta tampoco distinguían su motivo; no reconstruían de forma
   deliberada el tap y formato de `AVAudioEngine` cuando cambiaba el hardware.
5. El reset de media services reutilizaba el mismo `AVAudioEngine`, aunque Apple
   indica que los objetos de audio huérfanos deben desecharse y recrearse.
   Tampoco se observaba la pérdida previa de media services.
6. El procesador por sonido no limitaba buffers pendientes. Un atasco sostenido
   de escritura podía crecer sin cota y terminar por presión de memoria.
7. La auditoría inicial retiró `mixWithOthers` para aislar la grabación y
   unificar captura/reproducción. La evidencia física posterior de 1.0.6
   sustituye esa decisión: la sesión no mezclable no puede recuperarse en
   background tras Siri. Desde 1.0.7, captura y reproducción usan la misma
   política mezclable para que ningún componente revierta la opción compartida.

La revisión no atribuye todas las paradas reales a una sola causa. Los puntos
1–5 contienen caminos concretos capaces de producir la rotación fallida o una
parada sin explicación; el punto 6 es un riesgo de sesiones sostenidas.

## Fallo físico confirmado en 1.0.2 (1)

Una grabación real en modo `Todo` volvió a detenerse exactamente al alcanzar el
primer corte de cinco minutos. La causa restante era arquitectónica:
`record(forDuration:)` detiene deliberadamente `AVAudioRecorder` al llegar al
límite y la app intentaba crear otro grabador después. Durante ese intervalo ya
no existía captura activa y iOS podía suspender el proceso antes de completar la
reanudación. Además, las tareas canceladas de retry ignoraban el error de
cancelación y podían ejecutar una recuperación tardía.

## Fallo físico confirmado en 1.0.3 (1): Siri/interrupciones

El propietario confirmó en TestFlight que, después de Siri u otra interrupción,
la captura no siempre volvía sola. La causa concreta estaba en la transición de
fin: si iOS entregaba `.ended` sin `shouldResume`, la política conservaba la
intención pero devolvía `.none`; tampoco programaba retry al comenzar la
interrupción. Si Siri no provocaba después un cambio de `scenePhase` a activo —o
si no llegaba notificación de fin— no quedaba ningún evento que reabriera el
backend y la sesión permanecía pausada indefinidamente.

## Fallo físico confirmado en 1.0.4 (1): graph AVAudioEngine reutilizado

La prueba en iPhone volvió a fallar: Siri detuvo la captura y al cerrarlo nunca
regresó. 1.0.4 corregía la transición de intención, pero la recuperación real
seguía llamando `recoverRecordingBackend(rebuildAudioObjects: false)`. Después
de reactivar `AVAudioSession` reutilizaba el mismo `AVAudioEngine`, `inputNode`,
tap y formato anterior. Los tests solo sustituían eventos en la política y no
podían detectar un I/O unit desinicializado o un formato hardware inválido.
Además, no existía observador de `AVAudioEngineConfigurationChange`, por lo que
una invalidación del graph podía quedar fuera de interrupción, ruta y watchdog.

## Contratos de Apple aplicados

- [`record(forDuration:)`](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/record%28forduration%3A%29)
  detiene el grabador al alcanzar el límite, y el delegate informa tanto del
  final como de errores de codificación.
- [Responding to Interruptions](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html)
  exige guardar estado al comenzar, reactivar la sesión cuando proceda y asumir
  que puede no llegar una notificación de fin.
- [`shouldResume`](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionoptions/shouldresume)
  es una recomendación para decidir si resulta apropiado reanudar reproducción
  automáticamente. Apple indica que las apps que no necesitan una nueva acción
  del usuario pueden ignorarla. En VoiceRecorder el botón Grabar ya pulsado es
  la intención explícita vigente, por lo que un fin con o sin esa recomendación
  abre una oportunidad de recuperación.
- La metadata oficial vigente de Apple sitúa la deprecación de
  `InterruptionOptions.shouldResume` en iOS 27.0. Su sustituta,
  [`resumptionRecommendationNotification`](https://developer.apple.com/documentation/avfaudio/avaudiosession/resumptionrecommendationnotification),
  se introduce también en iOS 27.0 y todavía está marcada como beta.
  `interruptionNotification` continúa sin deprecación en iOS. La candidata usa
  Xcode/SDK 26.6 y admite iOS 16+, por lo que la notificación clásica es el único
  contrato disponible y correcto para iOS 16–26. Al adoptar un SDK estable que
  conozca iOS 27 se deberá añadir observación condicional de la nueva señal en
  iOS 27+, mantener fallback clásico en iOS 16–26 y deduplicar ambas mediante la
  misma máquina de estados; no se referencia ahora una API ausente del SDK.
- [`setPrefersNoInterruptionsFromSystemAlerts(_:)`](https://developer.apple.com/documentation/avfaudio/avaudiosession/setprefersnointerruptionsfromsystemalerts%28_%3A%29)
  reduce algunas interrupciones de alertas del sistema —por ejemplo llamadas
  presentadas como banner—, pero Apple aclara que es solo una preferencia y no
  evita llamadas aceptadas, Siri ni todos los casos. Un fallo al aplicar esta
  preferencia no impide iniciar la grabación y queda diagnosticado localmente.
  Apple la declara disponible desde iOS 14.5 y la recomienda expresamente para
  sesiones que graban medios audiovisuales; por tanto es válida con deployment
  iOS 16 y la categoría de entrada `playAndRecord` usada por la app.
- [Responding to Route Changes](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioHardwareRouteChanges/HandlingAudioHardwareRouteChanges.html)
  requiere leer el motivo y volver a consultar formato, frecuencia y canales.
- [`mediaServicesWereResetNotification`](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification)
  exige recrear grabadores, engines, convertidores/colas y la configuración de
  sesión. La app considera el botón Grabar ya pulsado y la intención persistida
  de esa sesión como la acción explícita del usuario; no inicia una sesión nueva
  después del reset.
- [`mediaServicesWereLostNotification`](https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswerelostnotification)
  se usa únicamente para congelar estado y esperar el reset.
- [`AVAudioEngine.inputNode`](https://developer.apple.com/documentation/avfaudio/avaudioengine/inputnode)
  requiere frecuencia y canales no nulos antes de capturar.
- [`AVAudioEngineConfigurationChange`](https://developer.apple.com/documentation/foundation/nsnotification/name-swift.struct/avaudioengineconfigurationchange)
  se emite cuando el I/O unit observa un cambio de sample rate o canales. Apple
  indica que el engine se detiene y desinicializa, mientras los nodos conservan
  las conexiones y formatos anteriores; la app debe restablecer conexiones si
  cambia el formato. VoiceRecorder reconstruye el graph fuera del callback y
  filtra la notificación por identidad del engine vigente.
- [`AVAudioApplication.requestRecordPermission`](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission%28completionhandler%3A%29)
  es la ruta vigente desde iOS 17; iOS 16 conserva el fallback de
  `AVAudioSession`.
- [`playAndRecord`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord)
  continúa bajo bloqueo de pantalla y en segundo plano con `UIBackgroundModes`
  `audio`; por defecto es no mezclable.

## Políticas de la fuente corregida posterior a 1.0.4 (1)

- Solo `stopRequested` borra la intención y desactiva la sesión. Un final
  inesperado, fallo de escritura o fallo al abrir el segmento siguiente guarda
  lo recuperable, mantiene `isRecording` como intención y reintenta cada cinco
  segundos.
- Ambos modos usan una sola captura `AVAudioEngine` durante toda la sesión. La
  separación cambia únicamente el `AVAudioFile`; nunca detiene el input node.
- Mientras se abre el archivo siguiente, los buffers se conservan en una cola
  FIFO acotada a 128 elementos y se escriben en orden al nuevo segmento. Un
  fallo de apertura reintenta cada 500 ms sin apagar el engine. Si la espera
  supera la cota se informa un fallo y se entra en recuperación completa.
- El watchdog exige engine, generación de procesador y actividad real de
  buffers para ambos modos. `Todo` escribe todos los buffers, incluido silencio;
  `Por sonido` conserva su umbral y cola final.
- Al comenzar una interrupción se finaliza una sola vez el fragmento válido y
  se conserva la intención. Se mantiene un único retry cancelable cada cinco
  segundos porque Apple no garantiza que llegue la notificación de fin.
- Al finalizar la interrupción se intenta reabrir inmediatamente un segmento
  tanto con `shouldResume` como sin él. Si `setActive(true)` o el engine todavía
  fallan, la recuperación continúa por el retry acotado; foreground es otra
  oportunidad inmediata. Stop cancela la tarea y ninguna señal tardía puede
  volver a crear el backend.
- Cada recuperación de hardware ejecuta el mismo orden: activar la sesión;
  abandonar el graph anterior y crear una generación de engine nueva; consultar
  el formato hardware y abrir el archivo; instalar el tap e iniciar el engine.
  Un input con sample rate/canales cero o un fallo de start invalida esa
  generación y el retry siguiente crea otra. Un fallo de activación no usa el
  engine mientras iOS aún niega el micrófono.
- La notificación de configuración nunca reconstruye dentro del callback. Salta
  al main actor, exige que el objeto sea el engine vigente y se deduplica con la
  recuperación activa. Un ticket de invalidación hace que un intento en curso
  falle cerrado si su graph cambia antes de confirmar éxito; entonces queda un
  retry garantizado. El engine retirado se detiene y libera fuera del callback,
  junto con su tap, antes de iniciar la generación nueva. Foreground constituye
  una oportunidad independiente del `Task.sleep`; el retry usa token para que
  una tarea cancelada no vuelva tarde.
- La sesión solicita que las alertas del sistema no interrumpan cuando iOS pueda
  respetarlo. Esta preferencia no se presenta como garantía y se desactiva al
  terminar voluntariamente la sesión.
- Conectar, retirar o perder una ruta reinicia en un segmento nuevo y vuelve a
  consultar el formato. `override`, `categoryChange` y `wakeFromSleep` no fuerzan
  un corte si el backend sigue sano.
- En media-services lost se espera. En reset se descartan los objetos huérfanos,
  se crea un `AVAudioEngine` nuevo, se reaplica la sesión y se recupera solo la
  sesión que ya tenía intención activa.
- Entrar en background no detiene. Al volver a foreground se compara intención
  con backend real y se repara cualquier divergencia.
- Un máximo de 64 buffers pendientes limita la presión normal de la cola de
  proceso. La cola temporal de rotación tiene su propia cota de 128. Cualquier
  desbordamiento se trata como fallo diagnosticado y recuperable.
- Cancelar un retry impide que su acción se ejecute más tarde; Stop,
  interrupción, route change y recuperación invalidan tanto el retry general
  como el de rotación.
- Los archivos no indexados siguen recuperándose desde `Documents/Recordings`
  al cargar la biblioteca. Un fallo del índice no elimina el audio.

## Telemetría local

`RecordingDiagnostics` conserva como máximo 200 eventos JSON en
`Library/Caches/RecordingDiagnostics/events.json` y los replica en Unified Log.
Solo contiene fecha, UUID efímero de sesión, código de ciclo de vida, fase,
modo y dominio/código numérico del error. No contiene audio, transcripciones,
nombres o rutas de archivo, nombre de dispositivo/ruta, cuentas, publicidad ni
contenido introducido por el usuario. No existe código de envío y Caches puede
ser purgado por iOS.

## Pruebas automatizadas

`RecordingContinuityPolicyTests` cubre:

- cinco rotaciones consecutivas;
- error al preparar el segmento siguiente sin perder intención;
- interrupción con y sin recomendación de reanudar, ambas con recuperación;
- ausencia de notificación de fin y oportunidad posterior por retry;
- fallos repetidos de activación/engine hasta recuperación;
- Stop durante interrupción y señales tardías sin reinicio;
- interrupciones múltiples, finalización única y ausencia de doble backend;
- cambio de ruta relevante frente a override no disruptivo;
- background/foreground con backend activo e inactivo;
- stop solicitado frente a fallo inesperado;
- fallos/reintentos de audio y recuperación;
- media-services lost/reset con reconstrucción.

`RecordingDiagnosticsTests` comprueba el límite del buffer local y que el
esquema codificado no incluye campos de audio, archivo/ruta o transcripción.

`ContinuousSegmentRotationTests` fija que ambos modos usan el engine continuo,
que separar un archivo no detiene la captura, que la cola de rotación conserva
orden y límite y que un retry cancelado no puede ejecutarse después.

`RecordingRecoveryDriverTests` inyecta fallos en los límites de hardware y fija
el orden `setActive` → rebuild → input/archivo → tap/start. Demuestra que un
formato cero o un fallo de `engine.start()` obliga a una generación nueva en el
intento siguiente, y que un fallo de `setActive` no toca el engine antes de que
la sesión vuelva a estar disponible. También verifica que una notificación de
configuración perteneciente a una generación retirada —o sin engine— se ignora,
y solo el engine vigente abre una oportunidad de recuperación. Un test de carrera
invalida un intento en curso antes de aceptar éxito, y el gate de segmento prueba
que señales repetidas solo pueden finalizar una vez cada archivo válido.

La puerta manual `.github/workflows/verify-ios-recording-stability.yml` genera
el proyecto, ejecuta XCTest en simulador, compila Release para dispositivo sin
firma y conserva el `.xcresult`. El run `33326449264` detectó antes de distribuir
una recuperación duplicada entre dos fines de interrupción; la nueva fase
`retryScheduled` la corrigió. El run `33326890651` pasó después los 41 XCTest y
Release device. Los commits distribuidos son `7072aee` y `b162787`.

## Matriz de QA físico pendiente

1.0.4 (1) queda invalidada por el fallo físico de Siri. La candidata vigente de
QA es 1.0.5 (1): `33327128802` archivó, firmó, validó con Apple y subió el IPA
con IDs demo. Apple procesó el recurso
`549fc26d-3786-446d-a379-163485cbe57c` como `VALID`, `INTERNAL_ONLY` e
`IN_BETA_TESTING`; `33327511155` confirmó dos testers privados, acceso
automático, estado externo `NOT_APPLICABLE` y ninguna selección por una versión
App Store. Esto no sustituye las pruebas físicas: Siri, llamadas, alarmas, rutas
y disponibilidad real del micrófono no se pueden reproducir fielmente mediante
XCTest. Toda la matriz debe repetirse sobre esta build exacta.

| Caso | Dispositivo/condición | Resultado esperado |
|---|---|---|
| Rotación continua | iPhone iOS 16 y iPhone iOS actual; 5 cortes mínimos | Cinco archivos válidos y la sesión continúa |
| Rotación por sonido | Ambos iPhone; voz suficiente para 5 cortes | Cinco archivos reproducibles, sin crecimiento anómalo de memoria |
| Destino no escribible / poco espacio | Llenar almacenamiento de forma controlada | Segmento previo visible, error útil, intención activa y recuperación al liberar espacio |
| Llamada/FaceTime | Rechazar y aceptar llamada | Segmento previo guardado; al liberar iOS el micrófono, reanudación inmediata o en el siguiente retry/foreground |
| Siri y alarma | Activar durante ambos modos; repetir con app visible y bloqueada | Segmento previo guardado; tras cerrar Siri/alarma aparece un segmento nuevo y la captura vuelve sin tocar Grabar |
| Interrupción prolongada | Mantener llamada/Siri más de 15 s | Un solo backend/retry, sin crecimiento de tareas; reanuda como máximo en el primer ciclo permitido tras liberar audio |
| Stop interrumpido | Pulsar Stop mientras Siri/llamada mantiene el micrófono | No hay reanudación al cerrar la interrupción ni cinco segundos después |
| Auriculares cableados | Conectar y retirar grabando | Corte controlado, nuevo formato/ruta y continuación |
| Bluetooth HFP | Conectar, desconectar y perder enlace | Nuevo segmento, continuación o reintento diagnosticado |
| Background/bloqueo | 30 min por modo con varios cortes | Captura continua; foreground no crea dobles backends |
| Media services | Developer Settings > Reset Media Services | Objetos reconstruidos, segmento previo conservado y recuperación |
| Escritura/encoder | Simular fallo o retirar capacidad | No se interpreta como stop del usuario; reintento local |
| Stop durante rotación/reintento | Pulsar Stop en el límite y durante retry | Un solo final, intent false, ningún reinicio tardío |
| Inicio sin permiso | Denegar micrófono | Sin archivo vacío persistente, error visible, intent false |

## Riesgos residuales

- macOS/Xcode, los XCTest y Release device ya validaron la fuente exacta de
  1.0.5 (1), pero no pueden certificar el comportamiento del micrófono frente a
  Siri ni rutas reales. La puerta restante son los iPhone físicos.
- El engine permanece activo entre archivos, pero una apertura de disco que
  tarde más que la cola temporal disponible terminará en recuperación para no
  crecer sin límite. Poco espacio y almacenamiento degradado requieren prueba
  física controlada.
- iOS puede terminar el proceso por presión extrema, batería o decisión del
  sistema sin entregar callbacks. Los archivos ya cerrados y los no indexados
  permanecen recuperables, pero no se puede grabar mientras el proceso no existe.
- iOS conserva la autoridad exclusiva sobre el micrófono. No es posible grabar
  durante una llamada aceptada, Siri u otra sesión que lo haya tomado; la mejora
  minimiza interrupciones evitables y recupera automáticamente cuando el sistema
  vuelve a permitir activar la sesión, pero no puede eliminar el hueco impuesto
  por el sistema.
