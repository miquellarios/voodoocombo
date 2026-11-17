# Fase 10 — Puntos, trampas, hechizos, mapas, carga y final de partida

> **Para Codex.** Antes de empezar, lee `AGENTS.md`, `assets/arenas/ARENAS.md` y `assets/ui/UI.md` (sección "Fase 10").
> Referencias visuales en `docs/media/`:
> - `hud_v2_referencia.png`: partida con nombres, ranura nueva y la niebla cerrándose;
> - `resultados_referencia.png`: podio con emotes.
>
> El lobby y el multijugador por internet **no** entran en esta fase: van en la fase 11, igual que quitar el modo Clásico y los modos nuevos: aquí no toques el Clásico.

## Qué hemos visto al probar la versión 9

1. Con el combo, el Frenesí y el Anillo se llega a 1000 doblones: cada uno llega a valer 16.
2. Las trampas quitan una cantidad fija de doblones; queremos que quiten un porcentaje.
3. Los hechizos se activan solos y la E no hace nada con algunos. La ranura "HECHIZO E" queda cortada por el borde de la arena.
4. Los obstáculos frenan casi una casilla antes de tocarlos.
5. En la Biblioteca el rayo se dibuja descolocado. En el Taller, la cinta de abajo dibuja las flechas al revés y faltan los rodillos.
6. No se puede elegir el mapa.
7. Hay demasiados doblones y se puede campear en una zona.
8. No queda claro cuál es tu personaje.
9. Los textos de "+N" y de combo duran poco y se ven borrosos.
10. Al final sobra texto (lista de jugadores, monedas, XP) y los niveles no sirven para nada.
11. La ventana es pequeña: queremos 1920×1080 y poder cambiarla.

## Cómo trabajar esta fase

- Son 12 bloques (**10a-10l**). Hazlos en orden y haz **un commit por bloque** (`Fase 10a: <resumen>`).
- Antes de cada bloque, resume en 3-5 líneas qué vas a cambiar.
- Todos los números nuevos van en `core/game_config.gd`; todos los textos, por `I18n.t()`.
- Cuando un bloque cambie una regla, actualiza también su sección de `AGENTS.md`.

---

## 10a · Puntos: los bonos suman, no multiplican

**Causa:** `Scoring.coin_value()` multiplica el combo (x4) por el Frenesí (x2) y por el Anillo (x2).

- **Valor de un doblón** = multiplicador de combo + 1 si es Frenesí + 1 si llevas el Anillo. Máximo 5.
- **Multiplicador de combo:**

  | Combo | Multiplicador | Aviso |
  |---|---|---|
  | 0-4 | x1 | — |
  | 5-11 | x2 | "¡Combo!" |
  | 12 o más | x3 | "¡VOODOO COMBO!" |

- **Menos doblones en VoodooCombo:**
  - 30 al empezar;
  - si quedan menos de 12, aparece uno cada 1,0 s;
  - en el Frenesí, hasta mantener unos 18.
- Actualiza §4.3 de `AGENTS.md`.
- **Tests:** `coin_value` da 1, 2, 3, 4 y 5 en los casos límite, y nunca más de 5.

## 10b · Las trampas quitan un porcentaje

- Todas las trampas que hacen daño (pinchos, rayo, fantasma, barril, vapor y raíces) quitan **el 15 % de tus doblones, con un mínimo de 2 y un máximo de 10**. Si tienes menos de 2, los que tengas.
- Lo que hace cada trampa además de quitar doblones (aturdir, empujar, atrapar) no cambia.
- El golpe de un rival con dash sigue en el 25 % (35 % con corona; 40 % con el Anillo).
- Todo pasa por la misma `apply_hit(...)` con `GameConfig.TRAP_DROP_PCT = 0.15`, `TRAP_DROP_MIN = 2` y `TRAP_DROP_MAX = 10`. Quita las cantidades fijas (2, 3, 20 %).
- Los doblones que suelta una trampa saltan en abanico como en un golpe y tú no los puedes recoger durante 0,6 s.
- Actualiza §4.8 de `AGENTS.md` y `ARENAS.md`.
- **Test:** con 0, 1, 10, 40 y 200 doblones, una trampa quita 0, 1, 2, 6 y 10.

