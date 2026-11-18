# Historia del diseño con IA

> Hacia dónde nos llevó la IA y qué decidimos nosotros. Es la base de la diapositiva 5 de la presentación.
> Formato de cada entrada: **qué pedimos → qué propuso la IA → qué decidimos → por qué**.
> Lo que va entre [corchetes] lo tenéis que completar vosotros.

## Línea de tiempo

```
1 Especificación inicial ─► 2 Nombre y cartas ─► 3 Pulido visual ─► 4 Cambio a Godot
       │
       ▼
5 Turnos tipo ajedrez ─► 6 Ajedrez modular ✗ ─► 7 Simple y con dopamina ✓ ─► 8 Revisión contra el enunciado
       │
       ▼
9 Tráiler ─► 10 Estilo visual (5 versiones, v3 ✓) ─► 11 Sprites para Godot ─► 12 Arenas con trampas
```

---

### 1 · Especificación inicial
- **Herramienta:** [con qué IA se hizo el PDF].
- **Qué teníamos:** un documento de arquitectura con un prompt maestro para Codex.
  - Arena 1v1 en tiempo real con Node.js, Socket.io y Canvas 2D.
  - 50 monedas en el mapa; gana el primero en llegar a 15.
  - Endpoint `POST /api/match/finish`.
  - 7 cartas de habilidad, cofres de oro y de bronce, y mejoras de cartas.
- **Decisión:** usarlo como punto de partida.
- **Ojo:** la "bitácora de errores" del PDF describía fallos que todavía no habían pasado. No es real (ver `PLAN.md` §5).

### 2 · Nombre y universo ⭐
- **Pedimos (Claude):** el juego se llamará *VoodooCombo*; cartas inspiradas en El Señor de los Anillos, Magic y World of Warcraft, "las justas".
- **Propuso:**
  - 14 cartas en 4 rarezas con **nombres propios**, inspirados pero sin copiar marcas, para evitar problemas de propiedad intelectual.
  - 3 combos para que el nombre tenga sentido en el juego.
- **Decidimos:** aceptarlo.
- **Por qué:** [vuestras palabras].

### 3 · Pulido visual
- **Pedimos:** darle muchas vueltas al diseño (avatares, personalización, "tonterías que marquen la diferencia"), en Markdown para pasárselo al compañero.
- **Propuso:**
  - Una guía de diseño con muñecos vudú de trapo dibujados por código y personalización por partes.
  - Juice, sonido sintetizado y accesibilidad.
  - Prioridades MVP / pulido / extra y prompts por bloques.
- **Decidimos:** quedarnos la identidad de muñeco vudú y la idea del juice.
- **Por qué:** [vuestras palabras].

### 4 · Cambio de tecnología a Godot ⭐
- **Decidimos nosotros:** trabajar con Godot; el compañero lo sube a GitHub y programa con Codex.
- **Qué aportó la IA:**
  - Explicó que un proyecto de Godot son archivos de texto que un agente puede escribir.
  - Propuso el multijugador integrado de Godot (ENet) en lugar de Node y Socket.io, con el propio servidor del juego haciendo de endpoint.
  - Propuso un flujo con GitHub y pull requests.
- **Por qué cambiamos:** [motivo real].
- **Tecnología que investigar:** ENet y las RPC de Godot (`INVESTIGACION.md`).

### 5 · Partidas rápidas con "flow de ajedrez"
- **Idea nuestra:** cartas, partidas rápidas pero con ritmo de ajedrez.
- **Propuso:**
  - Turnos en un tablero 9×9 simétrico, reloj de ajedrez y cartas de movimiento que se mueven como piezas.
  - Introdujo **`AGENTS.md`**: un archivo de directrices que Codex lee solo, más prompts cortos por fases.
- **Decidimos:** aceptarlo de forma provisional.
- **Lo que nos quedamos:** la forma de trabajar con `AGENTS.md` y las fases.

### 6 · Ajedrez modular con progresión y poderes ✗ ⭐
- **Idea nuestra:** una propuesta con 4 ejes (recurso de energía, personalización previa, categorías de poderes y control del ritmo).
- **Propuso:**
  - 3 configuraciones por capas, energía de 0 a 10 y ejércitos de 32 puntos.
  - 5 escuelas de magia y 27 rasgos.
  - Mecánicas de ritmo: Luna de Sangre y Marea Vudú.
