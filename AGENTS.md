# AGENTS.md — VoodooCombo (versión para la fase 12)

> Instrucciones permanentes para el agente (Codex las lee en cada tarea). Es la fuente de verdad del proyecto:
> si un prompt contradice este archivo, pregunta antes de programar.
> **Esta versión describe cómo tiene que quedar el juego al terminar la fase 12.** Incluye:
> - todo lo de las fases 10 y 11: letra "Brasa minimal", online con salas, lobby y votación;
> - la dopamina de la fase 12;
> - los modos nuevos, sin el Clásico.
>
> Antes de empezar la fase 12, copia este archivo a la raíz del proyecto como `AGENTS.md`. Sustituye a la versión de la fase 11.
> Visión y referencias del diseño para humanos: `docs/DISENO.md`. Requisitos del enunciado y plan: `docs/PLAN.md`.

## 1. Qué es

Party game **multijugador en tiempo real** de 2 a 4 jugadores, con partidas cortas en una sola pantalla y en una arena votada por los jugadores.
Cada jugador elige un personaje (muñecos vudú de fantasía: Brasa, Colmillo, Tuerca o Cripta) y recoge doblones en una de las 4 arenas con trampas, encadena combos y golpea con el dash para robar.

Tiene tres modos (§4.6):
- **VoodooCombo** (por defecto): gana quien tenga más doblones a los 90 s.
- **Último en Pie:** todos contra todos con 3 costuras, al mejor de 3 rondas (§4.9).
- **Codicia 2v2:** por equipos; los doblones solo cuentan al guardarlos en el cofre del equipo (§4.10).

El modo Clásico del enunciado se quitó por decisión del equipo (ver `docs/HISTORIA-IA.md`).

Se juega online con **código de sala** contra un **servidor dedicado y autoritativo**, o contra bots sin red. El servidor gestiona la partida y anuncia al ganador a todos los jugadores.

**Prioridad absoluta: que sea simple y que cada acción dé dopamina.**
Si una funcionalidad añade reglas que no se entienden en 5 segundos, no entra.

**Dopamina "de la buena":**
- **Se recompensa** jugar bien y jugar con amigos: respuesta inmediata, sorpresas pequeñas, ver que mejoras y momentos para reírse juntos.
- **Prohibido:**
  - cajas de botín o cualquier cosa que se pague;
  - rachas diarias que obliguen a entrar;
  - temporizadores que dan prisa para comprar;
  - notificaciones fuera del juego;
  - recompensas al azar que sustituyan a la habilidad.

## 2. Reglas técnicas

- **Motor:** Godot 4.7 + GDScript con tipos estáticos. Lee `config/features` de `project.godot` para saber la versión y usa solo APIs de esa versión.
- **Renderer:** Compatibility.
- **Ventana:**
  - resolución base 1280×720: todo el diseño se hace a ese tamaño;
  - ventana de 1920×1080 (`window_width_override` / `window_height_override`), redimensionable;
  - stretch `canvas_items` y aspect `keep`.
- **Assets:** solo los del proyecto, generados por Claude. Cada carpeta tiene un `.md` que explica cómo usarla.
  - `assets/fonts/`: Cinzel y Oswald (licencia OFL). Ver `assets/fonts/LEEME.md`. Si faltan, se usa la fuente por defecto sin errores.
  - `assets/characters/`: sprites de los personajes. Ver `assets/characters/SPRITES.md`.
  - `assets/arenas/`: fondos, mapa (`arenas.json`) y sprites de las trampas. Ver `assets/arenas/ARENAS.md`.
  - `assets/items/`: doblón, cofres e iconos de hechizos. Ver `assets/items/ITEMS.md`.
  - `assets/ui/`: logo, fondos, marcos, emotes, lobby, votación y medallas. Ver `assets/ui/UI.md`.
  - Están exportados **al doble de tamaño**: se dibujan a escala 0,5.
  - Partículas y sonidos se generan por código (`_draw()`, `AudioStreamWAV`).
- **Escenas `.tscn` mínimas:** nodo raíz + script. La UI se construye en código.
- **`core/` es lógica pura:** clases `RefCounted` sin nodos ni autoloads, con la aleatoriedad a partir de una semilla.
  - Contiene la simulación entera de la partida (`match_sim.gd`), la generación de arena, la física, las reglas de combo y robo, las trampas, la tirada de hechizos y el ranking con los premios.
  - Se testea en headless.
- **Autoridad:** el servidor decide todo:
  - doblones, cofres y golpes;
  - hechizos, trampas y la zona;
  - puntos, tiempo y ganador.
  - El cliente solo manda su entrada (mover, dash, hechizo, emotes) y predice su propio movimiento.
