# AudioRecorder

MVP nativo para grabar en iPhone y Android, segmentar por intervalos configurables y probar subida automatica a proveedores externos.

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
- Cola persistente de subida.
- Copia automatica a iCloud Drive / Archivos cuando iCloud esta disponible.
- Subida real a servidor propio mediante `multipart/form-data`.
- Abstraccion preparada para Google Drive y OneDrive.

## Probar subida externa

En iOS, abre `Ajustes`, activa `Subir al terminar cada segmento`, elige `Servidor propio` y pega un endpoint HTTPS. Si el servidor necesita autenticacion, guarda un token/API key y la app lo enviara como `Authorization: Bearer`.

La app hace un `POST multipart/form-data` con:

- `file`: archivo `.m4a`.
- `recording_id`: identificador de la grabacion.
- `provider`: `customServer`.

Si el servidor responde con HTTP 2xx, la grabacion pasa a `Subido`. Si responde con error o falta URL valida, queda como `Fallido` para poder reintentarla desde `Archivos`.

Para iCloud Drive, elige `iCloud Drive / Archivos`. La app copia los audios a la carpeta `AudioRecorder` de iCloud Drive si iCloud esta disponible; si no, los deja accesibles en la app Archivos dentro de `En mi iPhone > AudioRecorder`.

Para envio manual, abre `Archivos` y usa el boton de compartir de arriba para enviar todos los audios, o desliza una grabacion y pulsa `Enviar`. iOS mostrara la hoja nativa para guardar en Archivos, iCloud Drive, Google Drive, OneDrive, correo u otra app instalada.

## Pendiente antes de produccion

- Conectar OAuth real para Google Drive y OneDrive.
- Implementar subida resumible real en `GoogleDriveUploader` y `OneDriveUploader`.
- Sustituir la separacion simple voz/ruido por un modelo Core ML si se necesita separacion avanzada.
- Probar consumo de bateria en sesiones largas.
- Gestionar interrupciones de audio: llamadas, Siri, alarmas, cambios de ruta Bluetooth.
- Anadir tests unitarios cuando el proyecto se compile en macOS.

## Ficheros clave

- `native-ios/Sources/RecorderService.swift`: captura, escritura y rotacion de segmentos.
- `native-ios/Sources/VoiceNoiseAnalyzer.swift`: analisis simple de nivel para voz/ruido.
- `native-ios/Sources/CloudUploadQueue.swift`: cola persistente de subidas.
- `native-ios/Sources/CloudUploader.swift`: puntos de integracion cloud.
- `native-ios/Resources/Info.plist`: permisos y background audio.
