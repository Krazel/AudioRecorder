# AudioRecorder

MVP nativo para grabar en iPhone y Android, segmentar por intervalos configurables y enviar archivos manualmente.

## Build en GitHub

Este repo sigue el mismo patron que `Alarma`: el proyecto Xcode no se sube generado. GitHub Actions instala XcodeGen, genera el `.xcodeproj` desde `native-ios/project.yml`, compila en `macos-latest` y publica un IPA unsigned.

Flujo:

1. Crea el repo remoto en GitHub.
2. Sube este proyecto a la rama `main`.
3. GitHub ejecutara `.github/workflows/build-ios-unsigned.yml`.
4. El artifact se llamara `AudioRecorder-unsigned-ipa`.
5. La release `latest-ipa` tendra `AudioRecorder-iPhone-latest.ipa` y copias con version en el nombre, por ejemplo `AudioRecorder-iPhone-latest-v1.1-build-7.ipa`.

Para vigilar y descargar el IPA desde Windows:

```powershell
.\watch-ipa.bat -Repo "TU_USUARIO/TU_REPO"
```

## Abrir en Xcode manualmente

1. Copia esta carpeta a un Mac con Xcode 15 o superior.
2. Instala XcodeGen: `brew install xcodegen`.
3. Ejecuta `xcodegen generate` dentro de `native-ios`.
4. Abre `native-ios/AudioRecorder.xcodeproj`.
5. En el target `AudioRecorder`, cambia el bundle id `com.dmkr.audio` si quieres otro.
6. Ejecuta en un iPhone real. La grabacion en segundo plano y el microfono no deben validarse solo en simulador.

## Incluido

- SwiftUI con tabs de grabacion, archivos y ajustes.
- Grabacion mediante `AVAudioEngine`.
- Permiso de microfono en `Info.plist`.
- `UIBackgroundModes = audio` para continuar grabando en segundo plano.
- Segmentacion configurable: no separar, 5, 15, 30, 60 y 120 minutos.
- Calidad muy baja/baja/media/alta con ajustes de bitrate/formato.
- Modos: todo y por sonido.
- Indice local de grabaciones en JSON.
- Envio manual desde `Archivos` con la hoja nativa de compartir de iOS.
- Envio de pendientes y seleccion manual de grabaciones.

## Enviar archivos

En iOS, abre `Archivos` y usa `Enviar > Enviar pendientes` para compartir solo los audios no enviados. Tambien puedes pulsar `Seleccionar`, marcar grabaciones una a una o arrastrar el dedo por la lista, y usar `Enviar seleccionados`.

iOS mostrara la hoja nativa para guardar en Archivos, iCloud Drive, Google Drive, OneDrive, correo u otra app instalada. Cuando se cierra la hoja de compartir, esas grabaciones se marcan como `Subido` para que no vuelvan a entrar en pendientes.

Para envio manual, abre `Archivos` y usa el boton de compartir de arriba para enviar todos los audios, o desliza una grabacion y pulsa `Enviar`. iOS mostrara la hoja nativa para guardar en Archivos, iCloud Drive, Google Drive, OneDrive, correo u otra app instalada.

## Pendiente antes de produccion

- Sustituir la separacion simple voz/ruido por un modelo Core ML si se necesita separacion avanzada.
- Probar consumo de bateria en sesiones largas.
- Gestionar interrupciones de audio: llamadas, Siri, alarmas, cambios de ruta Bluetooth.
- Anadir tests unitarios cuando el proyecto se compile en macOS.

## Ficheros clave

- `native-ios/Sources/RecorderService.swift`: captura, escritura y rotacion de segmentos.
- `native-ios/Sources/VoiceNoiseAnalyzer.swift`: analisis simple de nivel para voz/ruido.
- `native-ios/Sources/RecordingsView.swift`: listado, seleccion y envio manual.
- `native-ios/Resources/Info.plist`: permisos y background audio.
