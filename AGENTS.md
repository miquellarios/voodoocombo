# AGENTS.md — VoodooCombo

> Instrucciones permanentes para el agente (Codex las lee en cada tarea). Es la fuente de verdad del proyecto:
> si un prompt contradice este archivo, pregunta antes de programar.
> Visión y referencias del diseño para humanos: `docs/DISENO.md`. Requisitos del enunciado y plan: `docs/PLAN.md`.

## 1. Qué es

Party game **multijugador en tiempo real** de 2 a 4 jugadores, con partidas cortas en una sola pantalla y en una arena aleatoria.
Cada jugador es un muñeco vudú que recoge doblones, encadena combos y golpea con el dash para robar.
Tiene dos modos (§4.6):
- **VoodooCombo** (por defecto): gana quien tenga más doblones a los 90 s.
- **Clásico:** literal del enunciado. Hay 50 doblones repartidos y gana el primero en recoger 15.

Un servidor autoritativo gestiona la partida y anuncia al ganador a todos los jugadores.

**Prioridad absoluta: que sea simple y que cada acción dé dopamina.**
Si una funcionalidad añade reglas que no se entienden en 5 segundos, no entra.

## 2. Reglas técnicas

- **Motor:** Godot 4 + GDScript con tipos estáticos. Lee `config/features` de `project.godot` para saber la versión y usa solo APIs de esa versión.
- **Renderer:** Compatibility. **Ventana:** 1280×720, stretch `canvas_items`, aspect `expand`.
- **Assets:** ninguno externo salvo `assets/fonts/` (Lilita One y Baloo 2, licencia OFL). Si las fuentes faltan, se usa la fuente por defecto sin errores.
  - Muñecos, arena, iconos, partículas y sonidos se generan por código (`_draw()`, `AudioStreamWAV`).
- **Escenas `.tscn` mínimas:** nodo raíz + script. La UI se construye en código.
- **`core/` es lógica pura:** clases `RefCounted` sin nodos ni autoloads, con la aleatoriedad a partir de una semilla.
  - Contiene la generación de arena, las reglas de combo y robo, la tirada de hechizos y el ranking con los premios.
  - Se testea en headless.
- **Autoridad:** el servidor decide doblones, cofres, golpes, hechizos, puntos y tiempo. Cada cliente solo controla el movimiento de su muñeco.
- **Textos:** todo texto visible pasa por `I18n.t("clave")` (es, ca, en).
- **Constantes:** todos los números de este archivo van en `core/game_config.gd`, para poder ajustar sin tocar la lógica.
- **Idioma:** código en inglés; textos de usuario y comentarios en castellano.

## 3. Estructura

```
res://
  AGENTS.md  README.md
  docs/      DISENO.md  PLAN.md  BITACORA.md  HISTORIA-IA.md  INVESTIGACION.md  PROMPTS-CODEX.md  conversaciones/  capturas/
  assets/fonts/
  autoload/  net.gd  profile.gd  settings.gd  i18n.gd  sfx.gd  fx.gd
  core/      game_config.gd  arena_gen.gd  scoring.gd  item_table.gd  ranking.gd
  net/       match_server.gd  lan_discovery.gd  http_endpoint.gd  bot_brain.gd
  scenes/    main/  menu/  lobby/  match/  podium/  customize/  settings/
  ui/        theme_builder.gd  widgets/
  tests/     run_tests.gd  test_*.gd
```

## 4. Reglas del juego

### 4.1 Arena
- **Tamaño:** 1200×600 px dentro de la ventana, sobre una rejilla lógica de 30×15 casillas de 40 px.
- **Generación:** con semilla. Entre 6 y 10 obstáculos de 1 a 3 casillas, colocados con **simetría en espejo horizontal y vertical**.
- **Validación:** con BFS se comprueba que no queden zonas cerradas. Si las hay, se regenera con semilla+1.
- **Salidas:** en cada partida se elige al azar un juego de 4 puntos simétricos (las 4 esquinas o los 4 centros de los lados, con un margen de 2 casillas) y se reparten al azar entre los jugadores.
- **Al empezar:** cada jugador ve "¡Eres el Jugador N!" con una flecha sobre su muñeco durante 3 s.
- **Bioma:** `seed % 4`. Solo cambia la parte visual (ver §7).