- **Textos:** todo texto visible pasa por `I18n.t("clave")` (es, ca, en).
- **Constantes:** todos los números de este archivo van en `core/game_config.gd`, para poder ajustar sin tocar la lógica.
- **Idioma:** código en inglés; textos de usuario y comentarios en castellano.
- **Coste 0 €:** no se activa ningún servicio de pago.

## 3. Estructura

```
res://
  AGENTS.md  CLAUDE.md  README.md
  docs/      DISENO.md  PLAN.md  BITACORA.md  HISTORIA-IA.md  INVESTIGACION.md  DESPLIEGUE.md  codex/  media/
  assets/    fonts/  characters/  arenas/  items/  ui/
  autoload/  net.gd  profile.gd  settings.gd  i18n.gd  sfx.gd  fx.gd
  core/      game_config.gd  match_sim.gd  arena_gen.gd  arena_physics.gd  hazard_rules.gd  scoring.gd  item_table.gd  ranking.gd
  net/       server_main.gd  room.gd  bot_brain.gd  http_endpoint.gd
  scenes/    main/  menu/  lobby/  vote/  loading/  match/  podium/  locker/  settings/  server/
  ui/        theme_builder.gd  widgets/
  tests/     run_tests.gd  test_*.gd
```

`match_sim.gd`, `server_main.gd`, `room.gd`, `scenes/vote/` y `scenes/server/` se crean en la fase 11. Si algún nombre no encaja con lo que ya hay, mantén lo que hay y apúntalo en la bitácora.

## 4. Reglas del juego

### 4.1 Arenas
- **Cuatro arenas** de 1200×600 px, con casillas de 40 px. Todo su contenido está en `assets/arenas/arenas.json`:

  | id | Nombre | Trampas |
  |---|---|---|
  | `cienaga` | Ciénaga Embrujada | Lodo, Raíces |
  | `cripta` | Cripta de Huesos | Pinchos, Fantasma |
  | `taller` | Taller Gnómico | Cintas, Vapor, Barril explosivo |
  | `biblioteca` | Biblioteca Arcana | Portales, Rayo arcano |

- **Elección:** antes de cada partida, **votación** con los 4 mapas, uno en cada esquina de la pantalla. Si hay empate o nadie vota, decide una ruleta (§5.5).
- **Mapa:** obstáculos, trampas y salidas salen de `arenas.json`. El layout es simétrico, así que todas las salidas son igual de justas.
- **Colisión:** cada obstáculo tiene `hitbox` (`[x, y, ancho, alto]`), su huella real en el suelo.
  - Los personajes chocan con `hitbox` usando el círculo de los pies: radio 14 px, centrado 12 px por debajo de su posición.
  - `rect` solo sirve para la rejilla de los bots y para no poner doblones encima.
- **Salidas:** se elige al azar uno de los `spawn_sets` y se reparte al azar entre los jugadores.
- **Doblones y cofres:** van en casillas libres al azar. Nunca en obstáculos ni en trampas fijas; sobre el lodo sí.

### 4.2 Jugador
- **Nombre:** se pide la primera vez que se abre el juego (3-12 caracteres) y se guarda en `Profile.nick`.
- **Saber quién eres:**
  - encima de cada personaje, su nombre;
  - el tuyo, más grande, en tu color y con "TÚ" y una flecha;
  - bajo tus pies, un aro de tu color que late suavemente.
- **Movimiento:** 260 px/s y radio de 22 px para recoger, golpear y separarse de otros jugadores. Choca con los obstáculos (§4.1) y con los bordes.
- **Dash:**
  - Dura 0,18 s a 3× la velocidad normal (unos 140 px) y tiene 1,5 s de espera.
  - Si golpea a un rival, este:
    - suelta el `25 %` de sus doblones (mínimo 3, máximo 12; con la corona, el `35 %`; con el Anillo activo, el `40 %`),
    - queda aturdido 0,4 s,
    - pierde su combo,
    - queda invulnerable 1,5 s (parpadeando).
  - **Choque de dashes:** si dos jugadores chocan los dos en dash, rebotan y nadie suelta nada.
- **Doblones sueltos:** saltan en abanico a una distancia de 60-140 px. La víctima no puede recogerlos durante los primeros 0,6 s.

### 4.3 Doblones y combo
- **Al empezar:** la partida arranca con **30 doblones** repartidos por la arena, a 35 px como mínimo entre ellos y de los obstáculos.
- **Reposición:**
  - si quedan menos de 12, aparece uno cada 1,0 s;
  - en el Frenesí, hasta mantener unos 18.
