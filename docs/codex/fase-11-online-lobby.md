# Fase 11 — Multijugador por internet y lobby

> **Para Codex.** Antes de esta fase tiene que estar terminada la fase 10.
> Lee `docs/codex/plan-multijugador.md`, el plan del equipo: es la base de esta fase y sus reglas de seguridad y coste valen tal cual.
> Aquí se concreta para VoodooCombo: no hay vida ni disparos; hay doblones, dash, hechizos y trampas.
> Referencia visual del lobby: `docs/media/lobby_referencia.png`.

## Decisiones del equipo

- **Servidor dedicado y autoritativo**, con Godot sin pantalla (*headless*) y `ENetMultiplayerPeer` por UDP.
  - Un solo proceso de servidor que lleva **varias salas** a la vez.
  - El cliente nunca decide doblones, golpes, puntos ni ganador.
- **Dónde corre:**
  - **Oracle Cloud Always Free**, para jugar desde casa.
  - **De respaldo, un PC de clase** con el mismo ejecutable de servidor en la red local, por si falla internet.
- **Cómo se entra:** solo con **código de sala**, de 5 letras. Sin partida rápida pública.
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

- Son 8 bloques (**11a-11h**), en orden y con **un commit por bloque** (`Fase 11a: <resumen>`).
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

## 11d · Lobby estilo Fortnite

Tiene que quedar como `docs/media/lobby_referencia.png`, con el fondo `assets/ui/lobby_fondo.png`.

- **Entrar al online:** en el menú, JUGAR abre **JUGAR ONLINE**, con tres opciones: **CREAR SALA**, **UNIRSE CON CÓDIGO** (campo de 5 letras) y **CONTRA BOTS** (como ahora, sin red).
- **Escenario:**
  - 4 peanas en x = 420, 780, 1140 y 1500 (en 1920×1080).
  - **Tú siempre en la segunda peana**, un poco más grande. Los demás, en el orden en que llegaron.
  - Cada uno con su personaje en `idle`, su marco y una placa con su nombre y **LISTO** en verde o "…".
  - El anfitrión, con la corona y "ANFITRIÓN" encima.
- **Huecos libres:** silueta con "+ INVITAR" y el código. El anfitrión ve además **AÑADIR BOT**.
- **Arriba a la izquierda:** el **código de sala** en grande y el botón **COPIAR** (`DisplayServer.clipboard_set`).
- **Arriba a la derecha:** **MODO** y **ARENA** con flechas ‹ ›. Solo los cambia el anfitrión; los demás lo ven pero no pueden tocarlo.
- **Abajo:**
  - **TAQUILLA**: personaje, marco, estela y emotes, como en la fase 10. Los cambios se ven al momento en tu peana y en la de los demás;
  - **¡LISTO!** (grande): cambia entre listo y no listo;
  - **SALIR**.
- **Emotes** con las teclas 1-4: el bocadillo lo ven todos.
- **Empezar:** cuando todos los humanos están listos y hay al menos 2 jugadores (contando bots), cuenta atrás de 5 s en el lobby. Después, todos pasan a la **pantalla de carga de 15 s** (fase 10) al mismo tiempo.
- Se usa entero con teclado y mando.

## 11e · Partida en red

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

## 11f · Desconexiones y final

- **Si alguien se cae durante la partida:** "puff", su personaje desaparece y la partida sigue. Si queda 1 humano, gana él y se va al podio.
- **Si se cae el servidor:** cartel "Se ha perdido la conexión con el servidor" y vuelta al menú.
- **Al acabar:**
  - podio y emotes iguales para todos (fase 10);
  - el resultado se guarda en el servidor y se ve en `GET /results`;
  - **¡OTRA!** vuelve al lobby de la misma sala, con todos "no listos".

## 11g · Exportar y desplegar

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

## 11h · Endurecer

- Límite de frecuencia en todas las RPC del cliente y tamaño máximo de los datos.
- Rechaza nombres de más de 12 caracteres o con caracteres de control, y cosméticos que no existan o no estén desbloqueados.
- Ningún cliente puede llamar a RPC del servidor que no sean suyas (crear, unirse, salir, entrada, listo, emote, cambios de taquilla y, si es anfitrión, modo, arena y bots).
- Ni contraseñas, ni claves, ni IPs privadas en el repositorio. La IP pública de Oracle va en `GameConfig` y se puede cambiar en AJUSTES.

---

## Pruebas que tienen que quedar apuntadas en la bitácora

| Prueba | Resultado esperado |
|---|---|
| Servidor + 2 clientes en el mismo PC | Crean y se unen a una sala con código |
| 4 clientes en una sala | Todos aparecen una vez; el quinto recibe "Sala llena" |
| Código inventado | "No existe esa sala" |
| Un cliente manda `move` de longitud 5 | El servidor lo recorta a 1 |
| Un cliente se cae en mitad de la partida | "Puff" y la partida sigue |
| Se cierra el servidor | Todos ven el aviso y vuelven al menú |
| Partida completa | Todos ven el mismo ganador y el mismo podio |
| Desde dos casas distintas contra Oracle | Partida completa con ping < 150 ms |
| PC de clase como servidor en la red local | Partida completa sin internet |
