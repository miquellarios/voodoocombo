# Fase 9 — Bots, trampas, texturas, marcador y menú

> **Para Codex.** Antes de empezar, lee `AGENTS.md`, `assets/arenas/ARENAS.md`, `assets/items/ITEMS.md` y `assets/ui/UI.md`.
> Referencias visuales: `docs/media/menu_referencia.png` (menú) y `docs/media/hud_referencia.png` (partida con el marcador).

## Qué hemos visto al probar el juego

1. Los bots se quedan atascados contra los muros.
2. Dos personajes se quedan uno encima del otro, haciéndose dash sin parar.
3. Las trampas solo se ven: no hacen nada.
4. Los doblones y los cofres son círculos y rectángulos.
5. El marcador de puntos no se ve durante la partida.
6. El menú principal es provisional.
7. Al acabar la partida, la partida se queda detrás y no se vuelve al menú.

## Cómo trabajar esta fase

- Son 7 bloques (**9a-9g**). Hazlos en orden y haz **un commit por bloque** (`Fase 9a: <resumen>`), para que podamos deshacer un bloque sin perder los demás.
- Antes de cada bloque, busca dónde está ahora el código afectado (`scenes/main/main.gd`, `net/bot_brain.gd`, `net/hazards.gd`… puede haber cambiado) y resume en 3-5 líneas qué vas a cambiar.
- Todos los números nuevos van en `core/game_config.gd`. Todos los textos nuevos, por `I18n.t()`.
- La lógica que se pueda probar sin nodos va en `core/`, con tests.

---

## 9a · Movimiento y colisiones

**Causa probable:** al chocar con un obstáculo se vuelve a la posición anterior (`pos = previous_position`). Quien empuja en diagonal contra un muro se queda quieto en vez de deslizarse.

- **Una sola función de movimiento** para jugador, bots, dash, empujones y trampas, en `core/` (por ejemplo `ArenaPhysics.move_circle(pos, motion, radius, rects) -> Vector2`):
  - Mueve primero en X y después en Y. Si un eje choca, solo se anula ese eje: así se desliza por el muro.
  - Choca con los bordes de la arena y con los obstáculos de `arenas.json`, con radio 22 px.
- **Separación entre jugadores:** si dos están a menos de 44 px, se separan la mitad cada uno, sin meterlos en un obstáculo. Nunca pueden quedar uno encima del otro.
- **Tests:**
  - Un círculo que va en diagonal contra un muro avanza a lo largo del muro.
  - Dos jugadores en el mismo punto acaban a 44 px.

## 9b · Bots que no se atascan

- **Camino:** `AStarGrid2D` de 30×15 casillas con los obstáculos como sólidos (`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`). Las trampas que hacen daño (pinchos, barril) no bloquean, pero cuestan más (`set_point_weight_scale` = 4).
- **Recalcula** el camino cada 0,3 s (no en cada frame) y sigue el siguiente punto. A menos de 12 px de un punto, pasa al siguiente.
- **Objetivo:**
  - El doblón con el camino más corto. Si no tiene hechizo, los cofres también cuentan.
  - Cada bot suma un sesgo aleatorio pequeño, para que no vayan todos al mismo doblón. Si otro bot va al mismo y está más cerca, elige otro.
- **Anti-atasco:** si en 0,5 s se ha movido menos de 20 px, cambia de objetivo y durante 0,3 s va en una dirección libre al azar.
- **Trampas:**
  - Evita las casillas de pinchos en aviso o arriba.
  - No entra en el círculo del rayo (radio 290 px) cuando un brazo está a menos de 40° de su posición.
  - Usa un portal si su pareja le deja más cerca del objetivo.
- **Test:** un bot con el objetivo detrás de un obstáculo llega a él en menos de 5 s de simulación.

## 9c · Dash entre bots y choques

**Causas probables:**
- La probabilidad de dash (30 %) se tira en cada frame, así que el bot hace dash en cuanto lo tiene listo.
- Nadie se separa.
- En el choque de dashes nadie rebota.
- Después de golpear, el bot sigue persiguiendo al mismo rival.

**Qué hacer:**
- El bot **decide** cada 0,4-0,6 s, no en cada frame. Hace dash con un 30 % de probabilidad solo si se cumple todo esto:
  - el rival está a menos de 120 px;
  - lo ve, sin un obstáculo en medio;
  - el rival no es invulnerable ni está aturdido;
  - el bot no ha golpeado a nadie en los últimos 2,5 s.
