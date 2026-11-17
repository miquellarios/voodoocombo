# AGENTS.md — VoodooCombo

> Instrucciones permanentes para el agente (Codex las lee en cada tarea). Es la fuente de verdad del proyecto:
> si un prompt contradice este archivo, pregunta antes de programar.
> Visión y referencias del diseño para humanos: `docs/DISENO.md`. Requisitos del enunciado y plan: `docs/PLAN.md`.

## 1. Qué es

Party game **multijugador en tiempo real** de 2 a 4 jugadores, con partidas cortas en una sola pantalla y en una arena aleatoria.
Cada jugador elige un personaje (muñecos vudú de fantasía: Brasa, Colmillo, Tuerca o Cripta) y recoge doblones en una de las 4 arenas con trampas, encadena combos y golpea con el dash para robar.
Tiene dos modos (§4.6):
- **VoodooCombo** (por defecto): gana quien tenga más doblones a los 90 s.
- **Clásico:** literal del enunciado. Hay 50 doblones repartidos y gana el primero en recoger 15.

Un servidor autoritativo gestiona la partida y anuncia al ganador a todos los jugadores.

**Prioridad absoluta: que sea simple y que cada acción dé dopamina.**
Si una funcionalidad añade reglas que no se entienden en 5 segundos, no entra.

## 2. Reglas técnicas

- **Motor:** Godot 4 + GDScript con tipos estáticos. Lee `config/features` de `project.godot` para saber la versión y usa solo APIs de esa versión.
- **Renderer:** Compatibility. **Ventana:** 1280×720, stretch `canvas_items`, aspect `expand`.
- **Assets:** solo los del proyecto.
  - `assets/fonts/`: New Rocker, Lilita One y Baloo 2 (licencia OFL). Si faltan, se usa la fuente por defecto sin errores.
  - `assets/characters/`: sprites de los personajes, generados por Claude. Cómo usarlos: `assets/characters/SPRITES.md`.
  - `assets/arenas/`: fondos, mapa (`arenas.json`) y sprites de las trampas, generados por Claude. Cómo usarlos: `assets/arenas/ARENAS.md`.
  - Doblones, cofres, iconos de hechizos, partículas y sonidos se generan por código (`_draw()`, `AudioStreamWAV`).
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
  assets/    fonts/  characters/  arenas/
  autoload/  net.gd  profile.gd  settings.gd  i18n.gd  sfx.gd  fx.gd  char_sprites.gd
  core/      game_config.gd  arena_data.gd  arena_gen.gd  scoring.gd  item_table.gd  ranking.gd
  net/       match_server.gd  hazards.gd  lan_discovery.gd  http_endpoint.gd  bot_brain.gd
  scenes/    main/  menu/  lobby/  match/  podium/  customize/  settings/
  ui/        theme_builder.gd  widgets/
  tests/     run_tests.gd  test_*.gd