- **Valor de cada doblón** = multiplicador de combo + 1 si es Frenesí + 1 si llevas el Anillo. **Máximo 5.** Los bonus se suman, nunca se multiplican.
- **Combo:**
  - Sube en +1 por cada doblón recogido con menos de 1,5 s desde el anterior.
  - Se pierde al pasar 1,5 s sin recoger o al recibir un golpe.
- **Multiplicador según el combo:**

  | Combo | Multiplicador | Aviso |
  |---|---|---|
  | 0-4 | x1 | — |
  | 5-11 | x2 | "¡Combo!" |
  | 12 o más | x3 | **"¡VOODOO COMBO!"** |

### 4.4 Cofres y hechizos
- **Cofres:**
  - aparece uno cada 8 s en una casilla libre al azar, con un máximo de 2 a la vez;
  - si no tienes hechizo, al tocarlo se tira una ruleta de 0,8 s y el hechizo resultante se guarda en tu única ranura **sin activarse**;
  - si ya tienes uno, o tienes uno de duración activo, pasas por encima del cofre sin abrirlo.
- **Al guardarlo**, aparece 2 s una tarjeta encima de la ranura: icono, nombre, una frase y "Pulsa E".
- **Lanzar:** el hechizo **solo se lanza con E** (B en el mando).
  - Los instantáneos (alfiler, escarcha, oveja) actúan y la ranura se vacía.
  - Los de duración (imán, botas, anillo, capa) se activan, y un aro alrededor de la ranura se vacía con el tiempo que queda.
- **Hechizos:**

| id | Nombre | Efecto |
|---|---|---|
| `magnet` | Imán de Mithril | Durante 5 s atrae los doblones en un radio de 220 px |
| `boots` | Botas de Montaraz | Durante 4 s: velocidad x1,6 y espera del dash de 0,5 s |
| `cloak` | Capa Élfica | Bloquea el siguiente golpe o hechizo. Dura 8 s como máximo |
| `pin` | Alfiler Vudú | Proyectil a 700 px/s con 900 px de alcance hacia donde miras. Al impactar tiene el mismo efecto que un dash |
| `frost` | Nova de Escarcha | Congela 1,5 s a los rivales en un radio de 180 px |
| `sheep` | Maldición Ovina | Va directa al líder (tarda 0,6 s en llegar). Durante 3 s el líder es una oveja: velocidad x0,6, no recoge y no hace dash |
| `ring` | Anillo de Poder | Durante 6 s cada doblón vale +1. Si te golpean mientras lo llevas, sueltas el 40 % |

- **Capa Élfica bloquea:** dash, alfiler, escarcha, oveja y trampas.
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

### 4.5 Partida (modo VoodooCombo; los otros modos, en §4.9 y §4.10)

**Antes de jugar:** lobby (§5.4) → votación de arena (§5.5) → **pantalla de carga de 15 s**. La pantalla de carga hace de tutorial y enseña:
- la arena con sus trampas y cuánto quitan;
- los controles;
- un consejo que cambia cada 4 s;
- tu personaje con "Eres el Jugador N".

Sin otros humanos, a partir de los 5 s se puede saltar con Espacio.

**Durante la partida:**
- **Inicio:** cuenta atrás 3-2-1-¡YA!.
- **Duración:** 90 s (el anfitrión puede elegir 60, 90 o 120).
- **Corona:** la lleva el líder en cada momento.
- **La zona se cierra (contra el campeo):**
  - **Cuándo:** a los 45, 35 y 25 s del final, la zona segura se encoge un paso. Cada paso quita 2 casillas por lado en horizontal y 1 en vertical, hasta quedar en 18×9 casillas.
  - **Aviso:** 3 s antes, el borde nuevo parpadea en morado y sale "¡LA NIEBLA SE CIERRA!".
  - **Fuera de la zona:**
    - hay niebla, vas a x0,7 de velocidad y pierdes 1 doblón cada 0,75 s;
    - los doblones y los cofres que quedan fuera se desvanecen y reaparecen dentro.
- **Frenesí:** en los últimos 15 s.

**Final:**
- **Ganador:** quien tenga más doblones. En caso de empate, gana quien tenga el combo máximo más alto.
- **Podio:** 1º en el centro, 2º a la izquierda y 3º a la derecha, con los personajes celebrando; el 4º, en el suelo.
  - Cada placa lleva solo el nombre y la puntuación. Nada de listas, monedas ganadas ni XP.
  - Todos pueden lanzar emotes con 1-4.
- **Premios** (se calculan en `ranking.gd`; si se puede, cada jugador recibe uno):

| Premio | Para quién |
|---|---|
| Rey del Combo | Combo máximo más alto |
| Manos Largas | Más doblones robados |
| Bala Perdida | Más dashes acertados |
| Oveja Oficial | Más veces convertido en oveja |
| Intocable | Menos golpes recibidos |

