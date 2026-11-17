# Fase 11 — Letra nueva, online y lobby

> **Para Codex.** Antes de empezar:
> 1. La fase 10 (`docs/codex/fase-10-arreglos.md`) tiene que estar terminada.
> 2. **Copia `docs/codex/fase-11/AGENTS.md` a la raíz como `AGENTS.md`.** Es la versión que describe cómo queda el juego al acabar esta fase. Si tu `AGENTS.md` ya la tiene, no hace falta.
> 3. Lee `docs/codex/plan-multijugador.md`, el plan del equipo: es la base del online y sus reglas de seguridad y coste valen tal cual.
>
> **Qué entra en esta fase:**
> - **11a** · Letra y color "Brasa minimal" (fuentes, logo, menú y textos de partida).
> - **11b-11j** · Online con servidor dedicado, salas con código, lobby de mazmorra, votación de arena con ruleta, partida en red, desconexiones, despliegue y seguridad.
>
> **Qué NO entra:** la dopamina extra (*game feel*, medallas, música por capas…), quitar el Clásico y los modos nuevos. Todo eso es la fase 12. **En esta fase no toques el modo Clásico.**
>
> Referencias visuales en `docs/media/`:
> - `menu_brasa_referencia.png` y `textos_partida_referencia.png`: letra y color;
> - `lobby_mazmorra_referencia.png`: lobby;
> - `votacion_esquinas_referencia.png`: votación de arena.
>
> En VoodooCombo no hay vida ni disparos: hay doblones, dash, hechizos y trampas.

## Decisiones del equipo (online)

- **Servidor dedicado y autoritativo**, con Godot sin pantalla (*headless*) y `ENetMultiplayerPeer` por UDP.
  - Un solo proceso de servidor que lleva **varias salas** a la vez.
  - El cliente nunca decide doblones, golpes, puntos ni ganador.
- **Dónde corre:**
  - **Oracle Cloud Always Free**, para jugar desde casa.
  - **De respaldo, un PC de clase** con el mismo ejecutable de servidor en la red local, por si falla internet.
- **Cómo se entra:** solo con **código de sala**, de 5 letras. Sin partida rápida pública.
- **La arena se vota** entre los 4 jugadores; si hay empate, ruleta.
- **Puerto:** UDP **7777**, el que ya usa `autoload/net.gd` (el 2456 del plan era un ejemplo).
- **Jugadores:** de 2 a 4 por sala. El anfitrión puede rellenar los huecos con bots.
- **Coste 0 €:** no se activa nada de pago. Si una cuota gratuita no llega, se para y se avisa.

## Hito 0 · Lo que hay ahora (revisado por Claude)

- Godot **4.7**, GDScript, renderizador Compatibility.
- **Todo pasa en `scenes/main/main.gd`** (unas 1360 líneas): estado de la partida, simulación, dibujo, HUD y menús juntos. Los jugadores son diccionarios en `players`, y los doblones y cofres son arrays.
- **Lógica reutilizable** que ya está separada en `core/`:
  - `arena_gen.gd`, `arena_physics.gd`, `hazard_rules.gd`, `scoring.gd`, `item_table.gd`, `ranking.gd`;
  - y `net/bot_brain.gd`.
- **`autoload/net.gd`** ya tiene ENet (puerto 7777), `request_join`, `ready`, posiciones y acciones. Pero crea el servidor dentro del juego del anfitrión, y el movimiento lo decide el cliente.
- **Riesgo principal:** sin separar la simulación del dibujo no se puede tener un servidor sin pantalla. Es lo primero que hay que hacer en el online (11b).

## Cómo trabajar esta fase

- Son 10 bloques (**11a-11j**). Hazlos en orden y con **un commit por bloque** (`Fase 11a: <resumen>`).
- **11a** cambia la letra y el logo. **11b-11j** son el online y el lobby; el riesgo principal está en 11b.
- **No cambies las reglas del juego** para meter la red: la partida contra bots tiene que jugarse igual que antes.
- Comprueba las APIs contra la documentación de Godot 4.7: `ENetMultiplayerPeer`, `@rpc`, `multiplayer.get_remote_sender_id()`, etc.
- Después de cada bloque, apunta en la bitácora qué archivos has tocado, cómo se prueba y qué se tiene que ver.

---

## 11a · Letra y color: "Brasa minimal"