- Después de golpear, ignora a ese rival 2,5 s y vuelve a por doblones (normalmente los que acaban de caer).
- **Choque de dashes (§4.2):** los dos rebotan 70 px en direcciones opuestas en 0,15 s y quedan 0,3 s sin poder hacer dash. Nadie suelta nada.
- El dash se para al chocar con un obstáculo.
- **Test:** dos bots juntos durante 10 s sin doblones cerca hacen como mucho 4 dashes entre los dos, y nunca están a menos de 40 px durante más de 0,2 s.

## 9d · Trampas que hacen daño

- La lógica va en `net/hazards.gd` (o donde esté ahora), con los datos de `assets/arenas/arenas.json` y las reglas de `ARENAS.md`.
  - Las trampas periódicas (pinchos, vapor, fantasma, rayo) se calculan con el reloj de la partida.
  - Las raíces y el barril los decide el servidor y se mandan con `hazard_event`.
- **Un único golpe para todo:** `apply_hit(victim, attacker, drop_pct, min_drop, max_drop, stun)`, que usan el dash, el alfiler y las trampas. Hace lo de §4.2:
  - suelta doblones en abanico a 60-140 px, y la víctima no los puede recoger durante 0,6 s;
  - aturdido, pierde el combo e invulnerable 1,5 s parpadeando;
  - texto "-N" en rojo, *boing* y sacudida.
  - La Capa Élfica lo bloquea. Si la víctima es invulnerable, no pasa nada.

| Trampa | Qué tiene que pasar |
|---|---|
| Lodo | Velocidad x0,6 mientras estás dentro de la elipse. Gotas de barro al andar |
| Raíces | Cada 6 s, en un punto libre al azar: aviso verde 0,7 s y después atrapan 1 s a quien esté a ≤36 px (no se mueve, pero puede usar el hechizo) y **suelta 2 doblones** |
| Pinchos | Arriba: golpe con `apply_hit` (25 %, mínimo 3, máximo 12). En aviso: solo el brillo rojo |
| Fantasma | Si te toca (radio 22): aturdido 0,6 s y **sueltas 3 doblones**. Después te ignora 2 s |
| Cinta | Empuja a 140 px/s a jugadores y doblones en su dirección |
| Vapor | Cada 4 s: aviso 0,6 s y chorro 0,5 s. A ≤70 px: empujón de 90 px hacia fuera, aturdido 0,3 s y **sueltas 2 doblones** |
| Barril | Si le das con el dash: mecha 0,8 s y explota. A ≤110 px: empujón hacia fuera y **sueltas el 20 % (mínimo 2)**. Vuelve a los 15 s |
| Portal | Entras (radio 22) y sales por su pareja, 30 px hacia fuera en tu dirección. 1 s de espera por jugador. Los doblones no lo cruzan |
| Rayo | Si tu distancia al brazo es menor de 10 + 22 px: golpe con `apply_hit` (25 %) |

- Las cantidades nuevas (raíces 2, vapor 2, barril mínimo 2) van en `GameConfig`. Actualiza la tabla de §4.8 de `AGENTS.md` y la de `ARENAS.md`.
- Cada trampa que te afecta tiene texto ("-N", "¡Atrapado!", "¡Zas!"), sonido y sacudida, como el resto del feedback (§6).
- **Tests:**
  - estados de pinchos y vapor en varios tiempos;
  - distancia punto-segmento del rayo;
  - `apply_hit` respeta la capa, la invulnerabilidad y los límites mínimo y máximo.

## 9e · Texturas de doblones, cofres y hechizos

Usa los sprites de `assets/items/` (cómo se cargan: `ITEMS.md`). Están exportados al doble de tamaño: se dibujan a escala 0,5.

- **Doblón:**
  - `doblon.png` (8 frames a 10 fps), cada doblón con su propio desfase para que no giren todos a la vez.
  - `doblon_sombra.png` en el suelo y un bote suave de 2 px.
  - Los doblones que se sueltan vuelan en arco hasta su sitio.
- **Cofre:** `cofre.png`, frame 0 con un bote suave. Al abrirlo, frames 1-5 en 0,25 s y después desaparece.
- **Hechizos:** `hechizos.png` en la ranura del HUD y en la ruleta.
- Quita los `draw_circle` y `draw_rect` antiguos de doblones y cofres.

## 9f · Marcador visible durante la partida

Tiene que quedar como `docs/media/hud_referencia.png` y §7. Comprueba primero por qué no se ve ahora: la capa del `CanvasLayer`, la arena dibujada encima, el HUD borrado al cambiar de estado…