- **¡OTRA!:** vuelve al lobby de la misma sala, con todos "no listos". **MENÚ PRINCIPAL** sale. Si nadie pulsa nada en 15 s, vuelve solo al menú.
- **Medallas:** también salen debajo de cada placa del podio (§4.11).
- **Niveles:** la XP se gana por partida y por los retos (§4.11). En el podio se ve una barra que se llena. Cada nivel desbloquea un cosmético (marcos, estelas del dash, emotes, bailes y gritos; tabla en `docs/codex/fase-10-arreglos.md` 10l y fase 11). Los cosméticos se equipan en la **TAQUILLA**.

### 4.6 Modos (los elige el anfitrión en el lobby)

| | VoodooCombo (por defecto) | Último en Pie | Codicia 2v2 |
|---|---|---|---|
| Objetivo | Más doblones a los 90 s (60/90/120 a elegir) | Ser el último con costuras; al mejor de 3 rondas | Más doblones guardados en el cofre del equipo a los 90 s |
| Doblones | 30 al empezar; reaparecen | No hay | 40 al empezar; reaparecen |
| Combo | Multiplicador x1–x3 | No | No |
| Frenesí | Últimos 15 s | No | Últimos 15 s: cada doblón vale 2 |
| La zona se cierra | A los 45, 35 y 25 s | Un paso cada 15 s, hasta 10×5 casillas | No |
| Hechizos | Los 7 | Los 7; el Anillo pasa a ser Costura Extra | Los 7 |

- **Al cambiar de modo en el lobby:** sale una tarjeta con 3 líneas de reglas.
- **En la pantalla de carga:** se enseñan las reglas del modo.
- **Al empezar cada partida o ronda:** un cartel de 2 s con el objetivo.

### 4.7 Bots
- **Para qué:** jugar contra bots y rellenar huecos de una sala.
- **Dónde corren:** dentro de `MatchSim`, en el servidor (o en local contra bots), como jugadores normales.
- **Nombres:** del juego, como "Mordisquitos", "Conde Costura" o "Dama del Pantano".
- **Comportamiento:**
  - Van hacia el doblón o cofre más cercano, siempre dentro de la zona.
  - Si tienen un rival a menos de 120 px y el dash listo, hacen dash el 30 % de las veces.
  - Guardan el hechizo y lo lanzan cuando les sirve.
  - Votan arena al azar en los primeros 3 s y lanzan algún emote en el lobby y el podio.
  - En Último en Pie y Codicia 2v2 siguen su propia lógica (§4.9 y §4.10).

### 4.8 Trampas de arena

| Trampa | Efecto al activarse |
|---|---|
| Lodo | Velocidad ×0,6 dentro de la elipse. |
| Raíces | Aviso 0,7 s; atrapan 1 s a ≤36 px. |
| Pinchos | 2 s abajo, 0,6 s de aviso y 1 s arriba. Arriba hacen daño. |
| Fantasma | Recorre su ruta a 120 px/s; al tocar aturde 0,6 s. Ignora al jugador afectado 2 s. |
| Cinta | Empuja jugadores y doblones a 140 px/s en su dirección `dir`. |
| Vapor | Periodo de 4 s: aviso 0,6 s y chorro 0,5 s; a ≤70 px empuja 90 px y aturde 0,3 s. |
| Barril | Un dash inicia una mecha de 0,8 s; explota a ≤110 px y empuja 90 px. Reaparece a los 15 s. |
| Portal | Teletransporta a la pareja y añade 30 px en la dirección de movimiento; espera de 1 s por jugador. |
| Rayo | Dos brazos de 280 px salen del centro del orbe y giran cada 8 s; tocar a ≤32 px hace daño. |

- **Daño de trampa** (raíces, pinchos, fantasma, vapor, barril y rayo): quita **el 15 % de tus doblones, con un mínimo de 2 y un máximo de 10** (si tienes menos de 2, los que tengas).
  - Los doblones saltan en abanico como en un golpe.
  - Todo pasa por la misma `apply_hit(...)`.
- **Capa Élfica:** bloquea el daño de las trampas.
- **Avisos:** toda trampa periódica anuncia antes de hacer daño.
- **Bots:** esquivan los pinchos levantados y el rayo, y usan los portales si les acercan a un doblón.

### 4.9 Modo Último en Pie
- **Costuras:** cada jugador tiene 3 (`assets/ui/costuras.png`). Se ven en su ficha y, en pequeño, sobre su cabeza.
- **Pierdes una costura con:** el dash de un rival, el alfiler o una trampa que hace daño. Después tienes 1,5 s de invulnerabilidad.
- **Sin costuras:** te descoses y pasas a ser un **fantasmita**. Vas a x0,6, no colisionas, no haces nada a nadie y puedes usar emotes.
- **Hechizos:**
  - cofres cada 5 s (máximo 2);
  - la Oveja va contra quien tenga más costuras;
  - el Anillo se cambia por **Costura Extra** (+1, máximo 3).