Lo decidió el equipo: ni dorado ni marrón, nada de letras "de plástico". Plano y minimalista, con una sola brasa de acento. **La dopamina la pone el movimiento, no la textura.** Referencias: `docs/media/menu_brasa_referencia.png` y `docs/media/textos_partida_referencia.png`. Ya está en `AGENTS.md` §7. Va primero porque el lobby y la votación de esta fase ya usan esta letra.

- **Fuentes nuevas** en `assets/fonts/`: `Cinzel-Bold.woff2`, `Cinzel-Regular.woff2`, `Oswald-Bold.woff2` y `Oswald-Medium.woff2`, con su licencia OFL.
  - Cambia New Rocker por Cinzel Bold, Lilita One por Oswald Bold y Baloo 2 por Oswald Medium en todo el juego: `ui/theme_builder.gd`, `_draw()`, HUD, menús y podio.
  - Cuando no quede nada que las use, borra las fuentes viejas y sus `.import`.
- **Títulos y menú** (Cinzel Bold):
  - espaciado entre letras +12 % (en botones +22 %), con `FontVariation.spacing_glyph`;
  - hueso `#EFE7DA`; lo destacado, en brasa `#FF6A2B` con resplandor (el contorno de `Label` a baja opacidad, o un shader de *glow* sencillo).
- **Logo:** `assets/ui/logo_brasa.png` sustituye a `logo.png`.
- **Botones del menú, minimalistas:**
  - solo texto, sin caja;
  - el que tiene el foco: en brasa, con un punto de brasa a la izquierda, una línea fina debajo y unas brasas pequeñas subiendo.
  - Los paneles 9-slice se quedan solo para el HUD y las tarjetas.
- **Texto en partida** (Oswald Bold, plano, contorno de 6-8 px `#0B0710`):

  | Texto | Color |
  |---|---|
  | "+1" | Hueso |
  | "+N" con bonus, "¡ROBO!", "x2"/"x3" | Brasa |
  | "-N" | Rojo `#FF3B3B` |
  | "¡ZAS!" y la escarcha | Cian |

- **Los textos se mueven** (todo con *tweens*, respetando "Reducir movimiento"; la fase 12 añade más efectos):
  - **"+N":** entra a escala 1,8 → 1 con rebote (0,15 s), sube 50 px, y en los últimos 0,25 s se encoge y se desvanece. Si vale más de 1, además gira ±6° al entrar.
  - **"-N":** tiembla 3 px a los lados durante 0,2 s y cae un poco en vez de subir.
  - **Carteles grandes** ("¡VOODOO COMBO!", "¡FRENESÍ!"): entran desde escala 2,4 con rebote, laten 2 veces y salen hacia arriba. Detrás, una línea de brasa que se dibuja de izquierda a derecha.
  - **Marcador:** al subir, el número cuenta hacia arriba y hace *pop*; al bajar, se pone rojo un momento y tiembla.

---

## 11b · Separar la simulación (`MatchSim`)

- Crea `core/match_sim.gd` (`RefCounted`, sin nodos ni autoloads) con **todo el estado y las reglas de la partida**:
  - jugadores, doblones, cofres, hechizos, trampas, zona que se cierra, combo, golpes, tiempo y resultado;
  - lo que ahora está en `main.gd`.
- Interfaz:
  - `setup(config)`: semilla, arena, modo, jugadores y bots.
  - `step(dt, inputs)`: `inputs` = por jugador `{move: Vector2, dash: bool, spell: bool}`.
  - `snapshot()`: estado mínimo para dibujar.
  - `pop_events()`: lista de eventos (`coin_taken`, `player_hit`, `item_rolled`, `item_used`, `hazard_event`, `zone_step`, `match_over`…).
- `main.gd` pasa a ser **solo la vista**: lee la entrada, se la da a la simulación, dibuja `snapshot()` y convierte los eventos en efectos y sonidos.
- La partida contra bots usa la misma `MatchSim` en local, sin red.
- **Tests en headless:** 90 s simulados con 4 bots y una semilla fija acaban siempre con el mismo resultado.

## 11c · Servidor dedicado

- Si el juego arranca con `--server`, carga `scenes/server/server.tscn`: sin menús, HUD, audio ni texturas.
- Se lanza con: `godot --headless --path . -- --server --port 7777`.
- `net/server_main.gd`:
  - crea el `ENetMultiplayerPeer` con `create_server(PORT, MAX_PEERS)`, con `MAX_PEERS = 32` (8 salas de 4);
  - ejecuta las `MatchSim` de las salas activas a **30 Hz**.
