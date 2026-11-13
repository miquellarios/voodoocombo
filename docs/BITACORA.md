# Bitácora de desarrollo

## Registro humano

Lo rellenáis vosotros después de cada fase. Son las preguntas que hace el profesorado.

| Fecha | Fase | Prompt (resumen) | ¿Funcionó a la primera? | Qué reformulamos y por qué | Qué investigamos por nuestra cuenta | ⭐ |
|---|---|---|---|---|---|---|
| | | | | | | |

## Momentos clave ⭐ (para la presentación)

-

## Registro de Codex

> Codex añade aquí una entrada por fase. Solo hechos reales: no se inventan problemas.

### Fase 9a — Movimiento y colisiones (13/11/2026)
- Qué se ha hecho: Añadida `ArenaPhysics` para desplazar círculos por ejes, deslizarse por obstáculos y separar jugadores sin atravesar la geometría. Jugador y bots usan la misma resolución de movimiento y el dash se detiene al chocar. Añadidas pruebas de deslizamiento y separación.
- Decisiones: Las colisiones se calculan con los rectángulos exactos de `arenas.json`; el radio de jugador viene de `GameConfig`.
- Problemas encontrados y cómo se resolvieron: Godot no registró la nueva clase global en la primera ejecución directa de tests; el escaneo headless del editor actualizó la caché de clases y después los tests pasaron.
- Qué tienen que probar los humanos: Moverse en diagonal contra los cuatro lados de varios obstáculos, cruzar esquinas y dejar dos personajes superpuestos para confirmar que se deslizan/separan y que el dash se corta contra los muros.

Formato de cada entrada:

```
### Fase N — <título> (<fecha>)
- Qué se ha hecho:
- Decisiones:
- Problemas encontrados y cómo se resolvieron:
- Qué tienen que probar los humanos:
```

### Fase 0 — Plan (10/11/2026)
- Qué se ha hecho: Preparado el kit (`AGENTS.md` y `docs/`) en la raíz y revisado `project.godot` junto con el plan y los prompts. Detectada la configuración de Godot 4.7 (`config/features` contiene `4.7`). No se ha escrito código.
- Decisiones: Seguir las fases en orden. Compatibility cumple AGENTS.md; Clásico se resuelve como inventario que puede cambiar al recibir un golpe; cuatro espejos de dos patrones producen ocho obstáculos. Orden: Fase 1 lógica pura; Fase 2 partida local; Fase 3 red; Fase 4 feedback; Fase 5 estética; Fase 6 progresión; Fase 7 accesibilidad; Fase 8 entrega.
- Problemas encontrados y cómo se resolvieron: El directorio de trabajo no contiene `.git`, así que no se pudo hacer el commit solicitado. La discrepancia entre Forward Plus y Compatibility se resolvió usando Compatibility.
- Riesgos y ambigüedades: La autoridad del servidor combinada con movimiento local requiere validación tolerante a latencia y recogidas atómicas; anfitrión debe compartir eventos sin duplicarlos. El lobby y la partida en red siguen pendientes de integración.
- Qué tienen que probar los humanos: Confirmar que el proyecto abre en Godot 4.7 y revisar ambas reglas de juego.

### Fase 1 — Lógica base (10/11/2026)
- Qué se ha hecho: Añadidos `core/game_config.gd`, `arena_gen.gd`, `scoring.gd`, `item_table.gd`, `ranking.gd` y `tests/run_tests.gd`. El generador produce ocho obstáculos en patrones espejo; el objetivo Clásico usa el inventario actual y las probabilidades se renormalizan al excluir el Anillo.
- Decisiones: Los patrones espejo se cuentan como ocho obstáculos. En Clásico los doblones robados cambian el marcador.
- Problemas encontrados y cómo se resolvieron: Al principio no se encontró Godot en PATH; después se localizó Godot 4.7.2 y se ejecutó el runner completo.
- Qué tienen que probar los humanos: Ejecutar `godot --headless --path . --script res://tests/run_tests.gd` en el PC del proyecto y revisar las distancias en pantalla.

### Fase 2 — Partida local (10/11/2026)
- Qué se ha hecho: Añadida escena principal dibujada por código, movimiento, bots, colisiones básicas, monedas, combo, robo con dash, cofres, ruleta, hechizos, corona, cuenta atrás, dos modos y pantalla de resultados con revancha.
- Decisiones: Los bots completan la partida local; el jugador local ocupa la primera ranura.
- Problemas encontrados y cómo se resolvieron: La escena arrancó en Godot 4.7.2 sin errores de parser ni runtime. No se pudo controlar el juego manualmente desde la integración usada.
- Qué tienen que probar los humanos: Jugar ambos modos, comprobar colisiones con obstáculos y recoger monedas soltadas tras un golpe.

### Fase 3 — Red (10/11/2026, parcial)
- Qué se ha hecho: Añadidos autoloads ENet, descubrimiento UDP y endpoint TCP con `/status`, `/results` y `/`.
- Decisiones: Se dejaron las entradas del endpoint en JSON simple.
- Problemas encontrados y cómo se resolvieron: El lobby, la sincronización de posiciones, la simulación autoritativa compartida y la revancha por red no quedaron integrados; el proceso dedicado solo abre transporte/endpoints.
- Qué tienen que probar los humanos: Importar el proyecto, verificar puertos 7777/7778/8080 y terminar la integración de snapshots/eventos antes de presentar multijugador.

