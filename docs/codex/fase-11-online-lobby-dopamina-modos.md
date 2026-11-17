# Fase 11 — Online, lobby, dopamina y modos

> **Para Codex.** Antes de esta fase tiene que estar terminada la fase 10. Es una fase grande en tres partes; hazla en orden.
> Lee `docs/codex/plan-multijugador.md`, el plan del equipo: es la base de la parte 1 y sus reglas de seguridad y coste valen tal cual.
> Referencias visuales en `docs/media/`:
> - `lobby_mazmorra_referencia.png`: lobby;
> - `votacion_esquinas_referencia.png`: votación de arena;
> - `menu_brasa_referencia.png` y `textos_partida_referencia.png`: letra y color.
>
> Aquí se concreta para VoodooCombo: no hay vida ni disparos; hay doblones, dash, hechizos y trampas.

# Parte 1 · Online y lobby (11a-11i)

## Decisiones del equipo

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
- **Riesgo principal:** sin separar la simulación del dibujo no se puede tener un servidor sin pantalla. Es lo primero que hay que hacer (11a).

## Cómo trabajar esta fase

- Son 22 bloques en tres partes: **online y lobby (11a-11i)**, **letra y dopamina (11j-11r)** y **modos (11s-11v)**. En orden y con **un commit por bloque** (`Fase 11a: <resumen>`).
- **No cambies las reglas del juego** para meter la red: la partida contra bots tiene que jugarse igual que antes.
- Comprueba las APIs contra la documentación de Godot 4.7: `ENetMultiplayerPeer`, `@rpc`, `multiplayer.get_remote_sender_id()`, etc.
- Después de cada bloque, apunta en la bitácora qué archivos has tocado, cómo se prueba y qué se tiene que ver.

---

## 11a · Separar la simulación (`MatchSim`)

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

## 11b · Servidor dedicado

- Si el juego arranca con `--server`, carga `scenes/server/server.tscn`: sin menús, HUD, audio ni texturas.
- Se lanza con: `godot --headless --path . -- --server --port 7777`.
- `net/server_main.gd`:
  - crea el `ENetMultiplayerPeer` con `create_server(PORT, MAX_PEERS)`, con `MAX_PEERS = 32` (8 salas de 4);
  - ejecuta las `MatchSim` de las salas activas a **30 Hz**.
- **Solo hay una fuente de verdad de la red:** el autoload `Net`. No crees otro autoload que también gestione la conexión.
- Logs en la consola de conexión, desconexión, sala creada o cerrada y fin de partida, con fecha y hora.
- **Prueba:** servidor y dos clientes en el mismo PC conectados a `127.0.0.1`.

## 11c · Salas con código

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

## 11d · Lobby de mazmorra

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
- La arena no se elige aquí: se vota (11e).

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

Cuando todos los humanos están listos y hay al menos 2 jugadores (contando bots): **votación de arena** (11e) → pantalla de carga de 15 s (fase 10), todos a la vez.

Se usa entero con teclado y mando.

## 11e · Votación de arena: 4 mapas en las esquinas y ruleta

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

**Fase 10f:** esta pantalla sustituye a la de elegir arena. Las cartas (`carta_<arena>.png`) ya no se usan aquí; pueden servir para CÓMO SE JUEGA o la pantalla de carga.

## 11f · Partida en red

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

## 11g · Desconexiones y final

- **Si alguien se cae durante la partida:** "puff", su personaje desaparece y la partida sigue. Si queda 1 humano, gana él y se va al podio.
- **Si se cae el servidor:** cartel "Se ha perdido la conexión con el servidor" y vuelta al menú.
- **Al acabar:**
  - podio y emotes iguales para todos (fase 10);
  - el resultado se guarda en el servidor y se ve en `GET /results`;
  - **¡OTRA!** vuelve al lobby de la misma sala, con todos "no listos".

## 11h · Exportar y desplegar

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

## 11i · Endurecer