### 4.2 Jugador
- **Movimiento:** 260 px/s, radio de 22 px, choca con los obstáculos y con los bordes.
- **Dash:**
  - Dura 0,18 s a 3× la velocidad normal (unos 140 px) y tiene 1,5 s de espera.
  - Si golpea a un rival, este:
    - suelta el `25 %` de sus doblones (mínimo 3, máximo 12; si lleva la corona, el `35 %`),
    - queda aturdido 0,4 s,
    - pierde su combo,
    - queda invulnerable 1,5 s (parpadeando).
  - **Choque de dashes:** si dos jugadores chocan los dos en dash, rebotan y nadie suelta nada.
- **Doblones sueltos:** saltan a una distancia de 60-140 px. La víctima no puede recogerlos durante los primeros 0,6 s.

### 4.3 Doblones y combo
- **Al empezar:** la partida arranca con **50 doblones** repartidos por la arena, a 35 px como mínimo entre ellos y de los obstáculos.
- **Reposición:** si quedan menos de 18, se repone uno cada 0,5 s (en Frenesí, hasta mantener unos 30). En modo Clásico no se reponen.
- **Valor de cada doblón:** 1 × multiplicador de combo × 2 si es Frenesí × 2 si llevas el Anillo.
- **Combo:**
  - Sube en +1 por cada doblón recogido con menos de 1,5 s desde el anterior.
  - Se pierde al pasar 1,5 s sin recoger o al recibir un golpe.
- **Multiplicador según el combo:**
  - 0-4: x1
  - 5-9: x2, con el aviso "¡Combo!"
  - 10-19: x3, con el aviso "¡Vudú!"
  - 20 o más: x4, con el aviso **"¡VOODOO COMBO!"**

### 4.4 Cofres y hechizos
- **Cofres:** aparece uno cada 8 s en una casilla libre al azar, con un máximo de 2 a la vez.
  - Si no tienes hechizo, al tocarlo se tira una ruleta de 0,8 s y el hechizo resultante se guarda en tu única ranura.
  - Si ya tienes uno, pasas por encima del cofre sin abrirlo.
- **Hechizos:**

| id | Nombre | Efecto |
|---|---|---|
| `magnet` | Imán de Mithril | Durante 5 s atrae los doblones en un radio de 220 px |
| `boots` | Botas de Montaraz | Durante 4 s: velocidad x1,6 y espera del dash de 0,5 s |
| `cloak` | Capa Élfica | Bloquea el siguiente golpe o hechizo. Dura 8 s como máximo |
| `pin` | Alfiler Vudú | Proyectil a 700 px/s con 900 px de alcance hacia donde miras. Al impactar tiene el mismo efecto que un dash |
| `frost` | Nova de Escarcha | Congela 1,5 s a los rivales en un radio de 180 px |
| `sheep` | Maldición Ovina | Va directa al líder (tarda 0,6 s en llegar). Durante 3 s el líder es una oveja: velocidad x0,6, no recoge y no hace dash |
| `ring` | Anillo de Poder | Durante 6 s los doblones valen doble. Si te golpean mientras lo llevas, sueltas el 40 % |

- **Capa Élfica bloquea:** dash, alfiler, escarcha y oveja.
- **Probabilidad de cada hechizo según tu posición** (%; con 2 jugadores solo existen las columnas "Primero" y "Último"):

| Hechizo | Primero | En medio | Último |
|---|---|---|---|
| magnet | 30 | 20 | 15 |
| boots | 25 | 20 | 15 |
| cloak | 30 | 15 | 5 |
| pin | 10 | 20 | 20 |
| frost | 5 | 15 | 15 |
| sheep | 0 | 7 | 20 |
| ring | 0 | 3 | 10 |

### 4.5 Partida (modo VoodooCombo; las diferencias del Clásico están en §4.6)
- **Inicio:** cuenta atrás 3-2-1-¡YA!.
- **Duración:** 90 s (el anfitrión puede elegir 60, 90 o 120).
- **Corona:** la lleva el líder en cada momento.
- **Frenesí:** en los últimos 15 s.
- **Final:** gana quien tenga más doblones. En caso de empate, gana quien tenga el combo máximo más alto.
- **Premios** (se calculan en `ranking.gd` y, si se puede, cada jugador recibe uno):

| Premio | Para quién |
|---|---|
| Rey del Combo | Combo máximo más alto |
| Manos Largas | Más doblones robados |
| Bala Perdida | Más dashes acertados |
| Oveja Oficial | Más veces convertido en oveja |
| Intocable | Menos golpes recibidos |

- **Revancha:** con el botón ¡Otra!. Si todos aceptan, empieza una partida nueva con nueva semilla en 3 s.

### 4.6 Modos (los elige el anfitrión en la sala)

