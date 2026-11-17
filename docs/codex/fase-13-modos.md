# Fase 13 — Quitar el Clásico y dos modos nuevos

> **Para Codex.** Antes tienen que estar terminadas las fases 10, 11 y 12 (dopamina). Los modos funcionan contra bots y en red, porque van sobre `MatchSim`.
> En el lobby, el anfitrión elige el modo con las flechas ‹ ›.

## 13a · Quitar el modo Clásico

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

## 13b · Modo Último en Pie (todos contra todos)

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

## 13c · Modo Codicia 2v2 (por equipos)

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

## 13d · Selector de modo y explicaciones

- En el lobby, al cambiar de modo, sale una tarjeta corta con 3 líneas de reglas y su icono.
- La pantalla de carga (10g) enseña las reglas del modo elegido en vez de las de VoodooCombo cuando toca.
- Al empezar cada partida o ronda, un cartel de 2 s con el objetivo: "¡Sé el último en pie!" / "¡Llena el cofre de tu equipo!".

## Ideas para más adelante (no hacer ahora)

Patata Vudú · Altar (rey de la colina) · Cazador 1v3 · Fútbol Vudú 2v2. Están descritas en el historial de diseño; si sobra tiempo, se hacen igual que estos dos, como modos sobre `MatchSim`.

## Al terminar

Ejecuta los tests y escribe en `docs/BITACORA.md` qué tenemos que probar:
- una partida de cada modo contra bots y otra en red;
- cambiar de equipo y de modo en el lobby;
- desconectarse en mitad de una ronda.
