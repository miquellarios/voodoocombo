# Fase 14 — Que no se cuelgue, que el online vaya fluido y que conectarse sea fácil

> **Para Codex.** Antes de empezar:
> 1. **Copia `docs/codex/fase-14/AGENTS.md` a la raíz como `AGENTS.md`.** Cambia §5.1: lista de partidas en tu red y alojar en mi PC.
> 2. Capturas de cómo está ahora en `docs/capturas/fase-13-revision/`. Claude las sacó ejecutando el juego (commit `96cd5da`) y comprobó cada fallo.

## Qué nos ha pasado al probar la fase 13

- **El juego va cada vez más lento, online y contra bots, y acaba colgándose o cerrándose.**
- **Online va a tirones:** tu muñeco da saltitos hacia atrás.
- **Conectarse desde otro ordenador cuesta:** hay que saber qué IP poner, abrir puertos, etc. Desde casa se arregla en la fase 15, con un servidor en internet; aquí, el modo sin internet.
- Varias cosas de la fase 13 están a medias: escala de la interfaz, marcador, podio y algunos detalles.

## Cómo trabajar esta fase

- Son 9 bloques (**14a-14i**), con **un commit por bloque** (`Fase 14a: <resumen>`).
- **14a es urgente** y va primero: es el cuelgue.
- Después de 14a y 14b, haz la prueba de 14i con dos PCs **antes** de seguir con lo visual.

---

## 14a · El cuelgue: un error que crea un texto nuevo en cada fotograma (URGENTE)

**Causa** (comprobada; capturas `racha_atascada_1.jpg` y `racha_atascada_2.jpg`):
- En `scenes/main/main.gd`, `_finish_pickup_streak()`, línea ~2348:
  ```gdscript
  var destination: Vector2 = hud_root.to_local(...)
  ```
- `hud_root` es un `Control`, y **`Control` no tiene `to_local()`** (eso es de `Node2D`). Da `SCRIPT ERROR: Invalid call. Nonexistent function 'to_local' in base 'Control'`.
- El error corta la función **después** de `hud_root.add_child(label)` y **antes** de `pickup_streak_value = 0`. Por eso:
  1. la racha nunca se reinicia;
  2. `_process()` vuelve a llamar a `_finish_pickup_streak()` **en cada fotograma**;
  3. en cada fotograma se añade un `Label` "+N" nuevo a `hud_root` que nunca se borra, y se imprime el error con su traza.
- **Lo medimos:**
  - en 30 s salen 798 errores;
  - `hud_root` pasa de 378 a 983 nodos y sigue creciendo;
  - en un PC a 144 fps son miles de nodos por minuto: tirones, cada vez más lento, y al final se cuelga o se cierra.
  - Pasa en cuanto **tú** coges un doblón, online y contra bots.
- **Efecto secundario:** tu ficha del marcador **se queda en 0 toda la partida**, porque `_update_hud()` espera a que la racha acabe para actualizarla (línea ~704). Lo vimos en todas las partidas.

**Arreglo:**
- Destino en coordenadas del `hud_root`:
  ```gdscript
  var destination := hud_root.get_global_transform().affine_inverse() * (target_global_position)
  ```
  O mejor: `score_number_labels[local_player].global_position - hud_root.global_position`, y anima `global_position`.
- `pickup_streak_value = 0` y `pickup_streak_count = 0` van **al principio**, después de guardar `total`. Así, aunque algo falle, nunca se repite.
- **Defensas:**
  - `Fx` y el HUD no pueden tener más de `GameConfig.MAX_FLOATING_LABELS = 12` textos flotantes; si hay más, se borra el más viejo;
  - un aviso en la bitácora si en una partida se crean más de 500 nodos.
- **Tests** (headless, `tests/`):
  - cogiendo doblones durante 30 s simulados, `hud_root.get_child_count()` no crece más de 40;
  - la ficha del jugador local termina con la misma puntuación que `players[local].score`;
  - ningún `SCRIPT ERROR` en una partida completa de 90 s contra 3 bots con el jugador local cogiendo doblones. Captura la salida y busca "SCRIPT ERROR".

## 14b · Online fluido (sin saltitos)

Tras 14a el juego ya no se va frenando. Pero los saltitos online tienen **otra causa**, en el servidor.