- Límite de frecuencia en todas las RPC del cliente y tamaño máximo de los datos.
- Rechaza nombres de más de 12 caracteres o con caracteres de control, y cosméticos que no existan o no estén desbloqueados.
- Ningún cliente puede llamar a RPC del servidor que no sean suyas (crear, unirse, salir, entrada, listo, emote, cambios de taquilla y, si es anfitrión, modo, arena y bots).
- Ni contraseñas, ni claves, ni IPs privadas en el repositorio. La IP pública de Oracle va en `GameConfig` y se puede cambiar en AJUSTES.

---

## Pruebas de la parte 1 que tienen que quedar apuntadas en la bitácora

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

# Parte 2 · Letra y dopamina (11j-11r)

## 11j · Letra y color: "Brasa minimal"

Lo decidió el equipo: ni dorado ni marrón, nada de letras "de plástico". Plano y minimalista, con una sola brasa de acento. **La dopamina la pone el movimiento, no la textura.** Referencias: `docs/media/menu_brasa_referencia.png` y `docs/media/textos_partida_referencia.png`. Ya está en `AGENTS.md` §7.

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

- **La dopamina, con movimiento** (todo con *tweens*, respetando "Reducir movimiento"):
  - **"+N":** entra a escala 1,8 → 1 con rebote (0,15 s), sube 50 px, y en los últimos 0,25 s se encoge y se desvanece. Si vale más de 1, además gira ±6° al entrar.
  - **"-N":** tiembla 3 px a los lados durante 0,2 s y cae un poco en vez de subir.
  - **Carteles grandes** ("¡VOODOO COMBO!", "¡FRENESÍ!"): entran desde escala 2,4 con rebote, laten 2 veces y salen hacia arriba. Detrás, una línea de brasa que se dibuja de izquierda a derecha.
  - **Marcador:** al subir, el número cuenta hacia arriba y hace *pop*; al bajar, se pone rojo un momento y tiembla.

## Qué es "de la buena" (y qué no)

**Sí:** recompensa por jugar bien y por jugar con amigos.
- Sonidos y efectos que te dicen "¡bien hecho!" al instante.
- Sorpresas pequeñas.
- Ver que mejoras.
- Momentos para reírse juntos.

**No:**
- cajas de botín ni nada que se pague;
- rachas diarias que te obliguen a entrar ("si no juegas hoy pierdes…");
- temporizadores que dan prisa para comprar;
- notificaciones fuera del juego;
- recompensas aleatorias que sustituyan a la habilidad.

Esto va también en `AGENTS.md`, como regla de diseño en §1.

**Reglas para todo:**
- Todo pasa por `Fx` y `Sfx`.
- Todo respeta "Reducir movimiento". Añade a AJUSTES un "Reducir destellos" que quite los flashes de pantalla.
- Todos los números nuevos van en `GameConfig`, en un bloque `# Juice`.
- Un commit por bloque (`Fase 11k: …`).

---

## 11k · La sensación al pegar y recoger (*game feel*)

- **Parón de golpe (*hitstop*):** la simulación visual se congela 60 ms al acertar un dash, 90 ms si quitas 5 o más doblones y 40 ms con las trampas. Solo la vista: el servidor sigue.
- **Sacudida de cámara** proporcional: 4 px al recoger con x3, 6 px en un golpe, 10 px en una explosión. Decae en 0,15-0,3 s.
- **Golpe de cámara:** zoom de +4 % durante 0,12 s en golpes fuertes y en el "¡VOODOO COMBO!".
- **Squash & stretch:** al recoger, el personaje se aplasta un pelín (escala 1,08 × 0,92 durante 0,08 s). Al aterrizar del dash, lo mismo pero más fuerte.
- **Partículas:** 6 chispas por doblón, polvo al frenar y al dash, y estela del color del jugador.
- **Vibración del mando** (`Input.start_joy_vibration`): suave al recoger con combo, media al golpear, fuerte al recibir. Con interruptor en AJUSTES.

## 11l · Los doblones vuelan a tu marcador

