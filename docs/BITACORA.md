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

### Fase 9b — Rutas y antiatasco de bots (13/11/2026)
- Qué se ha hecho: Los bots buscan monedas y cofres con AStarGrid2D, recalculan la ruta cada 0,3 s, evitan casillas de pinchos activas, encarecen barriles y rayos, reparten objetivos entre bots y prueban una dirección de escape al detectar un atasco.
- Decisiones: Se inflan las celdas sólidas con el radio del jugador para que la ruta sea físicamente transitable, no solo libre en el centro de cada casilla.
- Problemas encontrados y cómo se resolvieron: El primer test tomó un camino que rozaba una esquina y el círculo no podía seguirlo; al incluir la huella de colisión en la cuadrícula, el bot llega al objetivo en menos de cinco segundos.
- Qué tienen que probar los humanos: Dejar bots en esquinas y alrededor de muros durante dos minutos y revisar que no se atasquen, que elijan cofres sin hechizo y que eviten pinchos, barriles y rayos.

### Fase 9c — Dash de bots y choques (13/11/2026)
- Qué se ha hecho: Los bots evalúan ataques cada 0,4–0,6 s, solo contra rivales visibles, cercanos, vulnerables y con dash disponible. Tras un golpe se bloquean 2,5 s; hay una pausa compartida entre bots para evitar cadenas. Dos dashes que chocan rebotan 70 px y bloquean el dash 0,3 s. El dash también se corta al chocar con un muro.
- Decisiones: Se prioriza el control de spam con una espera común de 2,5 s entre dashes de bots, manteniendo además el porcentaje de acierto del 30 % en cada decisión.
- Problemas encontrados y cómo se resolvieron: El test inicial superó el límite de cuatro dashes en diez segundos; una pausa compartida entre bots eliminó esa ráfaga y el test pasó.
- Qué tienen que probar los humanos: Dejar dos bots cerca durante diez segundos sin monedas próximas, observar choques entre dashes y confirmar que ninguno se queda haciendo dash repetidamente ni queda dentro del otro.

### Fase 9d — Trampas y golpes comunes (13/11/2026)
- Qué se ha hecho: Conectados los efectos del lodo, raíces, pinchos, fantasma, cintas, vapor, barriles, portales y rayo. Los golpes usan un cálculo común con doblones en abanico, combo perdido, aturdimiento, invulnerabilidad y bloqueo por Capa Élfica. Actualizadas las reglas en `AGENTS.md` y `assets/arenas/ARENAS.md`.
- Decisiones: Las trampas periódicas consultan `elapsed`; raíces y barriles usan estado de partida. Los efectos corren en la simulación local actual porque aún no hay una simulación de partida autoritativa integrada.
- Problemas encontrados y cómo se resolvieron: Godot detectó inferencias ambiguas en dos vectores; se declararon como `Vector2`. Los tests de reglas y el arranque headless de la escena pasaron.
- Qué tienen que probar los humanos: Probar cada trampa de las cuatro arenas, observar sus avisos/daños/caídas de doblones y repetir con Capa Élfica e invulnerabilidad activas.

### Fase 9e — Texturas de objetos y hechizos (13/11/2026)
- Qué se ha hecho: Integrados `assets/items/`; los doblones giran con desfases y bote sobre su sombra, los cofres tienen reposo y apertura animados, y los iconos de hechizo aparecen en la ranura y en la ruleta.
- Decisiones: Los tamaños, fps, escalas y tiras se leen desde `items.json`; la apertura dura 0,25 s y deja la ruleta del hechizo en sus 0,8 s existentes.
- Problemas encontrados y cómo se resolvieron: Los sprites no estaban aún en el proyecto; se copiaron desde el paquete de fase 9 y Godot los importó correctamente. Arranque headless y tests core pasaron.
- Qué tienen que probar los humanos: Recoger doblones, abrir cofres de cada arena, comprobar que los iconos de hechizo coinciden con el objeto ganado y que sus animaciones se distinguen sin solaparse.

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

### Fase 9f — HUD ilustrado (13/11/2026)
- Qué se ha hecho: Sustituido el marcador de texto por cuatro fichas con panel 9-slice, retrato, nombre, forma, puntuación animada y corona del líder; el reloj ahora muestra minutos y segundos, y la ranura inferior usa los gráficos de hechizos del kit. El HUD se dibuja en una capa superior y conserva el escalado de interfaz.
- Decisiones: Se muestran las cuatro fichas para mantener ubicaciones estables aunque haya menos jugadores; las fichas vacías se ocultan. La ficha local indica «TÚ» según el idioma.
- Problemas encontrados y cómo se resolvieron: Ninguno durante la compilación de scripts y las pruebas headless.
- Qué tienen que probar los humanos: Revisar el HUD en ventana 1280×720 y con escala 100/125/150 %, comprobar corona y puntos durante una partida y verificar los iconos de hechizos.
