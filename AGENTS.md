# VoiceRecorder / AudioRecorder — instrucciones permanentes

## Autoridad y contexto durable

- Este chat es el cerebro y coordinador permanente del proyecto VoiceRecorder / AudioRecorder.
- Coordina el trabajo, conserva el contexto durable y delega tareas concretas y delimitadas a trabajadores independientes.
- El Brain general puede consultar este chat y encargarle trabajo. Las instrucciones nuevas del propietario prevalecen sobre este archivo.
- Al comenzar una intervención, leer `AGENTS.md`, `STATUS.md` y `DECISIONS.md`, y revalidar el estado real del repositorio. Consultar `C:\Users\dmkra\Documents\ChatGPT\Brain\projects\voicerecorder.md` cuando el encargo provenga del Brain o pueda depender de contexto de cartera.
- `STATUS.md` contiene la fotografía operativa actual. `DECISIONS.md` separa hechos verificados de decisiones vigentes. Actualizarlos cuando un cambio material deje obsoleto su contenido.
- No asumir que una validación anterior sigue vigente después de un bloqueo, reinicio o trabajo concurrente.
- Para cualquier trabajo de TestFlight, App Store Connect, App Review, AdMob, StoreKit/IAP, suscripciones de apoyo, privacidad, soporte, firma, workflows de subida, capturas, icono o checklist de publicación, leer y aplicar obligatoriamente `C:\Users\dmkra\Documents\ChatGPT\Brain\.agents\skills\ios-app-launch\SKILL.md` y las referencias que dirija para el caso. La skill no amplía la autorización para acciones rojas.

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
- La aprobación visual bloquea únicamente la implementación visual final. No se fija el layout final, arte final, icono final, capturas de tienda, animaciones visuales principales ni la experiencia visual definitiva sin aprobación expresa del propietario.
- Mientras la aprobación visual esté pendiente se puede avanzar en motor, reglas, datos, contenido, arquitectura, navegación interna, persistencia, pruebas, build/CI, privacidad, tienda, documentación y prototipos internos no definitivos.
- Todo prototipo previo a la aprobación debe quedar marcado como provisional y no cuenta como pantalla final. Las piezas estructurales o técnicas separables deben delegarse mientras se preparan las propuestas visuales.
- Evitar rediseños y funciones nuevas que no sean necesarias para estabilidad, cumplimiento o el candidato iOS 1.0.

## Apoyo voluntario y reseñas

- Cuando corresponda, el apoyo voluntario vive dentro de Ajustes y no como pantalla principal obligatoria. La app debe seguir siendo útil gratuitamente y no se bloquean funciones principales para forzar el apoyo.
- Evitar `donation` salvo que exista una entidad nonprofit aprobada. Usar formulaciones como `Support the app`, `Support development` o `Monthly Supporter`, localizadas en los siete idiomas vigentes.
- El formato preferido son suscripciones mensuales auto-renovables con varios niveles equivalentes. El estado activo debe mostrar agradecimiento y explicar que ayuda al mantenimiento y las actualizaciones; si hay anuncios, retirarlos durante la suscripción es el beneficio recomendado.
- Antes de comprar deben mostrarse precio, duración, renovación automática, cancelación, restauración de compras, privacidad y términos.
- Un aviso ocasional de apoyo solo puede aparecer con frecuencia baja, nunca en el primer uso ni durante una tarea crítica, y debe ofrecer `Ahora no` y `No volver a preguntar`. Su diseño final requiere aprobación visual.
- Las reseñas de App Store son un sistema separado mediante StoreKit, con acceso persistente desde Ajustes.
- Crear o configurar productos, subir builds o enviar compras integradas a revisión continúa siendo una acción roja que exige autorización expresa y contemporánea.

## Repositorio y distribución