- Al recoger, además del "+N" en el sitio, un doblón pequeño **vuela en arco hasta tu ficha del marcador** (0,35 s). Al llegar, el número de la ficha **sube contando** (no salta), hace *pop* y suena un *tic* metálico.
- **Robo:** los doblones que le quitas a alguien hacen un arco **desde su ficha hasta la tuya** en el marcador. "¡ROBO!" en dorado sobre tu personaje. Al otro, su número baja en rojo.
- Cuantos más doblones seguidos, más agudo el *cling*, un semitono más por cada paso de combo (como dice §6), hasta 12 pasos.

## 11m · El combo como un instrumento

- **Medidor de combo** junto a tu personaje: un anillo que se vacía en 1,5 s.
  - Con x2 es naranja y con x3 rosa.
  - A partir de x3, el personaje lleva un aura de fuego morado (partículas) y la música sube una capa (11o).
- **Subir de multiplicador:** el texto del multiplicador tiembla y cambia de color, y suena un acorde que sube.
- **"¡VOODOO COMBO!"** (al llegar a x3): cartel grande, golpe de cámara, flash corto (si están permitidos) y lluvia de chispas por el borde de la pantalla 1 s.
- **Perder el combo** también se nota, pero sin castigar: el anillo se rompe en trocitos con un *pff* suave. Si era un combo de 10 o más, sale "¡Combo de 14!", en gris, para que sepas lo que habías conseguido.

## 11n · Medallas en plena partida

Pequeñas medallas que aparecen 1,5 s junto a tu ficha cuando haces algo especial, con su sonido (`assets/ui/medallas.png`, orden en `fase12.json`).

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

- Las medallas de los demás salen pequeñas en su ficha, para que todos se enteren.
- Al final, en el podio, cada uno enseña sus medallas debajo de su placa.
- Se cuentan en el perfil y aparecen en el HISTORIAL.

## 11o · Música que reacciona

La música ya es sintetizada (§6). Hazla por capas que entran y salen suavemente (0,5 s):

| Situación | Capas que suenan |
|---|---|
| Base | Tambor y bajo |
| Combo x2 o más | + Percusión rápida |
| Combo x3 | + Melodía |
| Frenesí | Todo un 25 % más rápido y un tono más alto |
| Últimos 10 s | Tambor grave en cada segundo |

- Al ganar, la música se para medio segundo antes del podio, y luego entra la fanfarria. **El silencio antes del premio hace que el premio se note más.**

## 11p · Momentos de tensión

- **Último doblón decisivo:** si en los últimos 5 s el primero y el segundo están a 3 puntos o menos, cámara lenta x0,7 visual, latido de corazón y el marcador de los dos parpadeando.
- **Final de partida:** cámara lenta de 0,5 s en el último segundo, zoom al ganador y explosión de confeti de doblones (§6).
- **Remontada:** si el que gana iba último a mitad de partida, el podio dice "¡REMONTADA!" bajo su nombre.

## 11q · Después de la partida: progreso que se ve

- **Barra de nivel** en el podio, después de los emotes:
  - se llena poco a poco con un *tic* por cada 10 XP;
  - al subir de nivel, la barra explota en chispas y suena una fanfarria corta.
- **Desbloqueo:** si se desbloquea algo, una **caja de la taquilla** (no se compra: se gana jugando) tiembla, se abre con luz y enseña el cosmético nuevo girando. Botones "EQUIPAR" y "SEGUIR".
- **Retos de partida** (3 en la pantalla de carga, como "Roba 6 doblones", "Llega a x3" o "Usa 2 hechizos"):
  - durante la partida, un aviso pequeño cuando cumples uno;
  - cada reto da XP extra al final;
  - se renuevan cada partida, no cada día.

## 11r · Pulir menús y UI

- Cada botón: *hover* con un sonido suave y escala 1,05; al pulsar, se aplasta 0,95 y hace *clack*.
- Las transiciones entre pantallas son un **telón de tela** que se cierra y se abre (0,35 s), no un corte seco.
- El cursor del menú es un **alfiler vudú** (dibujado por código o un sprite pequeño).
- El logo del menú da un latido cada 4 s, con un brillo que le pasa por encima.