- **Zona:** fuera de ella pierdes una costura cada 3 s.
- **Rondas:**
  - al mejor de 3, con 90 s como máximo cada una;
  - si se acaba el tiempo, gana quien tenga más costuras; si hay empate, muerte súbita con la zona al mínimo;
  - entre rondas, cartel "RONDA N" de 4 s, otra arena al azar y todos con 3 costuras otra vez.
- **Podio:** por rondas ganadas; si hay empate, por las costuras de la última ronda.
- **Bots:** van a por el rival más cercano que no sea invulnerable (o al cofre si no tienen hechizo) y huyen cuando les queda 1 costura.

### 4.10 Modo Codicia 2v2
- **Equipos:**
  - estrados 1-2 del lobby = equipo **coral**, y 3-4 = equipo **azul**;
  - el anfitrión puede cambiar a alguien de equipo y los huecos se rellenan con bots;
  - cada jugador usa el color de su equipo y su forma de siempre.
- **Cofres de equipo:**
  - `assets/items/cofre_equipo_coral.png` y `cofre_equipo_azul.png`;
  - en `GameConfig.TEAM_BASES`: coral en (80, 300) y azul en (1120, 300);
  - zona de entrega de radio 56 px.
- **Llevar doblones:** lo que coges va encima, en una pila sobre la cabeza. Cada doblón te frena un 2 % (máximo 40 %) y te agranda un 1 % (máximo 20 %).
- **Guardar:** al entrar en tu zona, los doblones vuelan uno a uno al cofre y ya están a salvo.
- **Golpes:**
  - el dash de un rival o una trampa te hacen soltar **todo lo que llevas**;
  - lo que está en el cofre no se pierde;
  - entre compañeros no hay golpes.
- **Doblones:** si quedan menos de 20, aparece uno cada 0,8 s. Cada doblón vale 1 (2 en el Frenesí).
- **Hechizos:** la Oveja va contra el rival que más lleva encima.
- **Marcador:** los dos cofres con su total arriba, uno a cada lado del tiempo. Las fichas individuales enseñan lo que lleva encima cada jugador.
- **Bots:**
  - llevan entre 6 y 10 doblones y vuelven a guardar;
  - persiguen al rival más cargado si está a menos de 160 px;
  - protegen al compañero cuando lleva mucho.

### 4.11 Medallas y retos
- **Medallas en plena partida** (`assets/ui/medallas.png`). Salen 1,5 s junto a la ficha del jugador, con sonido, y las ven todos:

  | Medalla | Cuándo |
  |---|---|
  | Primera sangre | El primer golpe de la partida |
  | Venganza | Golpeas a quien te golpeó en los 5 s anteriores |
  | Remontada | Pasas de último a primero |
  | Robo maestro | Robas 8 o más doblones de un golpe |
  | Racha | 3 golpes seguidos sin que te den |
  | Por los pelos | Una trampa o un dash te pasa a menos de 10 px y no te da |
  | Intocable | 30 s sin recibir ningún golpe |
  | Rey del combo | Llegas a x3 dos veces en la misma partida |

  Las decide el servidor y se guardan en el perfil (HISTORIAL).
- **Retos de partida:**
  - 3 por partida, que se ven en la pantalla de carga (por ejemplo, "Roba 6 doblones");
  - dan XP extra;
  - se renuevan cada partida, **nunca cada día**.

## 5. Red (tiempo real)

Plan completo del equipo: `docs/codex/plan-multijugador.md`. Guía para desplegar el servidor: `docs/DESPLIEGUE.md`.

### 5.1 Servidor dedicado
- **Transporte:** `ENetMultiplayerPeer` por UDP, puerto **7777**.
- **Arranque:**
  - `godot --headless --path . -- --server --port 7777`;
  - carga `scenes/server/server.tscn`, sin menús, HUD, audio ni texturas.
- **Un proceso, varias salas:**
  - `MAX_PEERS = 32` (8 salas de 4);
  - cada sala con su propia `MatchSim` a **30 Hz**.
- **Dónde corre:** Oracle Cloud Always Free para jugar desde casa y, de respaldo, un PC de clase en la red local.
- **En AJUSTES → "Servidor":** Oracle (`GameConfig.ONLINE_HOST`), Red local (IP a mano) o Este PC (`127.0.0.1`).
- **Contra bots:** la misma `MatchSim` en local, sin red.
- **Solo hay una fuente de verdad de la red:** el autoload `Net`. Todas las RPC viven ahí, para que la ruta `/root/Net` sea igual en todos los peers.