## 10c · Hechizos: solo con la E

**Causas encontradas en `scenes/main/main.gd`:**
- En `_update_roll()`, al salir el hechizo se le pone `item_time`. Por eso las botas, el imán, el anillo y la capa empiezan a funcionar solos.
- `_use_spell()` hace `return` con `"cloak", "boots", "magnet", "ring"`, así que la E no hace nada con ellos.
- La E se procesa dos veces: en `_process()` (`is_action_just_pressed`) y en `_unhandled_input()`. Deja solo una.

**Cómo tiene que funcionar:**
- **Al abrir un cofre**, el hechizo se guarda en la ranura **sin hacer nada**. Aparece una tarjeta grande 2 s encima de la ranura: icono, nombre y una frase. Ejemplo: "NOVA DE ESCARCHA · Congela a los rivales cercanos · Pulsa E".
- **Al pulsar E**, se lanza:
  - los de efecto instantáneo (alfiler, escarcha, oveja) actúan y la ranura se vacía;
  - los de duración (imán 5 s, botas 4 s, anillo 6 s, capa 8 s) se activan y un aro alrededor de la ranura se vacía con el tiempo que queda. Al acabar, la ranura se vacía.
- Con una duración activa no se puede coger otro cofre.
- Los bots lanzan su hechizo con su propia lógica, pero también empiezan sin activarlo.
- **Ranura nueva** (`assets/ui/hechizo_ranura.png`, `hechizo_brillo.png`, `tecla_e.png` / `tecla_b.png`):
  - Abajo a la izquierda, a 80×80 px, **sin salirse de la pantalla** ni quedar cortada.
  - Vacía: apagada (modulate 0,5).
  - Con hechizo listo: el brillo late y se ve la tecla (E con teclado, B con mando, según lo último que se haya usado).
  - A la derecha, el nombre del hechizo.
- **Tests:** coger un cofre no cambia la velocidad ni el valor de los doblones hasta pulsar E; pulsar E una vez gasta el hechizo una sola vez.

## 10d · Colisión con lo que se ve

- `assets/arenas/arenas.json` trae un campo nuevo en cada obstáculo: `hitbox` = `[x, y, ancho, alto]`, que es la huella real del objeto en el suelo.
- **Los personajes chocan contra `hitbox`**, no contra `rect`. `rect` solo sirve para la rejilla de los bots y para no poner doblones encima.
- Para chocar con los obstáculos usa el círculo de los pies: radio 14 px, centrado 12 px por debajo de la posición del personaje. Las recogidas, los golpes y la separación entre jugadores siguen con el círculo de 22 px.
- **Test:** un personaje que camina hacia un árbol se para a menos de 6 px de su tronco.

## 10e · Arreglos de las arenas

- **Biblioteca, rayo:** en `_draw_ray_beams()` se usa `draw_set_transform(center, ...)` sin el desplazamiento de la arena, así que el haz sale corrido (-40, -60). Debe ser `center + OFFSET`. Comprueba que los dos brazos salen del centro del orbe y que el golpe coincide con el haz dibujado.
- **Taller, cintas:**
  - Las flechas tienen que apuntar en la dirección `dir` de cada cinta: con `dir` = (-1, 0), voltea el sprite.
  - Dibuja `cinta_rodillo` en los dos extremos de cada cinta.
  - Comprueba que el empuje va en la misma dirección que las flechas.
- **Las 4 arenas:** recorre cada una y compara las trampas con `docs/media/arenas.jpg`. Todas tienen que estar donde dice `arenas.json` y alineadas con su casilla. Si algo más no cuadra, arréglalo y apúntalo en la bitácora.

## 10f · Elegir el mapa

- Después de JUGAR aparece la pantalla de votación de arena descrita en `docs/codex/fase-11-online-lobby-dopamina-modos.md`, bloque **11e**:
  - los 4 mapas, uno en cada esquina de la pantalla, con su premisa;
  - votas con las flechas y los bots también votan;
  - si hay empate, ruleta.
- En esta fase solo hace falta para jugar contra bots; en la 11 se conecta con la red.
- `ArenaGen.generate()` acepta un `arena_id` concreto.

## 10g · Pantalla de carga de 15 s