**Causa 1: el servidor se salta pasos de tu movimiento.**
- `net/server_main.gd` → `_accept_input()` **sobrescribe** `room.inputs[sender]` con la última entrada que llega.
- El cliente manda 30 entradas por segundo y el servidor simula 30 pasos por segundo, pero los paquetes no llegan uno por paso: por wifi llegan a veces 2 juntos y a veces ninguno.
- **Cuando llegan 2 juntos, una se pierde**, y aun así `room.sequences[sender]` confirma (`ack`) la última.
- El cliente cree que el servidor aplicó los dos pasos y su predicción va por delante: la corrección lo tira para atrás. Eso es el "va lageado".

**Arreglo:**
- **Cola de entradas por jugador** en el servidor:
  - cada `submit_input` se añade a `room.input_queue[sender]`, con como mucho 6;
  - en cada paso de simulación se consume **una**;
  - si la cola está vacía, se repite el último `move` (como mucho 0,25 s; luego, quieto);
  - si hay más de 3, se consumen 2 en ese paso para alcanzar.
- **`ack`** = la última secuencia **aplicada** de verdad, no la última recibida.
- El dash y el hechizo siguen por `intent` fiable, como ahora.

**Causa 2: cada snapshot va en 2 paquetes.**
- El snapshot pesa unos **7 KB** sin comprimir y unos **1,5 KB** con zstd. `NET_CHUNK_BYTES = 1000`, así que **cada snapshot va en 2 trozos `unreliable`**.
- Si se pierde uno, se pierde el snapshot entero. Con un 3 % de pérdida, pierdes un 6 % de snapshots.

**Arreglo:**
- **Adelgaza el snapshot** para que quepa en **un solo paquete de menos de 1000 bytes** comprimido:
  - **jugadores:** solo `pos` (redondeada a entero), `vel`, `facing`, `anim`/estado, `score`, `combo`, `item`, `item_time` (en décimas) y los temporizadores visibles (`stun`, `invuln`, `dash_left`);
  - fuera los ~40 campos internos;
  - **doblones:** no los mandes enteros 20 veces por segundo. Ya hay eventos (`coin_taken`, `coin_spawned`); manda la lista completa solo cada 1 s o cuando cambie;
  - **cofres, efectos de hechizo y proyectiles:** solo los que existen.
- Mide los bytes de cada snapshot y apúntalo en la bitácora: con 4 jugadores, menos de 1000 bytes comprimido.

**Más cosas:**
- El **ping** va por un RPC `unreliable` propio, no `reliable`, para que no espere detrás de otros paquetes.
- **Interpolación adaptable:** 100 ms si el ping es estable y hasta 160 ms si hay *jitter*. Calcula la media del *jitter* de llegada de los snapshots.
- La **corrección de tu muñeco** no debe notarse:
  - si el error es menor de 24 px, se corrige en 0,2 s;
  - entre 24 y 96 px, en 0,1 s;
  - solo se teletransporta por encima de 96 px (portales, golpes).
- **Predice también** lo que mueve tu muñeco sin que tú lo muevas: la **cinta** (140 px/s) y el **lodo** (ya está). Los golpes y portales no se predicen.
- **Indicador de conexión** arriba a la derecha, con el ping en ms y color, y "Conexión inestable" si se pierden más del 5 % de snapshots.

**Test** (headless, tres procesos: servidor + 2 clientes):
- simula pérdida y *jitter*: tira el 5 % de los snapshots y retrasa entre 0 y 60 ms las entradas en el cliente de prueba;
- en 30 s de movimiento recto, el error medio entre la posición predicha y la del servidor tiene que ser menor de 6 px.

## 14c · Jugar sin internet: partida en mi red y alojar en mi PC

> **Cambio del equipo (27/11):** jugar **desde casa** va por un **servidor en internet** con enlaces de invitación. Es la **fase 15**, que va justo después de esta.
> Aquí solo se deja bien el modo **sin internet** (clase, misma wifi), que sirve de reserva.
> **No hagas UPnP, ni códigos con la IP dentro, ni la detección de VPN:** ya no hacen falta.

**Lo que molesta ahora:**
- hay que escribir la IP del anfitrión a mano;
- la IP que enseña el juego **a veces es la equivocada**: `_find_private_ipv4()` coge la primera privada, y en Windows suele ser un adaptador virtual (Hyper-V, WSL, VirtualBox: 172.x).

