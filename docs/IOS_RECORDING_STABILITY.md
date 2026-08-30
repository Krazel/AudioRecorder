# VoiceRecorder iOS — estabilidad de grabación 1.0.3

Fecha de auditoría: 2026-08-30
Alcance: `native-ios/`; Android, distribución y servicios externos fuera de alcance.

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
7. `mixWithOthers` permitía que otras sesiones se mezclaran con una grabación
   controlada por el usuario y que otro componente de la propia app volviera a
   aplicar esa opción al reproducir. La configuración de captura y reproducción
   ya usa una categoría no mezclable coherente.

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

## Contratos de Apple aplicados

- [`record(forDuration:)`](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/record%28forduration%3A%29)
  detiene el grabador al alcanzar el límite, y el delegate informa tanto del
  final como de errores de codificación.
- [Responding to Interruptions](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/HandlingAudioInterruptions/HandlingAudioInterruptions.html)
  exige guardar estado al comenzar, reactivar la sesión cuando proceda y asumir
  que puede no llegar una notificación de fin.
- [`shouldResume`](https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionoptions/shouldresume)
  se interpreta como recomendación de reanudación; si no está presente, la
  sesión queda pausada y el foreground o una acción posterior del usuario puede
  iniciar la recuperación.
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
- [`AVAudioApplication.requestRecordPermission`](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission%28completionhandler%3A%29)
  es la ruta vigente desde iOS 17; iOS 16 conserva el fallback de
  `AVAudioSession`.
- [`playAndRecord`](https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playandrecord)
  continúa bajo bloqueo de pantalla y en segundo plano con `UIBackgroundModes`
  `audio`; por defecto es no mezclable.

## Políticas explícitas de 1.0.3

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
- Al comenzar una interrupción se finaliza el fragmento válido. Con
  `shouldResume` se reabre un segmento inmediatamente; sin esa recomendación se
  conserva la intención y se espera al foreground o al usuario.
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
- interrupción con y sin recomendación de reanudar;
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

La puerta manual `.github/workflows/verify-ios-recording-stability.yml` genera
el proyecto, ejecuta XCTest en simulador, compila Release para dispositivo sin
firma y conserva el `.xcresult`. Tiene una guarda que no asigna runner mientras
el repositorio sea privado. No debe despacharse hasta que el propietario autorice
una visibilidad compatible con Actions; no se cambia la visibilidad desde esta
corrección.

## Matriz de QA físico pendiente

| Caso | Dispositivo/condición | Resultado esperado |
|---|---|---|
| Rotación continua | iPhone iOS 16 y iPhone iOS actual; 5 cortes mínimos | Cinco archivos válidos y la sesión continúa |
| Rotación por sonido | Ambos iPhone; voz suficiente para 5 cortes | Cinco archivos reproducibles, sin crecimiento anómalo de memoria |
| Destino no escribible / poco espacio | Llenar almacenamiento de forma controlada | Segmento previo visible, error útil, intención activa y recuperación al liberar espacio |
| Llamada/FaceTime | Rechazar y aceptar llamada | Segmento previo guardado; reanudación recomendada o al volver/actuar |
| Siri y alarma | Activar durante ambos modos | UI y backend coinciden; ningún segmento válido desaparece |
| Auriculares cableados | Conectar y retirar grabando | Corte controlado, nuevo formato/ruta y continuación |
| Bluetooth HFP | Conectar, desconectar y perder enlace | Nuevo segmento, continuación o reintento diagnosticado |
| Background/bloqueo | 30 min por modo con varios cortes | Captura continua; foreground no crea dobles backends |
| Media services | Developer Settings > Reset Media Services | Objetos reconstruidos, segmento previo conservado y recuperación |
| Escritura/encoder | Simular fallo o retirar capacidad | No se interpreta como stop del usuario; reintento local |
| Stop durante rotación/reintento | Pulsar Stop en el límite y durante retry | Un solo final, intent false, ningún reinicio tardío |
| Inicio sin permiso | Denegar micrófono | Sin archivo vacío persistente, error visible, intent false |

## Riesgos residuales

- Windows no puede compilar AVFoundation ni ejecutar XCTest. La compilación,
  XCTest y el comportamiento de hardware siguen pendientes de macOS/Xcode y de
  los dos iPhone físicos.
- El engine permanece activo entre archivos, pero una apertura de disco que
  tarde más que la cola temporal disponible terminará en recuperación para no
  crecer sin límite. Poco espacio y almacenamiento degradado requieren prueba
  física controlada.
- iOS puede terminar el proceso por presión extrema, batería o decisión del
  sistema sin entregar callbacks. Los archivos ya cerrados y los no indexados
  permanecen recuperables, pero no se puede grabar mientras el proceso no existe.