```

## 4. Reglas del juego

### 4.1 Arenas
- **Cuatro arenas** de 1200×600 px, con casillas de 40 px. Todo su contenido está en `assets/arenas/arenas.json`:

  | id | Nombre | Trampas |
  |---|---|---|
  | `cienaga` | Ciénaga Embrujada | Lodo, Raíces |
  | `cripta` | Cripta de Huesos | Pinchos, Fantasma |
  | `taller` | Taller Gnómico | Cintas, Vapor, Barril explosivo |
  | `biblioteca` | Biblioteca Arcana | Portales, Rayo arcano |

- **Elección:** después de elegir modo, se selecciona una de las cuatro arenas o aleatoria. La arena preferida se guarda en el perfil; aleatoria usa la semilla y evita repetir la anterior.
- **Mapa:** obstáculos, trampas y salidas salen de `arenas.json`. El layout es simétrico, así que todas las salidas son igual de justas.
- **Salidas:** se elige al azar uno de los `spawn_sets` y se reparte al azar entre los jugadores.
- **Al empezar:** cada jugador ve "¡Eres el Jugador N!" con una flecha sobre su personaje durante 3 s.
- **Doblones y cofres:** van en casillas libres al azar. Nunca en obstáculos ni en trampas fijas; sobre el lodo sí.

### 4.2 Jugador
- **Movimiento:** 260 px/s, radio de 22 px para jugadores; contra obstáculos usa los pies (radio 14 px, 12 px por debajo del centro). Choca también con los bordes.
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
- **Al empezar:** VoodooCombo arranca con **30 doblones** repartidos por la arena, a 35 px como mínimo entre ellos y de los obstáculos.
- **Reposición:** si quedan menos de 12, aparece uno cada 1,0 s (en Frenesí, hasta mantener unos 18). Clásico arranca con 50 y no repone.
- **Valor de cada doblón:** multiplicador de combo +1 si es Frenesí +1 si llevas el Anillo (máximo 5). Clásico siempre vale 1.
- **Combo:**
  - Sube en +1 por cada doblón recogido con menos de 1,5 s desde el anterior.
  - Se pierde al pasar 1,5 s sin recoger o al recibir un golpe.
- **Multiplicador según el combo:**
  - 0-4: x1
  - 5-11: x2, con el aviso "¡Combo!"
  - 12 o más: x3, con el aviso **"¡VOODOO COMBO!"**

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
- **Uso:** los cofres guardan un hechizo sin activarlo. E o B activan la ranura; cada duración empieza en ese momento. Un hechizo activo o guardado impide abrir otro cofre.
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
| Doblones | 30 al empezar; repone bajo 12 (Frenesí: 18) | 50 al empezar y no reaparecen |
| Objetivo | Tener más doblones a los 90 s (60/90/120 a elegir) | **El primero en recoger 15 gana al instante**. Si a los 3 min nadie llega, gana quien tenga más |
| Combo | Con multiplicador x1–x3; Frenesí y Anillo suman +1 cada uno | Solo visual: cada doblón vale 1 |
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

### 4.8 Trampas de arena

| Trampa | Efecto al activarse |
|---|---|
| Lodo | Velocidad ×0,6 dentro de la elipse. |
| Raíces | Aviso 0,7 s; atrapan 1 s a ≤36 px y quitan el 15 % (mín. 2, máx. 10). |
| Pinchos | 2 s abajo, 0,6 s de aviso y 1 s arriba; arriba quitan el 15 % (mín. 2, máx. 10). |
| Fantasma | Recorre su ruta a 120 px/s; al tocar aturde 0,6 s y quita el 15 % (mín. 2, máx. 10). Ignora al jugador afectado 2 s. |
| Cinta | Empuja jugadores y doblones a 140 px/s. |
| Vapor | Periodo de 4 s: aviso 0,6 s y chorro 0,5 s; a ≤70 px empuja 90 px, aturde 0,3 s y quita el 15 % (mín. 2, máx. 10). |
| Barril | Un dash inicia una mecha de 0,8 s; explota a ≤110 px, empuja 90 px y quita el 15 % (mín. 2, máx. 10). Reaparece a los 15 s. |
| Portal | Teletransporta a la pareja y añade 30 px en la dirección de movimiento; espera de 1 s por jugador. |
| Rayo | Dos brazos de 280 px giran cada 8 s; tocar a ≤32 px quita el 15 % (mín. 2, máx. 10). |

Todas las trampas que dañan quitan el 15 % de los doblones (mínimo 2, máximo 10; si tienes menos, los que tengas). Los golpes de dash entre jugadores mantienen el 25 % (mínimo 3, máximo 12; con corona 35 %, con Anillo 40 %), aturden 0,4 s, reinician el combo y dan 1,5 s de invulnerabilidad. La Capa Élfica los bloquea.

- **Avisos:** toda trampa periódica anuncia antes de hacer daño.
- **Bots:** esquivan los pinchos levantados y el rayo, y usan los portales si les acercan a un doblón.

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
- **Intenciones del cliente** (`reliable`): `request_join(nick, character, cosmetics, version)`, `request_ready()`, `request_dash(dir)`, `request_use_item(dir)`, `request_rematch()`.
- **Servidor:**
  - Ejecuta la lógica a 30 Hz: doblones, cofres, golpes, hechizos y tiempo.
  - Manda eventos `reliable`: `coin_spawned`, `coin_taken(id, by, value, combo)`, `player_hit(victim, attacker, dropped)`, `item_rolled`, `item_used`, `frenzy_started`, `hazard_event(type, data)`, `match_over(ranking, awards)`.
  - Las trampas periódicas (pinchos, vapor, fantasma, rayo) se calculan con el reloj de la partida en todos los peers. Raíces y barriles los decide el servidor.
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

## 7. Identidad visual (fantasía oscura)

- **Regla general:** fondo casi negro con niebla y velas. Solo lo importante va saturado: personajes, doblones dorados y trampas avisando.
- **Paleta:**

  | Uso | Color |
  |---|---|
  | Fondo | `#0B0710` |
  | Sombra de títulos | `#5C1018` (rojo sangre) |
  | Doblón | `#FFD23F`, con brillo `#FFF6C2` |
  | Hueso | `#E8DCC4` |
  | Escarcha | `#7FE7FF` |
  | Almas | `#B06BFF` |
  | Texto | `#FFFFFF` y, secundario, `#B8A9D1` |

- **Jugadores:** J1 coral `#D8484F` ● · J2 azul `#3C7FD0` ▲ · J3 lima `#63A83A` ■ · J4 hueso `#D9D0BE` ◆.
  - Los sprites ya vienen en cada color.
  - La forma (● ▲ ■ ◆) la dibuja el juego bajo el personaje y junto al nombre.
- **Personajes:** son cosméticos (sprites de `assets/characters/`). Muñecos vudú de arpillera con aspecto de fantasía:

  | Personaje | Rol |
  |---|---|
  | Brasa | Mago del fuego |
  | Colmillo | Trol del pantano |
  | Tuerca | Gnomo inventor |
  | Cripta | Nigromante |

  - Animaciones: idle, walk, dash, hurt y win.
  - En el HUD se muestra el nombre del personaje junto a "J1"-"J4".
- **Tipografía:**
  - **New Rocker:** logo, títulos, banners ("¡FRENESÍ!", "¡VOODOO COMBO!") y palabras grandes. Relleno hueso (`#F4ECDA` → `#A8977A`) u oro viejo (`#FFE7A0` → `#8A5A12`), con contorno `#0B0710` y sombra roja sangre.
  - **Lilita One:** números (marcador, tiempo, "+N", cuenta atrás).
  - **Baloo 2:** el resto del texto. Mínimo 18 px.
- **Logo:** "VOODOO" en hueso y "COMBO" en oro viejo, con un alfiler clavado en la última O.
- **HUD:** solo 3 elementos fijos.
  1. Jugadores con su personaje y su puntuación (la corona en el líder).
  2. Tiempo en grande arriba, en el centro.
  3. Ranura del hechizo abajo a la izquierda.
  - Paneles `#241838` con borde de costura.
- **Ambiente:** encima de la arena, niebla que se mueve despacio, velas que parpadean y viñeta oscura. Todo respeta "Reducir movimiento".

## 8. Accesibilidad

- **Controles:**

  | Acción | Teclado | Mando |
  |---|---|---|
  | Mover | WASD o flechas | Stick izquierdo |
  | Dash | Espacio o Shift | A |
| Hechizo | E | B |
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
