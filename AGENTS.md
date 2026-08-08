# VoiceRecorder / AudioRecorder — instrucciones permanentes

## Autoridad y contexto durable

- Este chat es el cerebro y coordinador permanente del proyecto VoiceRecorder / AudioRecorder.
- Coordina el trabajo, conserva el contexto durable y delega tareas concretas y delimitadas a trabajadores independientes.
- El Brain general puede consultar este chat y encargarle trabajo. Las instrucciones nuevas del propietario prevalecen sobre este archivo.
- Al comenzar una intervención, leer `AGENTS.md`, `STATUS.md` y `DECISIONS.md`, y revalidar el estado real del repositorio. Consultar `C:\Users\dmkra\Documents\ChatGPT\Brain\projects\voicerecorder.md` cuando el encargo provenga del Brain o pueda depender de contexto de cartera.
- `STATUS.md` contiene la fotografía operativa actual. `DECISIONS.md` separa hechos verificados de decisiones vigentes. Actualizarlos cuando un cambio material deje obsoleto su contenido.
- No asumir que una validación anterior sigue vigente después de un bloqueo, reinicio o trabajo concurrente.

## Modelo de coordinación

- Los turnos de coordinación deben terminar rápidamente mientras los trabajadores independientes avanzan. No bloquear el chat coordinador esperando trabajo que pueda seguir en una tarea independiente.
- Cada delegación debe indicar objetivo, alcance, rutas autorizadas, entregable, validación esperada y prohibiciones relevantes.
- Solo una tarea puede ser propietaria de implementación en un momento dado. No permitir dos tareas con escrituras solapadas sobre código, configuración o documentación del mismo cambio.
- Tareas de lectura, auditoría y pruebas pueden ejecutarse en paralelo si no escriben sobre los mismos archivos ni alteran estado externo.
- Antes de escribir, comprobar cambios locales y preservar todo trabajo existente. No reescribir por reescribir ni eliminar cambios ajenos.
- Ante una decisión roja —publicación, envío a revisión, contratos, credenciales, monetización o un cambio de alcance— detener la ejecución y pedir autorización al propietario.
- Los trabajadores deben devolver: archivos tocados, validaciones ejecutadas, resultados, riesgos y acciones externas pendientes. El coordinador integra el resultado en `STATUS.md`.

## Alcance del producto

- El producto activo es únicamente iOS, dentro de `native-ios/` y los materiales iOS relacionados.
- No desarrollar, mantener, corregir ni modificar Android hasta una orden expresa posterior del propietario.
- VoiceRecorder conserva excepcionalmente exactamente estos siete idiomas ya existentes: catalán, alemán, inglés, español, francés, italiano y portugués (`ca/de/en/es/fr/it/pt`). No aplicar la regla general de inglés único y no añadir idiomas nuevos.
- Toda pantalla nueva exige una imagen o mockup aprobado por el propietario antes de implementar la interfaz. Una modificación técnica que no crea pantalla nueva no activa esta puerta visual.
- Evitar rediseños y funciones nuevas que no sean necesarias para estabilidad, cumplimiento o el candidato iOS 1.0.

## Repositorio y distribución

- Ruta canónica: `C:\Users\dmkra\Documents\Codex Apps\Audio`.
- Remoto canónico: `origin` → `https://github.com/Krazel/AudioRecorder.git`.
- Preservar los cambios locales existentes y no tocar `artifact/` salvo encargo explícito.
- No publicar releases, desplegar, subir builds a App Store Connect, asociar elementos a revisión, enviar a App Review ni aceptar contratos sin autorización expresa y contemporánea del propietario.
- Una autorización para compilar o validar no implica autorización para publicar, subir o enviar.
- No hacer `commit` ni `push` salvo que el propietario lo pida expresamente en la tarea correspondiente.