- **Decidimos:** **descartarlo**.
- **Por qué:** demasiado complejo; no se entiende en 5 segundos y "lo simple es lo que llama a jugar".
- **Aprendizaje:** la IA amplía sin límite lo que le pides. Poner límites es trabajo nuestro.

### 7 · Simple y con dopamina ✓ ⭐
- **Pedimos:** simplificar; juegos de referencia con mucha dopamina y un diseño visual sencillo y llamativo.
- **Propuso:**
  - Un party game de 90 s.
  - Referencias concretas: Mario Kart (cofres con ruleta, concha azul), Sonic (doblones que saltan), Peggle y Balatro (combo que sube), Brawl Stars (corona), Fall Guys (podio y revancha), Among Us (silueta).
  - Reglas visuales y un `AGENTS.md` nuevo.
- **Decidimos:** este es el diseño definitivo.
- **Por qué:** [vuestras palabras].

### 8 · Revisión contra el enunciado
- **Pedimos:** tener en cuenta el enunciado y preparar un buen trabajo.
- **Propuso:**
  - Una matriz de requisitos.
  - **Modo Clásico** (literal del enunciado: 15 de 50 doblones), 50 doblones iniciales, salidas aleatorias y "¡Eres el Jugador N!".
  - Una página web en el endpoint e historial de partidas.
  - Plan de documentación, de presentación y de demo.
- **Decidimos:** [completad].

### 9 · Tráiler conceptual
- **Pedimos:** un tráiler del juego.
- **Propuso:**
  - Primero un teaser animado en el navegador para verlo en el móvil.
  - Después un tráiler de 42 s en MP4, generado por código (Python + Cairo para la imagen y sonido sintetizado), con la etiqueta "Tráiler conceptual".
- **Decidimos:** [completad].

### 10 · Dirección visual: 5 versiones de personajes ⭐
| Versión | Qué propuso la IA | Qué dijimos |
|---|---|---|
| v1 | Muñecos simples y brillantes, letras Lilita One | Demasiado simple: "algo más oscuro" |
| v2 | Muñecos de arpillera oscuros con costuras, dos opciones de logo | "Como trolls, gnomos, magos… referencias de WoW" |
| **v3** | Muñecos vudú de fantasía: mago, trol, gnomo, nigromante (diseños y nombres propios, sin copiar a Blizzard) | **Elegido** ✓ |
| v4 | Personajes humanoides | Al compañero no le gustó ✗ |
| v5 | Chibi que mezcla los dos | Descartado: nos quedamos con v3 |
- **Aprendizaje:** la IA itera muy rápido sobre lo visual. La decisión de estilo fue del equipo.

### 11 · Sprites para Godot ⭐
- **Pregunta del compañero:** ¿puede la IA usar las imágenes para crear los modelos en Godot, o hacerlos ella misma?
- **Propuso:** en vez de pedirle a Codex que copie las imágenes (saldría peor), generar los sprites con el mismo código que el tráiler.
  - 4 personajes × 4 colores.
  - 5 animaciones cada uno.
  - Metadatos en JSON y una guía con el código de carga en Godot.
- **Decidimos:** [completad].

### 12 · Arenas con trampas
- **Pedimos:** más arenas para no jugar siempre en la misma, con trampas y cosas por el mapa.
- **Propuso:** 4 arenas (Ciénaga, Cripta, Taller, Biblioteca), cada una con su decoración y 2-3 trampas que siempre avisan antes de hacer daño.
  - Las trampas periódicas se calculan con el reloj de la partida, así que no hace falta sincronizarlas por red.
  - Exportó fondos, sprites y un `arenas.json` con el mapa.
- **Decidimos:** [completad].

---

## Lo que hemos aprendido (borrador, revisadlo y hacedlo vuestro)
- Cuanto más abierta es la petición, más complejidad propone la IA. Hay que pedirle límites ("las justas", "que se entienda en 5 s").
- Cambiar de tecnología o de diseño fue barato porque todavía no había código. Iterar el diseño **antes** de programar ahorra tiempo.
- Tener las directrices en un archivo permanente (`AGENTS.md`) evita repetir el contexto en cada prompt.
- [lo que aprendáis programando con Codex]

---

## Plantilla para las siguientes entradas

```
### N · Título
- Pedimos (herramienta):
- Propuso:
- Decidimos:
- Por qué:
```

## Dopamina de la buena: recompensas por habilidad, sin cajas de pago
La implementación premia combos, acciones y retos de cada partida. No introduce compras, rachas diarias ni notificaciones externas. Los retos y medallas se deciden en la simulación autoritativa.