- **Solo hay una fuente de verdad de la red:** el autoload `Net`. No crees otro autoload que también gestione la conexión.
- Logs en la consola de conexión, desconexión, sala creada o cerrada y fin de partida, con fecha y hora.
- **Prueba:** servidor y dos clientes en el mismo PC conectados a `127.0.0.1`.

## 11d · Salas con código

- RPC del cliente al servidor (siempre con `get_remote_sender_id()`, nunca con un id que mande el cliente):
  - `create_room(nick, character, cosmetics, version)` → el servidor responde `room_joined(code, room_state)`;
  - `join_room(code, nick, character, cosmetics, version)` → `room_joined(...)` o `room_error(reason)`;
  - `leave_room()`.
- **Código:** 5 caracteres al azar del alfabeto `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (sin O/0 ni I/1), único entre las salas abiertas.
- **Reglas:**
  - máximo 4 humanos por sala;
  - una vez empezada la partida, no entra nadie más;
  - las salas vacías se cierran a los 5 min;
  - máximo 5 intentos de código por cliente y minuto;
  - si la versión del juego no coincide, `room_error("version")`.
- El servidor manda a todos los de la sala `room_state` cada vez que algo cambia: jugadores, listo o no, personaje, cosméticos, anfitrión, modo, arena y bots.
- Si el anfitrión se va, el siguiente que llegó pasa a serlo.
- **Prueba:** 4 clientes en la misma sala; el quinto recibe "Sala llena".

## 11e · Lobby de mazmorra

Tiene que quedar como `docs/media/lobby_mazmorra_referencia.png`, con el fondo `assets/ui/lobby_mazmorra.png`.

**Ambiente:** una mazmorra de fantasía oscura, con muro de piedra, arcos con ojos brillando en la oscuridad, estandartes con runas, antorchas, cadenas, calaveras, telarañas y una araña colgando. Todo eso ya viene dibujado en el fondo; por encima, en código:
- las antorchas parpadean (un brillo naranja que sube y baja);
- la niebla se mueve despacio;
- la araña baja y sube cada 8-12 s;
- de vez en cuando cae polvo del techo.
- Con "Reducir movimiento", todo quieto.

**Entrar al online:** en el menú, JUGAR abre **JUGAR ONLINE**, con tres opciones:
- **CREAR SALA**;
- **UNIRSE CON CÓDIGO** (campo de 5 letras);
- **CONTRA BOTS**: como ahora, sin red, pero con el mismo lobby y los huecos rellenos de bots.

**Escenario:**
- 4 estrados de piedra con runas, en x = 420, 780, 1140 y 1500 (en 1920×1080).
- **Tú siempre en el segundo**, un poco más grande. Los demás, en el orden en que llegaron.
- Cada personaje en `idle`, con su marco y una placa con su nombre y **LISTO** en verde o "…".
- El anfitrión, con la corona.
- **Huecos libres:** silueta con "+ INVITAR". El anfitrión ve además **AÑADIR BOT**.

**Arriba:**
- a la izquierda, el **código de sala** en grande y **COPIAR** (`DisplayServer.clipboard_set`);
- a la derecha, el **MODO** con flechas ‹ ›, que solo cambia el anfitrión.
- La arena no se elige aquí: se vota (11f).

**Abajo:** **TAQUILLA** · **¡LISTO!** (grande) · **BAILES** · **SALIR**.

### Emotes, bailes y gritos (para echarse unas risas)

Un menú en rueda (mantener **Q** o el botón Y del mando) con 8 huecos que se configuran en la TAQUILLA: emotes, bailes y gritos. Las teclas 1-4 lanzan los cuatro primeros directamente. Todo lo ven los demás jugadores.

- **Emotes:** `emotes.png` (8) y `emotes2.png` (8 más): dado de 20, jarra de hidromiel, rana, "Zzz", "¿?", "JA JA", pollito ("¡gallina!") y grito con hacha. El bocadillo dura 2 s.
- **Bailes:** hechos en código sobre el sprite (escala, giro, saltos y `flip_h`), en bucle hasta que te mueves o lanzas otra cosa. Con notas musicales ♪ flotando y un ritmo sintetizado. Los cuatro bailes:

  | Baile | Movimiento |
  |---|---|
  | Meneíto | Balanceo de ±15° a 4 Hz con botecitos |
  | Trompo | Se voltea cada 0,12 s mientras da saltitos |
  | Saltito Vudú | Saltos grandes, aplastándose al caer y estirándose al subir |
  | Carcajada | Tiembla de risa con la animación `win` y suelta el emote "JA JA" |

- **Gritos de guerra:** un cartel grande sobre tu personaje durante 2 s (Cinzel Bold espaciada, en brasa `#FF6A2B` con resplandor) y un sonido de cuerno o tambor. Frases **propias del juego**, sin copiar las de otros juegos o libros:
  - "¡A LA CARGA, CAMARADA!"
  - "¡SANGRE Y DOBLONES!"
  - "¡POR EL VUDÚ!"
  - "¡QUE TIEMBLE LA MAZMORRA!"
  - "¡HOY CENAMOS ORO!"
  - "¡NADIE TOCA MIS DOBLONES!"
