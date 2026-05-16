# AudioRecorder iOS

MVP nativo en SwiftUI para grabar audio en iPhone, segmentarlo por intervalos configurables y preparar subida automatica a proveedores externos.

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
- Segmentacion configurable: 5, 15, 30, 60 y 120 minutos.
- Calidad baja/media/alta con ajustes de bitrate/formato.
- Modos: todo, voces, ruido y separado.
- Indice local de grabaciones en JSON.
- Cola persistente de subida.
- Abstraccion para Google Drive, OneDrive y servidor propio.

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
