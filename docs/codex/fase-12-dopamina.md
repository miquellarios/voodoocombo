# Fase 12 — Dopamina de la buena

> **Para Codex.** Antes tienen que estar terminadas las fases 10 y 11. Después viene la 13 (modos).
> Objetivo: que **cada cosa que hace el jugador se sienta bien**: recoger, robar, esquivar, ganar, subir de nivel.
> Todo lo de esta fase es *feedback* y recompensa. **No cambia las reglas ni los números de la partida.**

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
- Un commit por bloque (`Fase 12a: …`).

---

## 12a · La sensación al pegar y recoger (*game feel*)

- **Parón de golpe (*hitstop*):** la simulación visual se congela 60 ms al acertar un dash, 90 ms si quitas 5 o más doblones y 40 ms con las trampas. Solo la vista: el servidor sigue.
- **Sacudida de cámara** proporcional: 4 px al recoger con x3, 6 px en un golpe, 10 px en una explosión. Decae en 0,15-0,3 s.
- **Golpe de cámara:** zoom de +4 % durante 0,12 s en golpes fuertes y en el "¡VOODOO COMBO!".
- **Squash & stretch:** al recoger, el personaje se aplasta un pelín (escala 1,08 × 0,92 durante 0,08 s). Al aterrizar del dash, lo mismo pero más fuerte.
- **Partículas:** 6 chispas por doblón, polvo al frenar y al dash, y estela del color del jugador.
- **Vibración del mando** (`Input.start_joy_vibration`): suave al recoger con combo, media al golpear, fuerte al recibir. Con interruptor en AJUSTES.

## 12b · Los doblones vuelan a tu marcador

- Al recoger, además del "+N" en el sitio, un doblón pequeño **vuela en arco hasta tu ficha del marcador** (0,35 s). Al llegar, el número de la ficha **sube contando** (no salta), hace *pop* y suena un *tic* metálico.
- **Robo:** los doblones que le quitas a alguien hacen un arco **desde su ficha hasta la tuya** en el marcador. "¡ROBO!" en dorado sobre tu personaje. Al otro, su número baja en rojo.
- Cuantos más doblones seguidos, más agudo el *cling*, un semitono más por cada paso de combo (como dice §6), hasta 12 pasos.

## 12c · El combo como un instrumento

- **Medidor de combo** junto a tu personaje: un anillo que se vacía en 1,5 s.
  - Con x2 es naranja y con x3 rosa.
  - A partir de x3, el personaje lleva un aura de fuego morado (partículas) y la música sube una capa (12e).
- **Subir de multiplicador:** el texto del multiplicador tiembla y cambia de color, y suena un acorde que sube.
- **"¡VOODOO COMBO!"** (al llegar a x3): cartel grande, golpe de cámara, flash corto (si están permitidos) y lluvia de chispas por el borde de la pantalla 1 s.
- **Perder el combo** también se nota, pero sin castigar: el anillo se rompe en trocitos con un *pff* suave. Si era un combo de 10 o más, sale "¡Combo de 14!", en gris, para que sepas lo que habías conseguido.

## 12d · Medallas en plena partida

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

## 12e · Música que reacciona

La música ya es sintetizada (§6). Hazla por capas que entran y salen suavemente (0,5 s):

| Situación | Capas que suenan |
|---|---|
| Base | Tambor y bajo |
| Combo x2 o más | + Percusión rápida |
| Combo x3 | + Melodía |
| Frenesí | Todo un 25 % más rápido y un tono más alto |
| Últimos 10 s | Tambor grave en cada segundo |

- Al ganar, la música se para medio segundo antes del podio, y luego entra la fanfarria. **El silencio antes del premio hace que el premio se note más.**

## 12f · Momentos de tensión

- **Último doblón decisivo:** si en los últimos 5 s el primero y el segundo están a 3 puntos o menos, cámara lenta x0,7 visual, latido de corazón y el marcador de los dos parpadeando.
- **Final de partida:** cámara lenta de 0,5 s en el último segundo, zoom al ganador y explosión de confeti de doblones (§6).
- **Remontada:** si el que gana iba último a mitad de partida, el podio dice "¡REMONTADA!" bajo su nombre.

## 12g · Después de la partida: progreso que se ve

- **Barra de nivel** en el podio, después de los emotes:
  - se llena poco a poco con un *tic* por cada 10 XP;
  - al subir de nivel, la barra explota en chispas y suena una fanfarria corta.
- **Desbloqueo:** si se desbloquea algo, una **caja de la taquilla** (no se compra: se gana jugando) tiembla, se abre con luz y enseña el cosmético nuevo girando. Botones "EQUIPAR" y "SEGUIR".
- **Retos de partida** (3 en la pantalla de carga, como "Roba 6 doblones", "Llega a x3" o "Usa 2 hechizos"):
  - durante la partida, un aviso pequeño cuando cumples uno;
  - cada reto da XP extra al final;
  - se renuevan cada partida, no cada día.

## 12h · Pulir menús y UI

- Cada botón: *hover* con un sonido suave y escala 1,05; al pulsar, se aplasta 0,95 y hace *clack*.
- Las transiciones entre pantallas son un **telón de tela** que se cierra y se abre (0,35 s), no un corte seco.
- El cursor del menú es un **alfiler vudú** (dibujado por código o un sprite pequeño).
- El logo del menú da un latido cada 4 s, con un brillo que le pasa por encima.

---

## Al terminar

- Tests de lo que sea lógica pura: detección de medallas y retos, y la XP que da cada reto.
- En `docs/BITACORA.md`, qué tenemos que probar:
  - que el *hitstop* y la sacudida no mareen;
  - que con "Reducir movimiento" y "Reducir destellos" todo siga siendo claro;
  - que cada medalla salta cuando toca;
  - que la música cambia de capa sin cortes;
  - que la barra de nivel y el desbloqueo se sienten bien.
- Una entrada en `docs/HISTORIA-IA.md`: "Dopamina de la buena: recompensas por habilidad, sin cajas de pago".