### 5.2 Salas con código
- **Código:** 5 caracteres de `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, único entre las salas abiertas.
- **RPC del cliente:** `create_room(...)`, `join_room(code, ...)`, `leave_room()`.
  - El servidor responde `room_joined(code, room_state)` o `room_error(reason)`.
  - El servidor identifica siempre al jugador con `get_remote_sender_id()`.
- **Reglas:**
  - máximo 4 humanos;
  - con la partida empezada no entra nadie;
  - las salas vacías se cierran a los 5 min;
  - máximo 5 intentos de código por minuto;
  - si la versión del juego no coincide, error.
- **Anfitrión:** elige el modo y la duración, añade bots y cambia de equipo. Si se va, pasa a serlo el siguiente que llegó.
- **Colores:** cada jugador tiene un color y una forma únicos según su orden de llegada (Jugador 1-4).

### 5.3 Partida en red
- **El cliente manda:**
  - `submit_input(seq, move, dash, spell)` 30 veces por segundo, `unreliable_ordered`;
  - dash y hechizo, también como intención `reliable`.
- **El servidor:**
  - valida la entrada (`move` de longitud ≤ 1, como mucho 40 entradas por segundo, jugador en la sala);
  - simula;
  - manda un `snapshot` a 20 Hz (`unreliable_ordered`);
  - manda los eventos de la partida como `reliable`: `coin_taken`, `player_hit`, `item_rolled`, `item_used`, `hazard_event`, `zone_step`, `match_over`…
- **Predicción:** tu personaje se mueve al momento en tu pantalla. Si el servidor dice otra cosa:
  - menos de 8 px, no se toca;
  - entre 8 y 64 px, se corrige poco a poco;
  - más de 64 px, salta.
- **Interpolación:** los demás jugadores se interpolan con 100 ms de retraso.
- **Trampas periódicas:** se calculan con el reloj de partida del snapshot, así que se ven igual en todos.
- **Datos:** en las RPC solo se mandan tipos simples. Los doblones son datos (`id`, `pos`, `value`), no nodos sincronizados.
- **Desconexión:**
  - si se cae un jugador, "puff" y la partida sigue; si queda un humano, gana;
  - si se cae el servidor, aviso y vuelta al menú.
- **Ping:** indicador pequeño arriba a la derecha.
- **Al acabar:**
  - el servidor guarda la partida en `user://matches/<fecha>.json`;
  - el endpoint HTTP (puerto 8080, `Access-Control-Allow-Origin: *`) atiende:
    - `GET /status`: partida en curso;
    - `GET /results`: últimas partidas con ganador, ranking y premios;
    - `GET /`: página HTML mínima con el marcador en directo, para la presentación.
- **Por qué este protocolo (para la documentación):** ENet manda mensajes asíncronos sobre UDP.
  - La entrada y las posiciones van por un canal no fiable: si se pierde un paquete, el siguiente ya lo corrige.
  - Los eventos importantes (doblones, golpes, ganador) van por un canal fiable.

### 5.4 Lobby de mazmorra
- **Entrada:** JUGAR → **CREAR SALA** · **UNIRSE CON CÓDIGO** · **CONTRA BOTS**.
- **Fondo:** `assets/ui/lobby_mazmorra.png`, con antorchas, niebla, araña y polvo animados en código. Con "Reducir movimiento", todo quieto.
- **Estrados:** 4 de piedra.
  - Tú siempre en el segundo.
  - Cada jugador con su placa (nombre y LISTO).
  - El anfitrión, con la corona.
  - Los huecos libres, con "+ INVITAR" y, para el anfitrión, AÑADIR BOT.
- **Arriba:** código de sala con COPIAR, y el modo.
- **Abajo:** TAQUILLA · ¡LISTO! · BAILES · SALIR.
- **Rueda (Q / Y) con 8 huecos:** emotes, bailes (Meneíto, Trompo, Saltito Vudú, Carcajada) y gritos de guerra propios del juego.
  - Las teclas 1-4 lanzan los cuatro primeros.
  - Uno cada 1 s; el servidor descarta el resto.
  - Lo ven todos.
- **Contenido original:** nada de nombres, frases ni logos de otros juegos o libros.

### 5.5 Votación de arena
- **Pantalla:** partida en 4 cuadrantes, un mapa en cada esquina (en sentido horario: Ciénaga, Cripta, Taller, Biblioteca).
  - Cada cuadrante tiene su vista grande, el nombre, la premisa, los iconos de trampas y los retratos de quien lo ha votado.
  - En el centro, un medallón con "¡VOTAD!" y la cuenta atrás.