**Qué hacer:**
- **Partidas en tu red:** una lista que se actualiza sola cada segundo, con el `LanDiscovery` que ya existe y que **ahora no usa nadie**.
  - El anfitrión anuncia por broadcast UDP 7778: nombre del anfitrión, modo, jugadores, versión, IP local, puerto y código.
  - Cada partida es una tarjeta con **ENTRAR**: un clic y dentro.
  - Si la versión no coincide, la tarjeta sale en gris con "Versión distinta".
- **Unirse solo con el código en la misma red:** si escribes los 5 caracteres, el juego pregunta por broadcast "¿quién tiene la sala KWET7?" y entra si alguien contesta.
- **IP del anfitrión:**
  - 192.168.x.x primero, luego 10.x y luego 172.16-31.x;
  - **descarta** los adaptadores con "vEthernet", "VirtualBox", "VMware" o "WSL" en el nombre (`IP.get_local_interfaces()`);
  - se ve y se puede cambiar en una lista pequeña.
  - El campo de IP a mano pasa a AJUSTES → ONLINE → "Avanzado".
- **Mensajes claros** al conectar, en una línea:
  - "No contesta nadie en esa dirección. ¿Tiene el anfitrión la partida abierta?"
  - "Sala llena"
  - "Versión distinta"
  - Como mucho 3 reintentos.
- **Antes de alojar por primera vez:** aviso del cortafuegos de Windows ("pulsa Permitir, redes privadas").
- **Dónde va:**
  - todo esto se queda en un botón **SIN INTERNET (EN CLASE)** de la pantalla JUGAR;
  - la pantalla JUGAR entera se rehace en la fase 15 (`docs/media/jugar_online_referencia.png`), así que aquí no la rediseñes.

## 14d · Si se cierra, que sepamos por qué

- Activa en `project.godot`: `debug/file_logging/enable_file_logging=true` (también en el *export*). Así se escribe `user://logs/godot.log`.
- **AJUSTES → ONLINE:** un botón **ABRIR CARPETA DE REGISTROS**, con `OS.shell_open(ProjectSettings.globalize_path("user://logs"))`.
- **Al arrancar,** si la última sesión no se cerró bien (un archivo `user://running.lock` que se borra al salir), un aviso: "El juego se cerró la última vez. Si se repite, mándanos el archivo godot.log", con el botón de abrir la carpeta.
- El **servidor alojado** escribe su propio log en `user://logs/servidor.log`. Lánzalo con `--log-file`, o redirige `print`.
- En `LEEME.txt`, dónde está la carpeta en Windows: `%APPDATA%\Godot\app_userdata\VoodooCombo\logs`.

## 14e · Escala de la interfaz (lo que quedó a medias en 13a)

**Ahora** (`ajustes_100.jpg` y `ajustes_escala_115.jpg`):
- solo cambia la pantalla de ajustes: el menú, el lobby, el HUD y el podio siguen igual;
- de 150 % salta a 75 % (`posmod`);
- al cambiar la escala, la pantalla se reconstruye y **las flechas cambian de sitio**, así que el segundo clic cae en otro sitio;
- a 115 % el panel queda pegado a la izquierda.

**Arreglo:**
- Aplica la escala **a todo** con `get_window().content_scale_factor = Settings.ui_scale`, o escalando el `CanvasLayer` raíz de cada pantalla con pivote en el centro.
  - Quita los `roundi(x * Settings.ui_scale)` repartidos por el código.
  - **El mundo de la partida (arena y muñecos) no se escala**, solo la interfaz.
- **Sin vuelta:** 75 % es el mínimo y 150 % el máximo. En los extremos, la flecha de ese lado sale gris.
- **La fila tiene que quedarse quieta** al cambiar: no reconstruyas la página entera, cambia solo el texto del valor.
- **Ajustes con la letra del juego:**
  - el título y las pestañas salen ahora con la fuente por defecto de Godot; usa Cinzel para el título y las pestañas y Oswald para las filas (`ThemeBuilder.build()` en el `CanvasLayer`);
  - quita el rectángulo blanco de foco del valor: el foco es la fila con borde de brasa, como en `ajustes_referencia.png`.
