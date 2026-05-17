# Build Android

AudioRecorder tiene version Android nativa en:

```text
android/
```

ID fijo:

```text
com.dmkr.audio
```

La version Android debe mantener paridad con iPhone:

- pantalla Grabar;
- pantalla Archivos;
- pantalla Ajustes;
- grabacion `.m4a` con `MediaRecorder`;
- reproducir, compartir, renombrar y eliminar grabaciones;
- ajustes de calidad, modo, corte, sensibilidad y subida automatica.

Generar APK debug:

```powershell
cd android
.\gradlew.bat assembleDebug
```

APK resultante:

```text
android/app/build/outputs/apk/debug/app-debug.apk
```

Objetivo para artifacts locales:

```text
artifact/AudioRecorder-Android-v1.0-local.apk
artifact/old/
```

Android se compila localmente desde Windows. No crear GitHub Actions para Android.

Debe mantenerse la misma regla: una sola build visible por plataforma en `artifact/` y builds antiguas en `artifact/old/`.