| | VoodooCombo (por defecto) | Clásico (enunciado) |
|---|---|---|
| Doblones | 50 al empezar y reaparecen | 50 al empezar y no reaparecen |
| Objetivo | Tener más doblones a los 90 s (60/90/120 a elegir) | **El primero en recoger 15 gana al instante**. Si a los 3 min nadie llega, gana quien tenga más |
| Combo | Con multiplicador x1–x4 | Solo visual: cada doblón vale 1 |
| Frenesí | Sí | No |
| Dash y robo | Sí | Sí |
| Cofres y hechizos | Sí | Sí, menos el Anillo |
| Punto de partido | Aviso en los últimos 15 s | Aviso cuando alguien llega a 12 |

### 4.7 Bots
- **Para qué:** modo práctica y rellenar huecos de la sala.
- **Dónde corren:** en el servidor, como jugadores normales.
- **Comportamiento:**
  - Van hacia el doblón o cofre más cercano.
  - Si tienen un rival a menos de 120 px y el dash listo, hacen dash el 30 % de las veces.
  - Usan el hechizo cuando les sirve.

## 5. Red (tiempo real)

- **Transporte:** `ENetMultiplayerPeer`, puerto 7777.
- **Modos:**
  - Crear sala: servidor + Jugador 1 en el mismo juego.
  - Unirse: por IP o desde la lista LAN.
  - Servidor dedicado: `godot --headless -- --server`.
- **Descubrimiento LAN:** broadcast UDP en el puerto 7778 cada segundo con `{name, host_nick, players, version}`.
- **RPC:** todas viven en el autoload `Net`, para que la ruta `/root/Net` sea igual en todos los peers.
- **Movimiento:**
  - Cada cliente mueve su muñeco en local y manda `{pos, vel, facing}` al servidor 20 veces por segundo (`unreliable_ordered`).
  - El servidor descarta los saltos imposibles comparándolos con la velocidad máxima.
  - El servidor manda a todos un snapshot con las posiciones 20 veces por segundo, y los clientes interpolan a los demás jugadores con 100 ms de retraso.
- **Intenciones del cliente** (`reliable`): `request_join(nick, cosmetics, version)`, `request_ready()`, `request_dash(dir)`, `request_use_item(dir)`, `request_rematch()`.
- **Servidor:**
  - Ejecuta la lógica a 30 Hz: doblones, cofres, golpes, hechizos y tiempo.
  - Manda eventos `reliable`: `coin_spawned`, `coin_taken(id, by, value, combo)`, `player_hit(victim, attacker, dropped)`, `item_rolled`, `item_used`, `frenzy_started`, `match_over(ranking, awards)`.
- **Datos:** en las RPC solo se mandan tipos simples. Los doblones son datos (`id`, `pos`, `value`) y no nodos sincronizados.
- **Modo anfitrión:** el Jugador 1 es el peer 1, el mismo proceso que el servidor. Se le entregan los eventos directamente o con `call_local`.
- **Sala:**
  - Admite hasta 4 jugadores.
  - Cada uno tiene un color y una forma únicos según su orden de llegada (Jugador 1-4) y lo ve claramente.
  - El anfitrión es el *master*: elige el modo y la duración, y empieza cuando haya al menos 2 jugadores listos.
- **Desconexión:** el muñeco desaparece con un *puff* y la partida sigue. Si se queda un solo jugador, la partida acaba.
- **Al acabar:**
  - El servidor guarda la partida en `user://matches/<fecha>.json`.
  - El endpoint HTTP (`TCPServer`, puerto 8080) atiende estas rutas, con `Access-Control-Allow-Origin: *`:
    - `GET /status`: JSON de la partida en curso (modo, tiempo, jugadores y puntos).
    - `GET /results`: JSON de las últimas partidas con ganador, ranking y premios.
    - `GET /`: una página HTML mínima con el marcador en directo (consulta `/status` cada segundo) y la última clasificación. Sirve para enseñarla en la presentación.
- **Por qué este protocolo (para la documentación):** ENet manda mensajes asíncronos sobre UDP.
  - Las posiciones van por un canal no fiable: si se pierde un paquete, el siguiente ya lo corrige.
  - Los eventos importantes (doblones, golpes, ganador) van por un canal fiable.

## 6. Feedback obligatorio

Cada acción tiene respuesta visual y sonora en menos de 100 ms. Todo pasa por los autoloads `Fx` y `Sfx` y respeta el ajuste "Reducir movimiento".