---

## Al terminar la parte 2

- Tests de lo que sea lógica pura: detección de medallas y retos, y la XP que da cada reto.
- En `docs/BITACORA.md`, qué tenemos que probar:
  - que el *hitstop* y la sacudida no mareen;
  - que con "Reducir movimiento" y "Reducir destellos" todo siga siendo claro;
  - que cada medalla salta cuando toca;
  - que la música cambia de capa sin cortes;
  - que la barra de nivel y el desbloqueo se sienten bien.
- Una entrada en `docs/HISTORIA-IA.md`: "Dopamina de la buena: recompensas por habilidad, sin cajas de pago".

# Parte 3 · Modos (11s-11v)

## 11s · Quitar el modo Clásico

- Decisión del equipo: el Clásico desaparece del juego.
- Quita:
  - el botón y la opción de modo;
  - `mode == "classic"` y las constantes `CLASSIC_*`;
  - los textos de I18n;
  - sus tests.
- **`AGENTS.md`:**
  - §1: los modos pasan a ser **VoodooCombo**, **Último en Pie** y **Codicia 2v2**;
  - §4.6: tabla nueva con los tres modos (abajo);
  - quita las demás menciones al Clásico.
- **`docs/HISTORIA-IA.md`:** añade una entrada "Quitamos el modo Clásico". Qué decidimos: [que lo completen los humanos]. Por qué: [ídem]. Apunta también que la IA avisó de que es el requisito literal del enunciado.
- El endpoint `/results` sigue diciendo el ganador de cada partida.

## 11t · Modo Último en Pie (todos contra todos)

Supervivencia: **no hay doblones**. Gana el último muñeco cosido.

- **Vidas:** cada jugador tiene **3 costuras** (`assets/ui/costuras.png`: 0 entera, 1 rota).
  - Se ven en su ficha del marcador y, en pequeño, encima de su cabeza.
- **Pierdes una costura** al recibir un dash de un rival, el alfiler, o una trampa que hace daño (pinchos, rayo, fantasma, barril, vapor, raíces). Después tienes 1,5 s de invulnerabilidad, como siempre.
- **Sin costuras:** el personaje se descose (puff de tela y botones saltando) y pasa a ser un **fantasmita**:
  - se mueve a x0,6;
  - no colisiona ni puede hacer nada a nadie;
  - puede usar emotes.
- **Hechizos:**
  - hay cofres cada 5 s (máximo 2) y valen los 7 hechizos;
  - la Capa bloquea un golpe;
  - la Escarcha congela;
  - la Oveja va contra quien tenga más costuras;
  - el Anillo se cambia por **Costura Extra** (+1 costura, máximo 3). Pon su icono y texto en `ItemTable` para este modo.
- **La niebla se cierra** (bloque 10j) más deprisa: un paso cada 15 s desde el principio, hasta una zona de 10×5 casillas.
  - Fuera de la zona pierdes una costura cada 3 s.
- **Rondas:** al mejor de 3 (gana quien gane 2 rondas).
  - Cada ronda dura como mucho 90 s. Si se acaba el tiempo, gana quien tenga más costuras; si hay empate, muerte súbita: la zona salta a su tamaño mínimo.
  - Entre rondas: cartel "RONDA 2" de 4 s, en otra arena al azar y con todos de nuevo con 3 costuras. No hay pantalla de carga de 15 s entre rondas, solo al principio.
- **Podio:** ordenado por rondas ganadas y, si hay empate, por costuras que quedaban en la última ronda.
- **Bots:**
  - sin doblones que perseguir, van a por el rival más cercano que no sea invulnerable, o al cofre si no tienen hechizo;
  - huyen cuando les queda 1 costura y tienen a alguien a menos de 150 px;
  - siempre se quedan dentro de la zona.
