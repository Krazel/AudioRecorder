# Build Android

AudioRecorder tiene version Android nativa en:

```text
android/
```

ID fijo:

```text
com.dmkr.audio
```

La version Android actual es un MVP nativo Java:

- permiso de microfono;
- grabacion `.m4a` con `MediaRecorder`;
- boton iniciar/parar;
- timer de grabacion;
- listado local de grabaciones guardadas en almacenamiento privado de la app.

Generar APK debug:

```powershell
cd android
.\gradlew.bat assembleDebug
```

APK resultante:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

Objetivo para artifacts:

```text
artifact/AudioRecorder-Android-v1.0-build-N.apk
artifact/old/
```

Debe mantenerse la misma regla que iOS: una sola build visible por plataforma en `artifact/` y builds antiguas en `artifact/old/`.