| Evento | Qué tiene que pasar |
|---|---|
| Recoger | Texto "+N" que salta, 6 chispas, *pop* del marcador y un *cling* que sube un semitono por cada paso de combo |
| Subir de multiplicador | El número tiembla y cambia de color (blanco → `#FF9F1C` → `#FF4FD8` → arcoíris), aparece el texto del multiplicador y suena un acorde |
| Dash | Aplastamiento, estela del color del jugador, polvo y *whoosh* |
| Golpe | Parón de 60 ms, vibración de 6 px durante 150 ms, doblones en abanico, *boing* y monedas cayendo |
| Ruleta | 0,8 s de iconos girando sobre el muñeco con *tic* y un *ding* final. Si sale el Anillo, fanfarria y rayos |
| Frenesí | Cartel "¡FRENESÍ!", borde dorado latiendo, lluvia de doblones y música un 25 % más rápida |
| Últimos 5 s | Números gigantes en el centro, con un tambor en cada uno |
| Final | Cámara lenta de 0,5 s, confeti de doblones y el ganador baila. Después, el podio |

**Sonido:** todo sintetizado en código como `AudioStreamWAV`, más un bucle de tambores y bajo.

## 7. Identidad visual

- **Regla general:** fondo oscuro y apagado. Solo lo importante va saturado: jugadores, doblones y ataques.
- **Paleta:**

  | Uso | Color |
  |---|---|
  | Fondo | `#160E22` |
  | Doblón | `#FFD23F`, con brillo `#FFF6C2` |
  | Escarcha | `#7FE7FF` |
  | Texto | `#FFFFFF` y, secundario, `#B8A9D1` |

- **Jugadores:** Coral `#FF5A5F` ● · Azul `#3DA5FF` ▲ · Lima `#7BE042` ■ · Hueso `#F3EEFC` ◆.
  - La forma aparece siempre junto al nombre y bajo el muñeco.
  - Los ataques y proyectiles llevan el color de quien los lanza.
- **Contornos:** de 4 px en `#160E22` en todo lo jugable. Las siluetas tienen que reconocerse a 40 px.
- **Muñeco:**
  - Silueta de judía con cabeza grande, dos ojos de botón, boca cosida y costura en X.
  - Botea al andar, se estira en la dirección del movimiento y se aplasta en el dash.
  - Cosméticos: sombrero, ojos, estela y baile.
- **Doblones:** giran (escala X), brillan y tienen sombra.
- **Tipografía:** Lilita One para títulos y números, Baloo 2 para el resto. Texto de 18 px como mínimo.
- **HUD:** solo 3 elementos fijos.
  1. Jugadores ordenados con su puntuación (la corona en el líder).
  2. Tiempo en grande arriba, en el centro.
  3. Ranura del hechizo abajo a la izquierda, con su tecla.
  - El combo flota junto a tu muñeco y el anillo de espera del dash va bajo sus pies.
- **Biomas:** suelo apagado de dos tonos y decorado de bajo contraste.

  | Bioma | Suelo | Obstáculos |
  |---|---|---|
  | Ciénaga | `#2B3A2A` / `#243223` | Lápidas |
  | Bosque | `#33402A` / `#2B3723` | Árboles blancos |
  | Hielo | `#2A3A4A` / `#233241` | Cristales |
  | Forja | `#3A2A2A` / `#322323` | Rocas |

## 8. Accesibilidad

- **Controles:**

  | Acción | Teclado | Mando |
  |---|---|---|
  | Mover | WASD o flechas | Stick izquierdo |
  | Dash | Espacio o Shift | A |
  | Hechizo | E o Enter | B |
  | Pausa / menú | Esc | Start |

- **Menús:** se usan del todo con teclado y mando, con foco visible.
- **Nunca solo color:** formas ● ▲ ■ ◆ e iconos.
- **Ajustes:** reducir movimiento, escala de UI 100/125/150 %, volumen de música y de efectos, idioma.

## 9. Cómo trabajar

- **Una fase cada vez:** trabaja solo en la fase que se pide.
- **Antes de programar:** resume en 3-5 líneas qué vas a hacer.
- **Tests:** si hay Godot en el PATH como `godot`, ejecuta `godot --headless --path . --script res://tests/run_tests.gd` y arregla lo que falle. Si no está, dilo.
- **Al terminar cada fase:**
  1. Añade una entrada en `docs/BITACORA.md` (sección "Registro de Codex") con qué has hecho, las decisiones, los problemas y **qué tienen que probar los humanos**. No inventes problemas que no hayan pasado.
  2. Haz commit con el mensaje `Fase N: <resumen>`.
- **Si algo es ambiguo,** pregunta en vez de inventar.
