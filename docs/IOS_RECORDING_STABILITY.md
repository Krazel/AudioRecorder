# VoiceRecorder iOS — estabilidad de grabación 1.0.2

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

## Políticas explícitas de 1.0.2

- Solo `stopRequested` borra la intención y desactiva la sesión. Un final
  inesperado, fallo de escritura o fallo al abrir el segmento siguiente guarda
  lo recuperable, mantiene `isRecording` como intención y reintenta cada cinco
  segundos.
- La rotación prepara primero el destino escribible del modo por sonido. El
  segmento anterior solo se confirma después. Para `AVAudioRecorder`, el
  segmento terminado ya está cerrado por Apple; si el siguiente no se prepara,
  el anterior queda indexado y el motor entra en recuperación.
- El watchdog usa tiempo monotónico para separar el límite esperado de una
  pérdida prematura del backend. En modo por sonido exige engine, generación de
  procesador y actividad de buffers.
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
- Un máximo de 64 buffers pendientes limita la presión de memoria del modo por
  sonido. Un desbordamiento se trata como fallo diagnosticado y recuperable.
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
- `AVAudioRecorder` cierra y abre archivos independientes; puede existir un
  intervalo pequeño entre segmentos. La corrección garantiza continuidad de la
  sesión y recuperación, no captura sin muestras perdidas a nivel profesional.
- iOS puede terminar el proceso por presión extrema, batería o decisión del
  sistema sin entregar callbacks. Los archivos ya cerrados y los no indexados
  permanecen recuperables, pero no se puede grabar mientras el proceso no existe.