- **Tests:**
  - 3 golpes dejan a un jugador como fantasmita;
  - la ronda acaba cuando queda uno;
  - quien gana 2 rondas gana la partida.

## 11u · Modo Codicia 2v2 (por equipos)

Dos equipos de dos. Los doblones solo cuentan cuando los **guardas en el cofre de tu equipo**.

- **Equipos:**
  - las peanas 1-2 del lobby son el **equipo coral** y las 3-4 el **equipo azul**;
  - el anfitrión puede cambiar a alguien de equipo;
  - los huecos los rellenan bots;
  - los jugadores usan el color de su equipo (`coral` / `azul` en sus sprites) y su forma de siempre.
- **Cofres:** `assets/items/cofre_equipo_coral.png` y `cofre_equipo_azul.png` (frame 1 cuando se guarda).
  - En `GameConfig.TEAM_BASES`: coral en (80, 300) y azul en (1120, 300). Están libres en las 4 arenas.
  - Zona de entrega de radio 56 px.
- **Llevar doblones:**
  - los que coges van encima: se ve una pila de doblones sobre tu cabeza y el número;
  - cada doblón que llevas te frena un 2 % (como mucho un 40 %, con 20 o más) y te hace un 1 % más grande (como mucho un 20 %). ¿Arriesgas o vuelves a guardar?
- **Guardar:** al entrar en tu zona, los doblones vuelan uno a uno al cofre (0,05 s cada uno), con sonido de caja y "+N" con el color del equipo.
- **Golpes:**
  - si un rival te da un dash, o te pilla una trampa, **sueltas todo lo que llevas** en abanico;
  - los del cofre están a salvo;
  - entre compañeros no hay golpes.
- **Doblones:** 40 en la arena al empezar; si quedan menos de 20, aparece uno cada 0,8 s.
  - Cada doblón vale 1; en el Frenesí (últimos 15 s), 2.
  - No hay combo de puntos en este modo.
- **Hechizos:** los 7.
  - La Oveja va contra el rival que lleve más doblones encima;
  - el Imán atrae doblones y también los que suelta un rival golpeado;
  - el Anillo hace que lo que coges valga doble durante 6 s.
- **Sin niebla:** los cofres están en los bordes.
- **Marcador:** arriba en el centro, los dos cofres con su total en grande (coral a la izquierda y azul a la derecha) y el tiempo en medio. Las fichas individuales enseñan lo que lleva encima cada jugador.
- **Final:** gana el equipo con más doblones en su cofre a los 90 s. En el podio, el equipo ganador sube junto al primer puesto.
- **Bots:**
  - cogen doblones hasta llevar entre 6 y 10, o hasta que un rival se acerque, y entonces vuelven a su cofre;
  - van a por el rival que más lleve si está a menos de 160 px;
  - si su compañero lleva mucho, se quedan cerca para protegerlo.
- **Tests:**
  - guardar suma al cofre del equipo correcto;
  - un golpe hace soltar todo lo que se lleva y nada del cofre;
  - con 20 doblones encima la velocidad es x0,6.

## 11v · Selector de modo y explicaciones

- En el lobby, al cambiar de modo, sale una tarjeta corta con 3 líneas de reglas y su icono.
- La pantalla de carga (10g) enseña las reglas del modo elegido en vez de las de VoodooCombo cuando toca.
- Al empezar cada partida o ronda, un cartel de 2 s con el objetivo: "¡Sé el último en pie!" / "¡Llena el cofre de tu equipo!".

## Ideas para más adelante (no hacer ahora)

Patata Vudú · Altar (rey de la colina) · Cazador 1v3 · Fútbol Vudú 2v2. Están descritas en el historial de diseño; si sobra tiempo, se hacen igual que estos dos, como modos sobre `MatchSim`.

## Al terminar la parte 3

Ejecuta los tests y escribe en `docs/BITACORA.md` qué tenemos que probar:
- una partida de cada modo contra bots y otra en red;
- cambiar de equipo y de modo en el lobby;
- desconectarse en mitad de una ronda.