- **Desbloqueos:** al principio, 4 emotes, 1 baile y 2 gritos. El resto se desbloquea con los niveles (amplía la tabla de la fase 10l).
- **Límite:** uno cada 1 s por jugador; el servidor descarta el resto.

### Empezar

Cuando todos los humanos están listos y hay al menos 2 jugadores (contando bots): **votación de arena** (11f) → pantalla de carga de 15 s (fase 10), todos a la vez.

Se usa entero con teclado y mando.

## 11f · Votación de arena: 4 mapas en las esquinas y ruleta

Tiene que quedar como `docs/media/votacion_esquinas_referencia.png`.

**Pantalla:** la pantalla se parte en 4 cuadrantes grandes, **un mapa en cada esquina**, en sentido horario: arriba a la izquierda la Ciénaga, arriba a la derecha la Cripta, abajo a la derecha el Taller y abajo a la izquierda la Biblioteca.
- **Posiciones:** en `assets/ui/fase12.json` → `votacion.quads_1920`, en 1920×1080. En 1280×720 se multiplican por 2/3.
- **En cada cuadrante:**
  - la vista grande de la arena (`assets/ui/arena_<id>_mini.png`) con un degradado oscuro abajo;
  - el **nombre** en Cinzel Bold y debajo la **premisa** (2 líneas como mucho), con los textos de `fase11b.json`;
  - los iconos de sus trampas en la esquina de fuera;
  - los retratos de quien lo ha votado.
  - Marco 9-slice `cuadrante_marco.png` (margen 40).
- **En el centro**, un medallón redondo con "¡VOTAD!" y la cuenta atrás, y 4 flechitas apuntando a los cuadrantes.

**Votar:**
- Con las flechas o el stick vas pasando por los 4 cuadrantes (el que tienes elegido se ve un poco más claro) y confirmas con Espacio o A. También se puede hacer clic.
- 10 s de tiempo. Se puede cambiar el voto hasta el final, y se acaba antes si todos han votado.
- Los bots votan al azar en los primeros 3 s.

**Ruleta (siempre que hay empate, o si nadie vota):**
- La luz da vueltas por los cuadrantes empatados **en sentido horario**: el cuadrante encendido cambia a `cuadrante_brillo.png`, se aclara y suena un *tic*.
- Empieza rápido (0,06 s por salto) y va frenando poco a poco durante unos 3,5 s, como una ruleta de verdad. Los dos últimos saltos dan un poco de suspense.
- **El ganador:** el marco brilla latiendo, salen destellos, la vista crece un 4 %, el medallón muestra su nombre y suenan *ding* y fanfarria. Los otros tres cuadrantes se oscurecen.
- Si un mapa gana por votos, sin empate, no hay ruleta: brilla directamente.
- **El servidor** cuenta los votos, decide la ruleta con la semilla de la partida y manda a todos la lista de saltos, para que todos vean la misma animación.

**Contra bots:** el mismo sistema.

**Fase 10f:** si ya se hizo una pantalla de elegir arena en la fase 10, esta la sustituye a la de elegir arena. Las cartas (`carta_<arena>.png`) ya no se usan aquí; pueden servir para CÓMO SE JUEGA o la pantalla de carga.

## 11g · Partida en red

- **Entrada:**
  - el cliente manda su entrada al servidor 30 veces por segundo, `unreliable_ordered`: `submit_input(seq, move, dash, spell)`;
  - el dash y el hechizo también como intención `reliable`, para que no se pierdan.