- **Votar:** 10 s, con flechas o stick y confirmando con Espacio o A. Se puede cambiar el voto hasta el final, y se acaba antes si votan todos.
- **Empate o sin votos:** ruleta en sentido horario por los empatados.
  - Empieza rápido y frena en unos 3,5 s.
  - El ganador brilla con fanfarria y los demás se oscurecen.
- **El servidor** decide la ruleta con la semilla y manda la lista de saltos, para que todos vean la misma animación.

## 6. Feedback obligatorio

Cada acción tiene respuesta visual y sonora en menos de 100 ms. Todo pasa por los autoloads `Fx` y `Sfx` y respeta el ajuste "Reducir movimiento".

| Evento | Qué tiene que pasar |
|---|---|
| Recoger | "+N" que salta (§7), 6 chispas, el personaje se aplasta un poco y un *cling* que sube un semitono por cada paso de combo (hasta 12). Un doblón pequeño vuela en arco a tu ficha, y el número sube contando y hace *pop* |
| Combo | Anillo junto al personaje que se vacía en 1,5 s (hueso en x2, brasa en x3). Al perderlo, se rompe con un *pff* suave; si era de 10 o más, sale "¡Combo de N!" en gris |
| Subir de multiplicador | El número tiembla y pasa de hueso a brasa, aparece el aviso y suena un acorde que sube |
| "¡VOODOO COMBO!" | Cartel grande, golpe de cámara (+4 %), flash corto (si se permiten) y chispas por el borde 1 s; aura de brasa en el personaje |
| Dash | Aplastamiento, estela del color del jugador (o la equipada), polvo y *whoosh* |
| Golpe | Parón (*hitstop*) de 60 ms (90 ms si quitas 5 o más), sacudida de 6 px, doblones en abanico, "-N" en rojo, *boing* y vibración del mando |
| Robo | Los doblones vuelan de la ficha del otro a la tuya y sale "¡ROBO!" en brasa |
| Medalla | Icono de 1,5 s junto a la ficha, con sonido |
| Ruleta del cofre | 0,8 s de iconos girando sobre el muñeco con *tic* y un *ding* final |
| Hechizo guardado | Tarjeta de 2 s sobre la ranura y la ranura empieza a latir |
| La niebla se cierra | Borde morado parpadeando, aviso sonoro y "¡LA NIEBLA SE CIERRA!" |
| Frenesí | Cartel "¡FRENESÍ!", borde de brasa latiendo, lluvia de doblones y música un 25 % más rápida y un tono más alta |
| Final ajustado | Si en los últimos 5 s el primero y el segundo están a 3 o menos: cámara lenta x0,7, latido de corazón y sus fichas parpadeando |
| Últimos 5 s | Números gigantes en el centro, con un tambor en cada uno |
| Final | Cámara lenta de 0,5 s, zoom al ganador y confeti de doblones. Medio segundo de silencio, fanfarria y el podio |
| Subir de nivel | La barra explota en chispas. Si se desbloquea algo, una caja de la taquilla (ganada jugando, nunca comprada) se abre y lo enseña |

- **Música por capas** (entran y salen en 0,5 s):

  | Situación | Capas |
  |---|---|
  | Base | Tambor y bajo |
  | Combo x2 o más | + Percusión rápida |
  | Combo x3 | + Melodía |
  | Últimos 10 s | + Tambor grave en cada segundo |

- **Menús:**
  - los botones se agrandan al pasar por encima y se aplastan al pulsar, con sonido;
  - las pantallas cambian con un telón de tela de 0,35 s;
  - el cursor es un alfiler vudú;
  - el logo late cada 4 s.
- **Números:** todos los números del *juice* van en `GameConfig`, en un bloque `# Juice`.

**Sonido:** todo sintetizado en código como `AudioStreamWAV`, más un bucle de tambores y bajo.

## 7. Identidad visual (fantasía oscura)

- **Regla general:** fondo casi negro con niebla y velas.
  - En la interfaz, poco dorado y nada de marrón: hueso y una sola brasa naranja.
  - Solo lo importante va saturado: personajes, doblones y trampas avisando.
- **Paleta:**

  | Uso | Color |
  |---|---|
  | Fondo | `#0B0710` |
  | Texto principal (hueso) | `#EFE7DA` |
  | Acento (brasa) | `#FF6A2B` |
  | Perder | `#FF3B3B` |
  | Escarcha | `#7FE7FF` |
  | Almas y niebla de la zona | `#B06BFF` |
  | Doblón | `#FFD23F`, con brillo `#FFF6C2` |
  | Texto secundario | `#B8A9D1` |
  | Paneles del HUD | `#241838` |

