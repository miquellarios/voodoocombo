# Fase 12 — Dopamina y modos

> **Para Codex.** Antes de empezar:
> 1. La fase 11 (`docs/codex/fase-11/FASE-11.md`) tiene que estar terminada: `MatchSim`, servidor, salas, lobby y votación funcionando.
> 2. **Copia `docs/codex/fase-12/AGENTS.md` a la raíz como `AGENTS.md`.** Sustituye a la versión de la fase 11. Ya trae:
>    - la regla de "dopamina de la buena";
>    - el *feedback* nuevo (§6);
>    - los modos sin Clásico (§4.6, §4.9 y §4.10).
>
> **Qué entra en esta fase** (12 bloques, en orden, con un commit por bloque):
> - **Parte 1 · Dopamina (12a-12h):**
>   - 12a: *game feel*;
>   - 12b: doblones que vuelan al marcador;
>   - 12c: medidor de combo;
>   - 12d: medallas;
>   - 12e: música por capas;
>   - 12f: momentos de tensión;
>   - 12g: progreso tras la partida;
>   - 12h: pulir menús.
> - **Parte 2 · Modos (12i-12l):**
>   - 12i: quitar el Clásico;
>   - 12j: Último en Pie;
>   - 12k: Codicia 2v2;
>   - 12l: selector de modo.
>
> Todo funciona igual contra bots y en red: la lógica nueva va en `MatchSim` (servidor) y los efectos, en la vista (`Fx` / `Sfx`).
> Las medallas, los retos y los modos los decide el servidor. El *hitstop*, la cámara y la música son solo del cliente.
>
> Referencias: `docs/media/textos_partida_referencia.png` y `assets/ui/medallas.png` (orden en `assets/ui/fase12.json`).

# Parte 1 · Dopamina (12a-12h)

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

Ya está en `AGENTS.md` (versión de la fase 12) como regla de diseño en §1.

**Reglas para todo:**
- Todo pasa por `Fx` y `Sfx`.
- Todo respeta "Reducir movimiento". Añade a AJUSTES un "Reducir destellos" que quite los flashes de pantalla.
- Todos los números nuevos van en `GameConfig`, en un bloque `# Juice`.
- Un commit por bloque (`Fase 12a: <resumen>`).

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
- **Robo:** los doblones que le quitas a alguien hacen un arco **desde su ficha hasta la tuya** en el marcador. "¡ROBO!" en brasa sobre tu personaje. Al otro, su número baja en rojo.
- Cuantos más doblones seguidos, más agudo el *cling*, un semitono más por cada paso de combo (como dice `AGENTS.md` §6), hasta 12 pasos.

## 12c · El combo como un instrumento

- **Medidor de combo** junto a tu personaje: un anillo que se vacía en 1,5 s.
  - Con x2 es hueso y con x3 brasa.
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

## Al terminar la parte 1

- Tests de lo que sea lógica pura: detección de medallas y retos, y la XP que da cada reto.
- En `docs/BITACORA.md`, qué tenemos que probar:
  - que el *hitstop* y la sacudida no mareen;
  - que con "Reducir movimiento" y "Reducir destellos" todo siga siendo claro;
  - que cada medalla salta cuando toca;
  - que la música cambia de capa sin cortes;
  - que la barra de nivel y el desbloqueo se sienten bien.
- Una entrada en `docs/HISTORIA-IA.md`: "Dopamina de la buena: recompensas por habilidad, sin cajas de pago".


# Parte 2 · Modos (12i-12l)

## 12i · Quitar el modo Clásico

- Decisión del equipo: el Clásico desaparece del juego.
- Quita:
  - el botón y la opción de modo;
  - `mode == "classic"` y las constantes `CLASSIC_*`;
  - los textos de I18n;
  - sus tests.
- `AGENTS.md` ya está actualizado en la versión de la fase 12 (§1, §4.6, §4.9 y §4.10): sin Clásico y con los tres modos.
- **`docs/HISTORIA-IA.md`:** añade una entrada "Quitamos el modo Clásico". Qué decidimos: [que lo completen los humanos]. Por qué: [ídem]. Apunta también que la IA avisó de que es el requisito literal del enunciado.
- El endpoint `/results` sigue diciendo el ganador de cada partida.

## 12j · Modo Último en Pie (todos contra todos)

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

## 12k · Modo Codicia 2v2 (por equipos)

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

## 12l · Selector de modo y explicaciones

- En el lobby, al cambiar de modo, sale una tarjeta corta con 3 líneas de reglas y su icono.
- La pantalla de carga (10g) enseña las reglas del modo elegido en vez de las de VoodooCombo cuando toca.
- Al empezar cada partida o ronda, un cartel de 2 s con el objetivo: "¡Sé el último en pie!" / "¡Llena el cofre de tu equipo!".

## Ideas para más adelante (no hacer ahora)

Patata Vudú · Altar (rey de la colina) · Cazador 1v3 · Fútbol Vudú 2v2. Están descritas en el historial de diseño; si sobra tiempo, se hacen igual que estos dos, como modos sobre `MatchSim`.

## Al terminar la parte 2

Ejecuta los tests y escribe en `docs/BITACORA.md` qué tenemos que probar:
- una partida de cada modo contra bots y otra en red;
- cambiar de equipo y de modo en el lobby;
- desconectarse en mitad de una ronda.