- Entre elegir arena y la cuenta atrás hay una pantalla de carga de **15 s** (`GameConfig.LOADING_SECONDS = 15.0`):
  - arriba, el nombre de la arena (Cinzel Bold) y su miniatura grande;
  - a un lado, **sus trampas**: icono de `trampas_iconos.png` y una frase que diga qué hacen y cuánto quitan;
  - debajo, los **controles**: mover, dash, hechizo (E) y emotes (1-4);
  - un **consejo** que cambia cada 4 s, de una lista de al menos 10. Ejemplos: "El combo se pierde si pasas 1,5 s sin coger un doblón", "Con la corona sueltas más doblones si te golpean", "Los doblones que sueltas no los puedes recoger durante un momento";
  - **tu personaje** con tu nombre y "Eres el Jugador N";
  - una barra de carga que se llena en 15 s.
- Mientras tanto se generan la arena y los doblones y se cargan las texturas.
- En partidas sin otros humanos, a partir de los 5 s se puede pulsar Espacio para empezar antes ("Pulsa Espacio para empezar").

## 10h · Saber quién eres: tu nombre

- **Primera vez que se abre el juego:** pantalla "¿Cómo te llamas?" con un campo de texto (de 3 a 12 caracteres, sin espacios al principio ni al final). Se guarda en `Profile.nick`. Se puede cambiar después desde PERSONAJES.
- **En la partida:**
  - Encima de cada personaje, su nombre: blanco, Oswald Medium de 18 px, con contorno.
  - El tuyo, más grande (22 px), en tu color y con "TÚ" y una flecha encima.
  - Bajo tus pies, un aro de tu color que late suavemente durante toda la partida.
  - Mira `hud_v2_referencia.png`.
- En las fichas del marcador aparece el **nombre del jugador** (no el del personaje), y debajo "J1 · TÚ", "J2"…
- Los bots se llaman con nombres del juego: "Mordisquitos", "Conde Costura", "Dama del Pantano".

## 10i · Textos que se ven bien

**Causa:** `_draw()` usa `ThemeDB.fallback_font` a 17-22 px, y los textos flotantes duran 0,8 s (`_on_floating_text`).

- Usa las fuentes del proyecto con contorno (`draw_string_outline` y después `draw_string`, o `Label` con `outline_size`):
  - "+N": Oswald Bold de 30 px (36 px si vale 3 o más), plana, con contorno de 6 px `#0B0710`. Hueso `#EFE7DA` si vale 1 y brasa `#FF6A2B` si lleva bonus.
  - Avisos de combo ("¡Combo!", "¡VOODOO COMBO!") y de trampa ("¡Atrapado!", "¡Zas!"): Cinzel Bold de 44-64 px, espaciada, en brasa `#FF6A2B` con resplandor suave (ver el bloque 11j del documento de la fase 11).
- **Duración:** "+N" 1,2 s; avisos 1,6 s. Entran con *pop* (escala 1,6 → 1 en 0,15 s), suben 40 px y se desvanecen solo en los últimos 0,3 s.
- Junto a tu personaje, mientras dure la racha, un círculo pequeño con "x2" / "x3" y el número del combo, como en el tráiler.
- Los avisos grandes de combo van en la capa del HUD, cerca del centro arriba, para que no los tape nada.

## 10j · La zona se cierra (contra el campeo)

- En los segundos 45, 35 y 25 que quedan, la zona segura se encoge un paso.
- **Cada paso** quita 2 casillas por cada lado en horizontal y 1 en vertical. Al final queda una zona de 18×9 casillas en el centro.
- **Aviso:** 3 s antes de cada paso, el borde nuevo parpadea en `#B06BFF`, suena un aviso y sale "¡LA NIEBLA SE CIERRA!".
- **Fuera de la zona:**
  - niebla (`assets/ui/zona_niebla.png`, repetida y moviéndose despacio);
  - vas a x0,7 de velocidad y pierdes 1 doblón cada 0,75 s (sale "-1" en morado);
  - los doblones y los cofres que quedan fuera se desvanecen y reaparecen dentro.
- **Bots:** su objetivo siempre está dentro de la zona y, si se quedan fuera, vuelven.
- **Test:** con los tiempos de prueba, la zona del paso 3 mide 18×9 casillas, y un jugador fuera pierde 4 doblones en 3 s.