- **Jugadores:** J1 coral `#D8484F` ● · J2 azul `#3C7FD0` ▲ · J3 lima `#63A83A` ■ · J4 hueso `#D9D0BE` ◆.
  - Los sprites ya vienen en cada color.
  - La forma (● ▲ ■ ◆) la dibuja el juego bajo el personaje y junto al nombre.
- **Personajes** (sprites de `assets/characters/`). Son cosméticos: muñecos vudú de arpillera con aspecto de fantasía.

  | Personaje | Aspecto |
  |---|---|
  | Brasa | Mago del fuego |
  | Colmillo | Trol del pantano |
  | Tuerca | Gnomo inventor |
  | Cripta | Nigromante |

  - Animaciones: idle, walk, dash, hurt y win.
- **Estilo de letra: "Brasa minimal".** Plano, sin degradados ni biseles: el impacto lo dan el movimiento y una sola brasa de acento.
  - **Cinzel Bold**, espaciada (+12 % entre letras; +22 % en botones):
    - para logo, títulos, botones del menú, carteles ("¡FRENESÍ!", "¡VOODOO COMBO!"), nombres de arena y gritos de guerra;
    - en hueso; lo que tiene que destacar, en brasa con un resplandor suave.
  - **Oswald Bold**, plana y con contorno oscuro `#0B0710` de 6-8 px: todo lo que salta en la partida ("+N", "-N", "¡ROBO!", "x3", "¡ZAS!"), los números del marcador y el tiempo.
  - **Oswald Medium:** el resto del texto, incluidos los nombres sobre los personajes. Mínimo 18 px.
  - **Colores del texto en partida:**

    | Texto | Color |
    |---|---|
    | "+1" | Hueso `#EFE7DA` |
    | "+N" con bonus, "¡ROBO!", "x2"/"x3" | Brasa `#FF6A2B` |
    | "-N" (perder doblones) | Rojo `#FF3B3B` |
    | "¡ZAS!" y escarcha | Cian `#7FE7FF` |
    | "-1" por la niebla | Morado `#B06BFF` |

  - **Duración:** "+N" 1,2 s y avisos 1,6 s. Entran con *pop*, suben y se desvanecen solo al final.
- **Logo:** `assets/ui/logo_brasa.png`.
- **Botones del menú:** solo texto, sin caja. El que tiene el foco va en brasa, con un punto a la izquierda y una línea fina debajo.
- **HUD:** solo 3 elementos fijos.
  1. **Fichas de los jugadores:** retrato con su marco, nombre del jugador, "J1 · TÚ", puntuación y la corona en el líder.
  2. **Tiempo:** en grande arriba, en el centro.
  3. **Ranura del hechizo:** abajo a la izquierda, 80×80 px, nunca cortada por el borde. Muestra la tecla (E o B) y el nombre del hechizo.
  - Paneles `#241838` con borde de costura.
- **Ambiente:** encima de la arena, niebla que se mueve despacio, velas que parpadean y viñeta oscura.

## 8. Accesibilidad

- **Controles:**

  | Acción | Teclado | Mando |
  |---|---|---|
  | Mover | WASD o flechas | Stick izquierdo |
  | Dash | Espacio o Shift | A |
  | Hechizo | E | B |
  | Rueda de emotes (lobby) | Mantener Q | Y |
  | Emotes rápidos (lobby y podio) | 1-4 | Cruceta |
  | Pantalla completa | F11 | — |
  | Pausa / menú | Esc | Start |

- **Menús:** se usan del todo con teclado y mando, con foco visible.
- **Nunca solo color:** formas ● ▲ ■ ◆ e iconos.
- **Ajustes:**
  - reducir movimiento y reducir destellos;
  - vibración del mando;
  - escala de UI 100/125/150 %;
  - pantalla (ventana o pantalla completa) y tamaño de ventana;
  - volumen de música y de efectos;
  - idioma;
  - servidor.

## 9. Cómo trabajar

- **Una fase cada vez:** trabaja solo en la fase que se pide. Hay un commit por bloque (`Fase 12a: <resumen>`).
- **Antes de programar:** resume en 3-5 líneas qué vas a hacer.
- **Tests:** si hay Godot en el PATH como `godot`, ejecuta `godot --headless --path . --script res://tests/run_tests.gd` y arregla lo que falle. Si no está, dilo.
- **Al terminar cada bloque:**
  1. Añade una entrada en `docs/BITACORA.md` (sección "Registro de Codex") con qué has hecho, las decisiones, los problemas y **qué tienen que probar los humanos**. No inventes problemas que no hayan pasado.
  2. Haz commit.
- **Si algo es ambiguo,** pregunta en vez de inventar.
