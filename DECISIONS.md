# VoiceRecorder / AudioRecorder — hechos y decisiones

Última actualización: 2026-08-08.

Este documento distingue hechos observados de decisiones del propietario. Un hecho puede cambiar al evolucionar el repositorio; una decisión permanece vigente hasta que el propietario la sustituya expresamente.

## Hechos verificados

### F-001 — Identidad del repositorio — 2026-08-08

- Ruta: `C:\Users\dmkra\Documents\Codex Apps\Audio`.
- Rama: `main`.
- Commit actual: `35a7afadf6c0a53803f44aa1b5d9ff7b918a91c4`.
- Remoto `origin`: `https://github.com/Krazel/AudioRecorder.git`.

### F-002 — Estado del árbol — 2026-08-08

- Hay cambios iOS, documentación y CI locales sin commit que deben preservarse.
- También hay archivos sin seguimiento, entre ellos `artifact/`, `docs/`, el procesador del modo por sonido y el manifiesto de privacidad.
- Android no presenta cambios en el árbol ni en el índice.

### F-003 — Línea base iOS — 2026-08-08

- iOS declara versión 1.0, build base 1 y deployment target iOS 16.
- Existen siete localizaciones coherentes: `ca/de/en/es/fr/it/pt`.
- El código local carga seis suscripciones mensuales de apoyo: 0,99 / 3 / 5 / 10 / 15 / 30.
- App Store Connect conserva históricamente nueve productos; los tres niveles 50/100/300 no forman parte de la preparación local 1.0.
- AdMob usa todavía identificadores de demostración de Google como valores locales de desarrollo; el workflow firmado exige IDs reales y rechaza los demos.

### F-004 — Validación disponible — 2026-08-08

- Han pasado las comprobaciones locales de manifiesto, localizaciones, capturas, plist, enlaces, estructura de concurrencia y puerta estática UMP/AdMob. Las siete tablas contienen las mismas 126 claves.
- No existe toolchain Apple en este equipo Windows, por lo que la compilación actual y las pruebas en dispositivo siguen pendientes.

### F-005 — Preparación UMP/AdMob — 2026-08-08

- UMP está declarado como dependencia directa y el flujo local ejecuta actualización, formulario requerido y comprobación de `canRequestAds` antes de iniciar Mobile Ads o cargar un banner.
- Ajustes expone las opciones de privacidad solo cuando UMP las marca como requeridas.
- El App ID y el Banner ad unit ID se inyectan por separado. El archivo firmado comprueba formato, rechaza el publicador demo y verifica los valores archivados.
- El workflow firmado se detiene con Xcode o SDK iOS anteriores a la versión 26 y mantiene la validación externa y la subida desactivadas por defecto.
- Exige un número de build positivo explícito, inspecciona el archive y conserva IPA, archive y dSYM como artefactos temporales.
- `Info.plist` incluye los 50 SKAdNetwork IDs del ejemplo oficial de Google vigente el 2026-08-08.

### F-006 — Bloqueo externo AdMob — 2026-08-08

- El propietario tuvo que crear una cuenta nueva de AdMob y Google mantiene pendiente su verificación.
- Mientras dure la verificación no están disponibles los dos IDs reales ni la configuración/publicación definitiva de mensajes UMP/CMP.
- No se crearon recursos externos ni se inventaron identificadores.

## Decisiones vigentes

### D-001 — Plataforma exclusiva iOS — 2026-08-08

VoiceRecorder se completa primero y únicamente para iOS. Android queda fuera de alcance hasta una nueva orden expresa del propietario.

### D-002 — Excepción permanente de idiomas — 2026-08-08

Este proyecto conserva exactamente catalán, alemán, inglés, español, francés, italiano y portugués (`ca/de/en/es/fr/it/pt`). No se reduce a inglés y no se añaden idiomas nuevos sin una decisión posterior.

### D-003 — Cerebro permanente y delegación — 2026-08-08

Este chat mantiene el contexto durable, coordina VoiceRecorder y delega trabajo delimitado. El Brain general puede consultarlo y encargarle trabajo. Los turnos de coordinación deben cerrarse rápidamente mientras las tareas independientes continúan.

### D-004 — Propiedad única de implementación — 2026-08-08

Solo una tarea puede ser propietaria de implementación en cada momento. Lecturas, auditorías y pruebas no destructivas pueden ejecutarse en paralelo si no generan escrituras solapadas.

### D-005 — Puerta visual para pantallas nuevas — 2026-08-08

No se implementa ninguna pantalla nueva sin una imagen o mockup previamente aprobado por el propietario.

### D-006 — Monetización local de 1.0 — 2026-08-08

La escala preparada para 1.0 contiene seis niveles mensuales: 0,99 / 3 / 5 / 10 / 15 / 30. Todos conceden el mismo beneficio mientras el derecho está activo. Los niveles 50/100/300 quedan excluidos de la versión local 1.0.

### D-007 — Códigos manuales retenidos — 2026-08-08

Los códigos manuales ocultos que retiran anuncios permanecen en la build pública por decisión informada del propietario. Deben describirse fielmente en las notas de App Review; no se permite ocultarlos de forma engañosa.

### D-008 — Publicación bajo autorización expresa — 2026-08-08

No publicar releases, subir builds, asociar suscripciones a revisión, enviar a App Review, aceptar contratos ni realizar acciones equivalentes sin autorización expresa y contemporánea del propietario. Compilar o validar no concede permiso para publicar.

### D-009 — Integridad del trabajo local — 2026-08-08

Preservar todos los cambios existentes. No borrar, revertir o reemplazar trabajo local sin autorización expresa en el momento y una verificación previa del objetivo exacto.

### D-010 — AdMob real antes de TestFlight — 2026-08-08

La candidata de TestFlight debe integrar los identificadores reales de la app iOS y de su unidad banner. Los IDs demo pueden permanecer para desarrollo local, pero deben quedar bloqueados en cualquier archive firmado destinado a App Store Connect.

### D-011 — Consentimiento antes de anuncios — 2026-08-08

No se solicita ningún anuncio antes de que UMP permita hacerlo mediante `canRequestAds`. La aplicación debe ofrecer revisión o cambio de opciones de privacidad cuando UMP indique que corresponde.

### D-012 — Recursos de consola bajo autorización — 2026-08-08

La verificación de cuenta, el alta de la app/unidad publicitaria y la configuración o publicación de mensajes en AdMob son acciones externas. No se crean, publican ni sustituyen con datos inventados; tras el desbloqueo el propietario proporcionará los dos IDs o autorizará expresamente la acción concreta.

### D-013 — ATT separado de UMP — 2026-08-08

UMP y anuncios sin IDFA no implican solicitar seguimiento. No se añade ATT, `NSUserTrackingUsageDescription` ni un mensaje IDFA sin una decisión expresa posterior y su correspondiente revisión de privacidad y pruebas.

### D-014 — Dependencias publicitarias reproducibles — 2026-08-08

Google Mobile Ads queda fijado en 12.14.0 y UMP en 3.1.0 para la candidata actual. No se adopta una versión mayor sin generar el proyecto, compilar y ejecutar regresión en macOS/dispositivo. Los 50 SKAdNetwork IDs oficiales pueden mantenerse localmente sin activar ATT.
