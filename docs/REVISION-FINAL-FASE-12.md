# Revisión final de VoodooCombo — fase 12

**Fecha:** 18 de noviembre de 2026

**Alcance:** auditoría de los bloques 12a–12l, pruebas automatizadas y paquete Windows.

## Resultado

Los doce bloques de fase 12 están implementados: respuesta visual y sonora, vuelos de doblones al marcador, combo, medallas, música por capas, tensión y final, progreso y retos, pulido de menús, retirada de Clásico, Último en Pie, Codicia 2v2 y selección de modo. No encontré otro fallo de código que impidiera superar las comprobaciones automatizadas de esta pasada.

Durante la revisión corregí un aviso reproducible: en modo headless `Sfx` creaba capas de audio que no se pueden reproducir y Godot informaba streams retenidos al cerrar. Ahora no crea esos reproductores en el backend headless. También incorporé los UID que Godot genera para los tests y los metadatos de importación de las imágenes de referencia.

## Comprobaciones

- Godot **4.7.2** hizo el escaneo/importación del proyecto. El único aviso restante identifica `voodoocombo/` como otro proyecto Godot anidado y lo omite; esa carpeta local quedó intacta y fuera de Git.
- `tests/run_tests.gd`: pasó la regresión de arena, física, bots, trampas, hechizos, zona, puntuación y simulación determinista.
- Pasaron `test_challenges.gd`, `test_client_view.gd`, `test_disconnect.gd`, `test_full_modes.gd`, `test_lobby_view.gd`, `test_local_match.gd`, `test_medals.gd`, `test_rooms.gd`, `test_rpc_rules.gd`, `test_survival.gd`, `test_teams.gd` y `test_vote.gd`.
- `test_network_client.gd`: ida y vuelta ENet correcta con su servidor fixture en `127.0.0.1:17777`.
- `tools/test-network.ps1`: VoodooCombo, Último en Pie y Codicia 2v2 completaron la partida con cuatro clientes; los resultados coincidieron, el quinto cliente fue rechazado por aforo y `/results` devolvió el modo esperado.
- Se regeneró `build/VoodooCombo-0.1.pck`, se actualizó el ZIP y se extrajo para comprobar el arranque del juego mediante `VoodooCombo-0.1.exe`.

## Pendiente de validación humana

- Abrir el paquete en Windows con ventana visible; revisar resolución, idioma, audio, controles y accesibilidad con teclado y mando.
- Jugar cada modo en las cuatro arenas, comprobar feedback visual/sonoro, medallas, barra de XP, desconexiones y revancha con varias personas.
- La exportación dedicada Linux y el despliegue de Oracle están documentados en `docs/DESPLIEGUE.md`, pero requieren las plantillas oficiales de exportación y configuración humana. No se creó ninguna VM.
- `docs/HISTORIA-IA.md` conserva los campos `[que lo completen los humanos]` que la tarea deja expresamente para decisión del equipo.

## Distribución

El archivo `build/VoodooCombo-0.1-Windows.zip` contiene el lanzador, el PCK y los binarios de Godot necesarios. La plantilla oficial de exportación no estaba instalada; por eso el ZIP incluye el runtime y es más grande que una exportación autocontenida estándar.