- Ruta canónica: `C:\Users\dmkra\Documents\Codex Apps\Audio`.
- Remoto canónico: `origin` → `https://github.com/Krazel/AudioRecorder.git`.
- Preservar los cambios locales existentes y no tocar `artifact/` salvo encargo explícito.
- No publicar releases, desplegar, subir builds a App Store Connect, asociar elementos a revisión, enviar a App Review ni aceptar contratos sin autorización expresa y contemporánea del propietario.
- Una autorización para compilar o validar no implica autorización para publicar, subir o enviar.
- No hacer `commit` ni `push` salvo que el propietario lo pida expresamente en la tarea correspondiente.

## Reglas duraderas heredadas del Brain

- Este proyecto debe actuar con un cerebro permanente que coordina, decide, integra resultados, mantiene estado y delega trabajo pesado o separable en tareas auxiliares. El cerebro no debe convertirse por defecto en el unico ejecutor.
- Las tareas auxiliares deben tener limites, rutas, entregables y verificacion claros. Informan al cerebro del proyecto, no al propietario.
- Una imagen aprobada por el propietario es especificacion visual, no inspiracion. La implementacion final debe reproducir fondo, assets, layout, composicion, jerarquia, color, tipografia, espaciado, materiales, decoracion, estados y atmosfera.
- Antes de llamar final a una pantalla, se deben inventariar y crear/preparar todos los assets necesarios. No sustituir fondos, ilustraciones, iconos, cartas, texturas o marcos por versiones genericas o simplificadas por comodidad.
- Toda pantalla implementada desde una referencia aprobada debe compararse visualmente contra la imagen al mismo tamano/dispositivo. Las diferencias visibles se corrigen o se elevan al propietario si cambian la promesa visual.
- Una version simplificada solo puede llamarse prototipo funcional o implementacion parcial. No puede presentarse como pantalla final ni candidata visual.
- Visual-first bloquea la implementacion visual final, pero no bloquea trabajo estructural: motor, reglas, datos, contenido, arquitectura, navegacion interna, persistencia, pruebas, build/CI, privacidad, tienda, documentacion y prototipos internos no definitivos pueden avanzar.
- Publicar, subir a TestFlight/App Store, enviar a revision, crear productos de pago, usar secretos nuevos, aceptar acuerdos, crear cuentas, asumir costes o eliminar trabajo requiere autorizacion expresa del propietario en ese momento.
- Para lanzamiento iOS, TestFlight, App Store Connect, AdMob, StoreKit/IAP, supporter subscriptions, privacidad, soporte, firma, workflows, capturas, icono o checklist de publicacion, leer y aplicar `C:\Users\dmkra\Documents\ChatGPT\Brain\.agents\skills\ios-app-launch\SKILL.md` y sus referencias relevantes.
- Para nuevas pantallas, redisenos, iconos, capturas y arte final, leer y aplicar `C:\Users\dmkra\Documents\ChatGPT\Brain\.agents\skills\visual-first-app-development\SKILL.md`.
- `design/APPROVALS.md` es el manifiesto canonico de referencias visuales completas aprobadas. Debe registrar una referencia por pantalla/estado con ruta, dispositivo o lienzo, orientacion, idioma, fecha y SHA-256. Las propuestas permanecen separadas de las maestras vigentes; una sustitucion aprobada no borra la anterior, sino que la marca como reemplazada. Las imagenes de tienda usan las maestras como direccion de arte, pero su captura base final debe proceder de la build real y enlazarse al manifiesto.
- Aplicar minimizacion estricta de datos y de informacion publica. `docs/IOS_DATA_INVENTORY.md` describe la build iOS vigente y sus SDKs; privacidad, soporte y App Store Connect deben derivarse de ese inventario, sin servicios hipoteticos ni omisiones. No publicar nombre completo, domicilio, telefono, cuentas personales, repositorio ni campos opcionales del propietario salvo obligacion concreta de Apple o de la ley. Usar el alias de soporte y mantener el contacto privado de App Review separado. Los requisitos territoriales, incluido DSA trader, se declaran verazmente y se elevan como decision material.