- **Servidor:**
  - valida (longitud de `move` ≤ 1, como mucho 40 entradas por segundo, jugador vivo y en la sala);
  - simula;
  - manda a la sala `snapshot` a **20 Hz** (`unreliable_ordered`): posiciones, velocidades, estados y doblones que han cambiado;
  - manda los eventos de `pop_events()` como `reliable`.
- **Tu personaje:**
  - se mueve al momento en tu pantalla con la misma `ArenaPhysics` (predicción);
  - si el servidor dice otra cosa: menos de 8 px no se toca, entre 8 y 64 px se corrige poco a poco, y más de 64 px salta directamente.
- **Los demás:** se interpolan con 100 ms de retraso.
- **Trampas periódicas:** se calculan con el reloj de la partida que manda el servidor en cada snapshot, así que se ven igual en todos.
- Arriba a la derecha, un indicador pequeño de ping (verde < 80 ms, amarillo < 150 ms, rojo).

## 11h · Desconexiones y final

- **Si alguien se cae durante la partida:** "puff", su personaje desaparece y la partida sigue. Si queda 1 humano, gana él y se va al podio.
- **Si se cae el servidor:** cartel "Se ha perdido la conexión con el servidor" y vuelta al menú.
- **Al acabar:**
  - podio y emotes iguales para todos (fase 10);
  - el resultado se guarda en el servidor y se ve en `GET /results`;
  - **¡OTRA!** vuelve al lobby de la misma sala, con todos "no listos".

## 11i · Exportar y desplegar

Codex prepara los archivos; **el despliegue en Oracle lo hacen los humanos** siguiendo la guía.

- **Presets de exportación:**
  - "Windows" (cliente);
  - "Servidor Linux ARM64", para Oracle Ampere: modo *Dedicated Server*, sin texturas ni audio;
  - "Servidor Linux x86_64", para el PC de clase con Linux.
  - Si para el PC de clase se usa Windows, el servidor es el mismo `.exe` con `--headless -- --server`.
- **`docs/DESPLIEGUE.md`**, paso a paso para Oracle:
  - crear la VM Always Free (Ampere A1, Ubuntu);
  - abrir **UDP 7777** en la *Security List* y en el firewall de la VM (`iptables` / `ufw`);
  - SSH solo con clave;
  - usuario `godotserver`;
  - servicio `systemd`;
  - ver los logs con `journalctl`;
  - probar desde otra red.

  Incluye avisos: no elegir recursos de pago, revisar las cuotas y saber que Oracle puede no tener capacidad libre en la región.
- **En el juego:** AJUSTES → "Servidor": **Oracle** (dirección guardada en `GameConfig.ONLINE_HOST`), **Red local** (IP escrita a mano) o **Este PC** (`127.0.0.1`).
- Un `.bat` / `.sh` de ejemplo para arrancar el servidor en el PC de clase.

## 11j · Endurecer

- Límite de frecuencia en todas las RPC del cliente y tamaño máximo de los datos.
- Rechaza nombres de más de 12 caracteres o con caracteres de control, y cosméticos que no existan o no estén desbloqueados.
- Ningún cliente puede llamar a RPC del servidor que no sean suyas (crear, unirse, salir, entrada, listo, emote, cambios de taquilla y, si es anfitrión, modo, arena y bots).
- Ni contraseñas, ni claves, ni IPs privadas en el repositorio. La IP pública de Oracle va en `GameConfig` y se puede cambiar en AJUSTES.

---

## Al terminar: pruebas que tienen que quedar apuntadas en la bitácora

| Prueba | Resultado esperado |
|---|---|
| Servidor + 2 clientes en el mismo PC | Crean y se unen a una sala con código |
| 4 clientes en una sala | Todos aparecen una vez; el quinto recibe "Sala llena" |
| Código inventado | "No existe esa sala" |
| Un cliente manda `move` de longitud 5 | El servidor lo recorta a 1 |
| Un cliente se cae en mitad de la partida | "Puff" y la partida sigue |
| Se cierra el servidor | Todos ven el aviso y vuelven al menú |
| Partida completa | Todos ven el mismo ganador y el mismo podio |
| Votación con empate 2-2 | Todos ven la misma ruleta y la misma arena ganadora |
| Un jugador baila en el lobby | Los otros 3 lo ven bailar |
| Desde dos casas distintas contra Oracle | Partida completa con ping < 150 ms |
| PC de clase como servidor en la red local | Partida completa sin internet |