- **Test:** con cada escala, recorre todos los `Control` visibles del menú, los ajustes, el lobby, el HUD y el podio. Ninguno puede salirse de 1280×720.

## 14f · Marcador

**Ahora** (`partida_marcador.jpg`, `partida_final.jpg` y `codicia.jpg`):
- **Al reordenar las fichas,** algunos números quedan detrás del reloj o fuera de su ficha; se ven dos números encima ("28/18"). La ficha del líder a veces sale sin número. Al final de la partida los números parecen cambiar de jugador (Mordisquitos 80 → 19).
  - Revisa `_layout_score_cards()`: **número, nombre, retrato y corona tienen que ser hijos de la misma ficha** y moverse con ella, no `Label` sueltos colocados aparte.
- **En Codicia** solo salen 3 fichas y los totales del equipo son un "● 2 ◆ 0" pequeño dentro de la arena. Tienen que ser los **dos cofres arriba en el centro**, a los lados del tiempo, con el total en grande (13d).
- **En Último en Pie,** las costuras de las fichas siguen siendo "x x x" diminutas (`ultimo_en_pie.jpg`). Usa `costuras.png` a 28 px.

## 14g · Podio (lo que quedó a medias en 13h)

`podio.jpg`:
- las placas siguen tapando el "1º", "2º" y "3º";
- MENÚ PRINCIPAL y ¡OTRA! siguen encima de los bloques del podio.

**Cómo tiene que quedar:**
- número de puesto **dentro** del bloque, arriba;
- placa **debajo** del bloque;
- botones en una fila propia a 40 px del borde de abajo, fuera del podio;
- el 4º, de pie a la derecha con su placa debajo.

**Test:** los rectángulos de las placas, los números y los botones no se cruzan, con 2, 3 y 4 jugadores.

## 14h · Detalles

- **Ayuda "¿Jugar desde otra casa?":** es un `AcceptDialog` gris de sistema con el texto cortado (`ayuda_otra_casa.jpg`). Hazla un panel del juego, con la misma letra y colores, texto con `autowrap` y un botón VOLVER.
- **ELIGE MODO y JUGAR ONLINE:** el título queda encima del estandarte del fondo (`elige_modo.jpg`). Bájalo o oscurece el estandarte detrás.
- **Lobby de Codicia:** los rótulos "EQUIPO CORAL" y "EQUIPO AZUL" se pisan entre ellos (`lobby_codicia.jpg`). Uno por pareja de estrados, centrado.
- **Taquilla, emotes:**
  - la rueda de 8 huecos es diminuta (iconos de ~20 px) y se pisa; hazla de 360 px de diámetro con iconos de 56 px (`taquilla_emotes.jpg`);
  - el emote calavera sale como "Marco calavera": usa su propio texto;
  - la rejilla se corta abajo: que se vea entera o que tenga *scroll* visible.
- **Alojar desde el editor:**
  - `OS.create_process(OS.get_executable_path(), …)` sin `--path` abre el gestor de proyectos cuando se juega desde el editor;
  - si `OS.has_feature("editor")`, añade `["--path", ProjectSettings.globalize_path("res://")]`.
  - Así se puede probar alojar sin exportar.
- **Hechizos:** se ven bien la escarcha, el alfiler y la oveja. El imán, la capa y el anillo se ven poco: súbeles la opacidad al 85 % y el tamaño un 25 %.

## 14i · Prueba con dos PCs y entrega

1. **Exporta** `build/VoodooCombo-v0.14.0-Windows.zip`.
2. **Súbelo** a GitHub como *release* `v0.14.0`. Si no puedes desde la terminal, dilo en la bitácora para que Joel lo suba a mano desde la web (Releases → Draft a new release).
3. **Prueba real, apuntada en la bitácora con el resultado de cada punto:**

| Prueba | Resultado esperado |
|---|---|
| Dos PCs en la misma wifi | El segundo ve la partida en la lista y entra con un clic |
| Mismo caso, escribiendo solo los 5 caracteres de la sala | Entra |
| Partida completa de 90 s online | Sin saltitos visibles y sin `SCRIPT ERROR` en `godot.log` |
| 3 partidas seguidas sin cerrar el juego | La memoria (Administrador de tareas) no sube más de 50 MB |
| El anfitrión cierra el juego | Al otro le sale el aviso y vuelve al menú, sin cerrarse |
