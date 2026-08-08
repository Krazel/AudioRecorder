# VoiceRecorder / AudioRecorder — hechos y decisiones

Última actualización: 2026-08-08.

Este documento distingue hechos observados de decisiones del propietario. Un hecho puede cambiar al evolucionar el repositorio; una decisión permanece vigente hasta que el propietario la sustituya expresamente.

## Hechos verificados

### F-001 — Identidad del repositorio — 2026-08-08

- Ruta: `C:\Users\dmkra\Documents\Codex Apps\Audio`.
- Rama: `agent/prepare-ios-test-build`.
- Commit actual: `cdcce91`; draft PR `#1` contra `main`.
- Remoto `origin`: `https://github.com/Krazel/AudioRecorder.git`.

### F-002 — Estado del árbol — 2026-08-08

- Hay cambios locales sin commit en CI y documentación durable para TestFlight interno que deben preservarse.
- `artifact/` permanece sin seguimiento y se excluyó expresamente. La política, el procesador por sonido y el manifiesto de privacidad ya forman parte del commit candidato.
- Android no presenta cambios en el árbol ni en el índice.

### F-003 — Línea base iOS — 2026-08-08

- iOS declara versión 1.0, build base 1 y deployment target iOS 16.
- Existen siete localizaciones coherentes: `ca/de/en/es/fr/it/pt`.
- El código local carga seis suscripciones mensuales de apoyo: 0,99 / 3 / 5 / 10 / 15 / 30.
- App Store Connect conserva históricamente nueve productos; los tres niveles 50/100/300 no forman parte de la preparación local 1.0.
- AdMob usa todavía identificadores de demostración de Google. El workflow local permite ese par exacto únicamente para una exportación `TestFlight Internal Only`; la ruta de producción sigue exigiendo IDs reales y rechaza los demos.

### F-004 — Validación disponible — 2026-08-08

- Han pasado las comprobaciones locales de manifiesto, localizaciones, capturas, plist, enlaces, estructura de concurrencia y puerta estática UMP/AdMob. Las siete tablas contienen las mismas 126 claves.
- No existe toolchain Apple en este equipo Windows. El commit `db0d870` sí compiló correctamente en macOS mediante GitHub Actions; las pruebas en dispositivo y el archive firmado siguen pendientes.

### F-005 — Preparación UMP/AdMob — 2026-08-08

- UMP está declarado como dependencia directa y el flujo local ejecuta actualización, formulario requerido y comprobación de `canRequestAds` antes de iniciar Mobile Ads o cargar un banner.
- Ajustes expone las opciones de privacidad solo cuando UMP las marca como requeridas.
- El App ID y el Banner ad unit ID se inyectan por separado. El archivo firmado verifica los valores archivados; la ruta `production` valida formato y rechaza el publicador demo, mientras `test` acepta únicamente el par oficial y fuerza TestFlight interno.
- El workflow firmado se detiene con Xcode o SDK iOS anteriores a la versión 26 y mantiene la validación externa y la subida desactivadas por defecto.
- Exige un número de build positivo explícito, inspecciona el archive y conserva IPA, archive y dSYM como artefactos temporales.
- `Info.plist` incluye los 50 SKAdNetwork IDs del ejemplo oficial de Google vigente el 2026-08-08.

### F-006 — Bloqueo externo AdMob — 2026-08-08

- El propietario tuvo que crear una cuenta nueva de AdMob y Google mantiene pendiente su verificación.
- Mientras dure la verificación no están disponibles los dos IDs reales ni la configuración/publicación definitiva de mensajes UMP/CMP.
- No se crearon recursos externos ni se inventaron identificadores.

### F-007 — Build macOS unsigned verificada — 2026-08-08

- Rama: `agent/prepare-ios-test-build`; commits `1c79d7d` y `db0d870`; draft PR `#1`.
- GitHub Actions run `31271758443` completó generación, compilación, empaquetado y artefacto con publicación omitida.
- IPA: 6.600.734 bytes; SHA-256 `EF4FBB659AC69EF99904BF88E19DF7143012E30FD74FDDB23446B79931C14C11`.
- Se verificaron ambos frameworks Google, manifiesto de privacidad, assets y siete idiomas.
- Los avisos de `allowBluetooth` y destino ambiguo quedaron corregidos. Permanece el aviso de orientaciones, ligado a la decisión pendiente sobre iPhone/iPad.

### F-008 — Firma y credenciales TestFlight — 2026-08-08

- GitHub tiene el environment `app-store-production` y los cuatro secrets Apple requeridos, cargados con autorización expresa sin mostrar sus valores. La Team API Key activa tiene rol Gestor de apps.
- App Store Connect se comprobó en vivo: app `6772278149`, bundle `com.dmkr.audio.B2X6D3A9J9`, cero builds, grupo interno `Testers` con un tester y un único usuario elegible. El build `1` está libre.

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

### D-010 — Beta interna antes de AdMob real — 2026-08-08 (sustituye la formulación anterior)

Se permite probar ahora con el par oficial de IDs demo de Google, exclusivamente en una build exportada como `TestFlight Internal Only`. Esa build no se reutiliza para TestFlight externo ni para clientes. Antes de cualquier candidata pública se generará un archive nuevo con IDs reales y mensajes UMP/CMP configurados y probados.

### D-011 — Consentimiento antes de anuncios — 2026-08-08

No se solicita ningún anuncio antes de que UMP permita hacerlo mediante `canRequestAds`. La aplicación debe ofrecer revisión o cambio de opciones de privacidad cuando UMP indique que corresponde.

### D-012 — Recursos de consola bajo autorización — 2026-08-08

La verificación de cuenta, el alta de la app/unidad publicitaria y la configuración o publicación de mensajes en AdMob son acciones externas. No se crean, publican ni sustituyen con datos inventados; tras el desbloqueo el propietario proporcionará los dos IDs o autorizará expresamente la acción concreta.

### D-013 — ATT separado de UMP — 2026-08-08

UMP y anuncios sin IDFA no implican solicitar seguimiento. No se añade ATT, `NSUserTrackingUsageDescription` ni un mensaje IDFA sin una decisión expresa posterior y su correspondiente revisión de privacidad y pruebas.

### D-014 — Dependencias publicitarias reproducibles — 2026-08-08

Google Mobile Ads queda fijado en 12.14.0 y UMP en 3.1.0 para la candidata actual. No se adopta una versión mayor sin generar el proyecto, compilar y ejecutar regresión en macOS/dispositivo. Los 50 SKAdNetwork IDs oficiales pueden mantenerse localmente sin activar ATT.