- El `CanvasLayer` del HUD va con `layer = 10`, por encima de todo lo de la partida.
- **Fichas de jugador** en la franja de arriba, sin tapar la arena:
  - 4 fichas de 280×52 px con `assets/ui/panel.png` en 9-slice, en orden J1-J4 fijo (no se reordenan).
  - Posición x de cada ficha: 8, 294, 706 y 992. Si la arena ya no empieza en y = 60, ajústalo para que no la tapen.
  - En cada ficha:
    - retrato `assets/ui/retrato_<personaje>_<color>.png` a 44 px;
    - nombre y, debajo, "J1 · TÚ", "J2"… en el color del jugador y con su forma ● ▲ ■ ◆;
    - puntos a la derecha en Lilita One 34 px. Al cambiar, el número hace *pop* (escala 1,25 → 1 en 0,15 s) y se pone dorado un momento;
    - la corona (`assets/characters/crown.png`) encima del retrato del líder.
- **Tiempo** arriba en el centro, en Lilita One 44 px. En el Frenesí, dorado y latiendo.
- **Ranura del hechizo** abajo a la izquierda: `ranura.png` con el icono del hechizo y la tecla "E".
- Tiene que funcionar con la escala de UI al 100, 125 y 150 %.

## 9g · Menú principal nuevo y vuelta al menú al acabar

### Menú

Tiene que quedar como `docs/media/menu_referencia.png`.

- **Fondo:** `assets/ui/menu_fondo.png` a pantalla completa (cubriendo). Encima, partículas de polvo lentas y la niebla de la partida, si ya existe.
- **Logo:** `assets/ui/logo.png` arriba en el centro, a unos 560 px de ancho. Entra cayendo con rebote (0,5 s) y después flota ±4 px.
- **Botones:**
  - En columna en el centro, de 340×54 px y separados 12 px.
  - Con `StyleBoxTexture` de `boton.png`, `boton_hover.png` y `boton_pulsado.png` (márgenes en `UI.md`). El foco de teclado y mando usa el estilo hover.
  - Texto en New Rocker 26 px, color hueso, dorado al tener el foco. Un sonido suave al cambiar de foco y al pulsar.
  - Entran uno detrás de otro, con 0,05 s de diferencia.
  - Los botones son:
    1. **JUGAR:** partida VoodooCombo.
    2. **MODO CLÁSICO**
    3. **PERSONAJES:** elegir Brasa, Colmillo, Tuerca o Cripta, con su retrato grande (`portrait_*.png`) y la animación idle. Se guarda en el perfil y es el personaje que usas en la partida. Sustituye a PERSONALIZAR (sombrero, ojos y estela ya no encajan con los sprites).
    4. **AJUSTES**
    5. **HISTORIAL**
    6. **SALIR**
- Abajo a la izquierda, el nivel y la XP. Abajo en el centro, los controles.
- Con "Reducir movimiento", sin animaciones.
- En el menú no se dibuja nada de la arena.

### Fin de partida

1. Cuando el tiempo llega a 0 (o alguien llega a 15 en el modo Clásico): "¡TIEMPO!" durante 1 s.
2. **Pantalla de resultados** sobre un fondo limpio, sin la arena detrás: podio con los personajes, los puntos y los premios.
3. Botones **MENÚ PRINCIPAL** (con el foco) y **¡OTRA!**. Si nadie pulsa nada en 10 s, se vuelve solo al menú.
4. Al volver al menú **se borra toda la partida**: jugadores, doblones, cofres, trampas, textos flotantes, ruleta, temporizadores, nodos y HUD (por ejemplo, en `_end_match_cleanup()`). Lo mismo al salir desde la pausa.
5. El resultado se sigue guardando en el historial y en `/results`, como ahora.

- **Test:** empezar y terminar 3 partidas seguidas deja el mismo número de nodos que al principio, y el menú sin restos.

---

## Al terminar

- Ejecuta los tests en headless (si hay `godot` en el PATH) y arregla lo que falle.
- En `docs/BITACORA.md`, una entrada por bloque con **qué tenemos que probar**, como mínimo:
  - bots contra los muros y en las esquinas durante 2 minutos;
  - todas las trampas de las 4 arenas: avisan, hacen lo de la tabla y quitan doblones;
  - el marcador visible con las 3 escalas de UI;
  - el menú usado solo con teclado y solo con mando;
  - 3 partidas seguidas volviendo al menú.