## 10k · Ventana a 1080 y tamaño ajustable

- La resolución base sigue siendo 1280×720: todo el diseño está hecho a ese tamaño.
- `project.godot`: `window_width_override=1920` y `window_height_override=1080`, ventana redimensionable, stretch `canvas_items` y aspect `keep`. Así todo se escala, se ve nítido y no se deforma.
- **AJUSTES:**
  - "Pantalla": Ventana / Pantalla completa (F11 también lo cambia);
  - "Tamaño de ventana": 1280×720, 1600×900, 1920×1080.
  - Se guarda en `Settings`.
- Las texturas están exportadas al doble, así que a 1080 se ven nítidas.

## 10l · Final de partida con podio y emotes; los niveles dan cosméticos

### Podio

Tiene que quedar como `docs/media/resultados_referencia.png`.

- **Fondo:** `assets/ui/resultados_fondo.png`.
- **Bloques:** `assets/ui/podio.png`, con 1º en el centro, 2º a la izquierda y 3º a la derecha.
- **Personajes:**
  - encima de cada bloque, con su animación: `win` el primero (con la corona) y `idle` el segundo y el tercero;
  - el cuarto, en el suelo a la derecha, con `hurt`;
  - entran cayendo uno tras otro, con confeti.
- **Título:** "¡GANA <nombre>!".
- **Placa de cada jugador:** solo su nombre y un doblón con su puntuación.
- **Fuera:** la lista de jugadores, las monedas ganadas, la XP y el nivel. No quiero más texto.
- **Botones:** MENÚ PRINCIPAL (con el foco) y ¡OTRA!. Si nadie pulsa nada en 15 s, se vuelve solo al menú.

### Emotes

- En el podio, las **teclas 1-4** (o la cruceta del mando) lanzan uno de tus 4 emotes equipados.
- Sale un bocadillo de `assets/ui/emotes.png` encima de la cabeza durante 2 s. Se puede lanzar otro cada 1 s.
- Los bots lanzan 1 o 2 al azar.
- Abajo a la izquierda, la barra con los 4 emotes y su tecla.

### Niveles → cosméticos

- La XP se sigue ganando por partida, pero **no se enseña** en el menú ni en los resultados.
- Cada nivel desbloquea un cosmético:

  | Nivel | Desbloquea |
  |---|---|
  | Inicio | Emotes risa, enfado, GG y corazón · marco de madera · estela de tu color |
  | 2 | Marco de hueso |
  | 3 | Emote calavera |
  | 4 | Estela dorada |
  | 5 | Marco de plata |
  | 6 | Emote llanto |
  | 7 | Estela de escarcha |
  | 8 | Marco de oro |
  | 9 | Emotes pulgar y fuego |
  | 10 | Marco de almas · estela de almas |

- **Marcos:** `assets/ui/marco_<id>.png`, encima del retrato del marcador.
- **Estelas:** el color de la estela del dash (dorada `#FFD23F`, escarcha `#7FE7FF`, almas `#B06BFF`).
- **Al desbloquear algo**, en los resultados sale una sola tarjeta: "¡Nuevo! Marco de plata", con su imagen.
- **PERSONAJES pasa a ser la TAQUILLA**, con pestañas: Personaje · Marco · Estela · Emotes (eliges 4).
  - Lo bloqueado sale con un candado y "Nivel N".
  - Se guarda en `Profile.cosmetics`. Quita el sombrero, los ojos y la estela antiguos, que ya no encajan.

---

## Al terminar

- Ejecuta los tests en headless y arregla lo que falle.
- En `docs/BITACORA.md`, una entrada por bloque con **qué tenemos que probar**:
  - que una partida normal acabe entre 60 y 150 puntos para el ganador;
  - que cada trampa quite el 15 %;
  - que ningún hechizo funcione sin pulsar E;
  - caminar pegado a los obstáculos de las 4 arenas;
  - el rayo y las cintas;
  - elegir mapa, la pantalla de carga y la zona que se cierra;
  - la ventana a 1080 y en pantalla completa;
  - el podio con emotes;
  - desbloquear un cosmético.