### Fase 4 — Feedback (10/11/2026, parcial)
- Qué se ha hecho: Añadidos tonos sintetizados, mensajes flotantes, sonido de recogida, golpes y aviso de Frenesí.
- Decisiones: Se usó síntesis de tonos sin recursos de audio externos.
- Problemas encontrados y cómo se resolvieron: No se implementó el conjunto completo de música, cámara lenta, partículas y secuencias de victoria.
- Qué tienen que probar los humanos: Revisar niveles de sonido y movimiento reducido en el juego.

### Fase 5 — Estética (10/11/2026, parcial)
- Qué se ha hecho: Añadida paleta de cuatro biomas, escenario procedural, personajes de color con símbolos, doblones, cofres y tema de controles.
- Decisiones: El renderizador se cambió a GL Compatibility para cumplir AGENTS.md; se usa la fuente integrada de Godot porque el kit no incluye Lilita One ni Baloo 2.
- Problemas encontrados y cómo se resolvieron: El menú, lobby jugable, ilustración final de personaje y decoración específica por bioma quedaron simplificados.
- Qué tienen que probar los humanos: Revisar visibilidad, escala del HUD y legibilidad a resolución objetivo.

### Fase 6 — Perfil y progresión (10/11/2026, parcial)
- Qué se ha hecho: Añadidos perfil persistente, XP, niveles, personalización básica, historial de partidas y podio de texto.
- Decisiones: Los registros locales viven en `user://matches/` y el perfil en `user://profile.cfg`.
- Problemas encontrados y cómo se resolvieron: No se implementaron desbloqueos por nivel ni animaciones del podio.
- Qué tienen que probar los humanos: Completar partidas, reiniciar el juego y revisar perfil e historial.

### Fase 7 — Accesibilidad (10/11/2026, parcial)
- Qué se ha hecho: Añadidos controles de teclado y mando para movimiento, dash y hechizo; ajustes persistentes para reducir movimiento, escala UI e idioma es/ca/en.
- Decisiones: Se conserva foco de teclado en botones y se usan símbolos además de colores.
- Problemas encontrados y cómo se resolvieron: La cobertura de traducciones y navegación completa por mando no pudo verificarse sin ejecutar Godot.
- Qué tienen que probar los humanos: Probar los menús solo con mando/teclado y las tres opciones de idioma y escala.

### Fase 8 — Entrega (10/11/2026, parcial)
- Qué se ha hecho: Añadidos README, preset de exportación de Windows y paquete `VoodooCombo 0.1`. No se hizo commit por instrucción del usuario.
- Decisiones: Se documenta explícitamente que multijugador y endpoint dedicado no equivalen aún a una partida en red terminada.
- Problemas encontrados y cómo se resolvieron: La exportación oficial no pudo usar las plantillas de Windows que faltan; el paquete de runtime alternativo se generó y se probó en modo headless. La red aún no se probó entre equipos.
- Qué tienen que probar los humanos: Ejecutar el paquete Windows y terminar la conexión de la simulación de red antes de dar la entrega por lista.

### Revisión y build 0.1 (10/11/2026)
- Qué se ha hecho: Corregido el inventario de Clásico para que el dash pueda robar y modificar el marcador; corregidos los bots que quedaban aturdidos permanentemente y la dirección/velocidad de su dash; las reposiciones de cofres/monedas evitan obstáculos y monedas cercanas; BFS ahora exige conectividad completa; los obstáculos miden de 1 a 3 casillas. Configurados nombre y versión 0.1.
- Decisiones: Las plantillas oficiales de exportación Windows no están instaladas. El paquete local usa un lanzador pequeño, el runtime Godot 4.7.2 y el PCK; deben permanecer juntos en `build/`.
- Problemas encontrados y cómo se resolvieron: La exportación Windows oficial falló por ausencia de `windows_debug_x86_64.exe` y `windows_release_x86_64.exe`; se produjo y probó el paquete de runtime alternativo. La suite core y el arranque headless del runtime pasan.
- Qué tienen que probar los humanos: Ejecutar `build/VoodooCombo-0.1.exe` en Windows, confirmar el menú y jugar una partida de cada modo. Para una exportación autocontenida estándar, instalar las plantillas de exportación de Godot 4.7.2 y usar `export_presets.cfg`.

### Revisión — Integración del paquete de personajes y arenas (13/11/2026)
- Qué se ha hecho: Copiados al proyecto los recursos y guías de `VoodooCombo-pack-companero`; `ArenaGen` ahora carga `arenas.json`, elige entre las cuatro arenas sin repetir la anterior, usa sus salidas/obstáculos y coloca doblones evitando trampas fijas. La partida dibuja los fondos, sprites de personajes con animaciones básicas y sprites de trampas periódicas. Actualizados `build/VoodooCombo-0.1.pck` y `build/VoodooCombo-0.1-Windows.zip`.
- Decisiones: Se conservaron los datos y los nombres de archivos originales del paquete. El generador acepta los arrays que trae `arenas.json` y el formato de texto documentado en `ARENAS.md`; la selección de salidas y sus asignaciones usa la semilla.
- Problemas encontrados y cómo se resolvieron: Godot no podía escribir su configuración en las rutas de usuario del entorno; al redirigir `APPDATA`, `LOCALAPPDATA` y las carpetas temporales a `.godot-appdata/` y `.godot-tmp/`, se generó un PCK válido. La suite core pasó y el PCK actualizado arranca en modo headless.
- Qué tienen que probar los humanos: Abrir `build/VoodooCombo-0.1.exe` y confirmar las cuatro arenas, el encaje de los fondos, escala/animación de los personajes, colisiones y ubicación de doblones. Las imágenes de las trampas están integradas; sus efectos de juego aún no están conectados.
