# VoodooCombo — Prompts para Codex

## Antes de empezar

1. **En el repo:** descomprimid el kit en la raíz (`AGENTS.md` y la carpeta `docs/`) y haced commit. Codex lee `AGENTS.md` solo.
2. **Codex en el PC** (VS Code o terminal), no en la web, porque la web no puede ejecutar Godot.
3. **Godot en el PATH:** poned el ejecutable de consola (`Godot_v4.x-stable_win64_console.exe`) con el nombre `godot`, para que Codex pueda pasar los tests.
4. **Fuentes:** descargad **Lilita One** y **Baloo 2** de Google Fonts y ponedlas en `assets/fonts/`.
5. **Ritmo de trabajo:** una fase cada vez. Probad con F5, apuntad en la bitácora y pasad a la siguiente.
6. **Multijugador en un solo PC:** Debug → Customize Run Instances → 2 a 4 instancias. En versiones antiguas es "Run Multiple Instances".

---

## Fase 0 — Plan (sin código)

```
Lee AGENTS.md, docs/DISENO.md y project.godot. No escribas código todavía.
Dime: la versión de Godot que detectas, el plan de las fases 1 a 8 con los archivos de cada una,
los riesgos técnicos (sincronización en tiempo real, modo anfitrión, latencia al recoger doblones)
y cualquier cosa ambigua de AGENTS.md.
Añade este plan en docs/BITACORA.md (sección "Registro de Codex"; la plantilla ya existe) y haz commit "Fase 0: plan".
```

## Fase 1 — Lógica pura y tests

```
Fase 1: implementa core/ según AGENTS.md, sin escenas ni red.
- game_config.gd con todas las constantes de AGENTS.md.
- arena_gen.gd: arena 30x15 con semilla, obstáculos con simetría en espejo, BFS sin zonas cerradas,
  salidas aleatorias (4 esquinas o 4 centros de lado), 50 doblones iniciales separados al menos 35 px,
  bioma = seed % 4.
- Los dos modos de AGENTS.md §4.6 (VoodooCombo y Clásico) como configuraciones de game_config.gd.
- scoring.gd: combo (ventana de 1,5 s), multiplicador x1–x4, valor del doblón con Frenesí y Anillo,
  cantidad que se suelta al recibir un golpe (25 % / 35 % con corona / 40 % con Anillo, mínimo 3 y máximo 12).
- item_table.gd: tirada de hechizo con RNG según la posición (tabla de AGENTS.md; con 2 jugadores, solo primero y último).
- ranking.gd: clasificación, desempate por combo máximo y reparto de premios.
Tests en tests/ con un runner propio que extienda SceneTree: simetría y conectividad de la arena,
umbrales de combo, valores con Frenesí y Anillo, mínimo y máximo de robo, que el líder nunca reciba Oveja,
que las probabilidades sumen 100, desempates y premios, y en Clásico: victoria al llegar a 15 y que no salga el Anillo.
Ejecuta los tests, actualiza docs/BITACORA.md y haz commit.
```

## Fase 2 — Partida local con bots (que sea divertido antes de la red)

```
Fase 2: una partida completa en un solo PC: tú contra 1-3 bots. Todavía sin red,
pero la lógica de partida tiene que estar ya en un nodo "servidor" local, para que en la fase 3 solo cambie el transporte.
- Arena dibujada con _draw() (suelo de dos tonos, obstáculos con contorno).
- Muñecos sencillos (círculo de color con ojos de botón y su forma ● ▲ ■ ◆), con movimiento y colisiones.
- Dash con golpe y robo: los doblones salen en abanico; aturdimiento e invulnerabilidad parpadeando.
- Doblones que aparecen, combo con multiplicador y número flotando junto al muñeco.
- Cofres, ruleta y los 7 hechizos de AGENTS.md. Corona al líder. Frenesí en los últimos 15 s.
- HUD de 3 elementos, cuenta atrás inicial, "¡Eres el Jugador N!" con flecha, final y un podio simple con el botón ¡Otra!.
- Los dos modos: VoodooCombo y Clásico (primero en 15 de 50 doblones).
- Bots según AGENTS.md (net/bot_brain.gd).
En docs/BITACORA.md: qué probar y qué valores de game_config.gd creéis que habrá que ajustar. Commit.
```

## Fase 2b — Personajes y arenas (assets)

```
Fase 2b: integra los assets que ya están en el repo.
- Personajes: autoload CharSprites tal como está en assets/characters/SPRITES.md. El jugador usa un AnimatedSprite2D
  (idle, walk, dash, hurt, win) con flip_h según la dirección. La forma ● ▲ ■ ◆ se dibuja debajo con _draw().
- Arenas: sigue el prompt de assets/arenas/ARENAS.md (arena_data, arena_gen, colisiones, trampas en net/hazards.gd).
- Añade la niebla y el parpadeo de las velas por encima de la arena.
Tests, docs/BITACORA.md y commit.
```

## Fase 3 — Multijugador en red

```
Fase 3: multijugador real de 2 a 4 jugadores según la sección 5 de AGENTS.md. Reutiliza la partida de la fase 2.
- Autoload Net: Crear sala, Unirse por IP, servidor dedicado (--server, headless).
- lan_discovery.gd: lista de salas en la red local.
- Movimiento de cada cliente en local, enviado 20 veces por segundo, con la validación de velocidad máxima.
  Snapshots del servidor 20 veces por segundo e interpolación de 100 ms para los demás.
- El servidor decide doblones, cofres, golpes, hechizos, puntos y tiempo, y lo comunica con eventos reliable.
- Sala de espera: jugadores con su color, forma y "Jugador N"; botón Listo; el anfitrión (master) elige el modo
  y la duración y pulsa Empezar. Los bots pueden rellenar los huecos.
- match_over con ranking y premios para todos; revancha; desconexiones según AGENTS.md.
- Guardado en user://matches/ y endpoint HTTP: GET /status, GET /results y GET / (página con marcador en directo).
En docs/BITACORA.md explica cómo probarlo en 1 PC, en 2 PCs y con el servidor dedicado. Commit.
```

## Fase 4 — Dopamina: juice y sonido

```
Fase 4: implementa TODA la tabla de la sección 6 (Feedback obligatorio) de AGENTS.md.
- Autoload Fx: textos flotantes, partículas con pool, vibración de pantalla, parón de impacto y cámara lenta.
  Todo respeta "Reducir movimiento".
- Autoload Sfx: todos los sonidos sintetizados como AudioStreamWAV. El cling del combo sube de semitono en
  semitono. Bucle de música que acelera en Frenesí.
- Ruleta del cofre con giro, tics y ding; fanfarria y rayos si sale el Anillo.
- Cartel de Frenesí, borde dorado, lluvia de doblones y cuenta atrás gigante en los últimos 5 s.
- Final con cámara lenta, confeti y baile del ganador.
Cada acción tiene que responder en menos de 100 ms. En docs/BITACORA.md: lista de efectos y cómo comprobar cada uno. Commit.
```

## Fase 5 — Estética

```
Fase 5: identidad visual según la sección 7 de AGENTS.md.
- ui/theme_builder.gd: Theme en código con la paleta oscura de AGENTS.md §7, botones que rebotan al pasar por encima
  y se aplastan al pulsar, y fuentes New Rocker (títulos) / Lilita One (números) / Baloo 2 (texto).
- Personajes: ya son sprites. Añade bote al andar y estiramiento en el dash con la escala del nodo (no los redibujes).
- Arenas: ya son assets. Añade la viñeta, la niebla y las luces de las velas por encima.
- Doblones que giran y brillan; cofres que flotan y brillan.
- Menú principal: logo VOODOO COMBO con letras que se mueven, botón JUGAR enorme (foco inicial) y tu
  muñeco bailando.
- Lobby jugable: en la sala de espera ya puedes moverte y hacer dash.
En docs/BITACORA.md describe el antes y el después. Commit.
```

## Fase 6 — Podio, premios y progresión

```
Fase 6:
- Podio animado: los muñecos suben a sus escalones, la corona cae sobre el ganador y los premios
  aparecen uno a uno con sonido.
- Autoload Profile (user://profile.cfg): nick (con generador aleatorio "Sustantivo + Adjetivo"),
  cosméticos, XP y estadísticas.
- XP por partida: 50 por jugar + 30 / 20 / 10 por quedar 1º / 2º / 3º + el combo máximo. Un nivel cada 300 XP.
  Cada nivel desbloquea un cosmético. La barra de XP se llena con tics en el podio.
- Pantalla Personalizar: sombrero, ojos, estela y baile, con una vista previa grande. Los cosméticos
  viajan en request_join y los demás los ven.
- Pantalla Historial: lista de las partidas guardadas en user://matches (fecha, modo, ganador, ranking y premios).
Actualiza docs/BITACORA.md y haz commit.
```

## Fase 7 — Accesibilidad y pulido

```
Fase 7: repasa todo el juego.
- Teclado y mando en todos los menús, con el foco siempre visible.
- Formas ● ▲ ■ ◆ en todas partes donde aparezca un jugador.
- Reducir movimiento, escala de UI y volúmenes. Textos completos en es, ca y en.
- Errores claros: no se puede conectar, versión distinta, sala llena.
- Primera vez que se juega: una pantalla "Cómo se juega" con 3 iconos (recoge, encadena, golpea) que se puede saltar.
Lista los cambios en docs/BITACORA.md y haz commit.
```

## Fase 8 — Entrega

```
Fase 8: revisión final.
- Busca y arregla bugs en estos casos: dos jugadores cogen el mismo doblón a la vez, golpe durante la
  ruleta, desconexión en Frenesí, revancha con alguien que se ha ido, partida con solo bots.
- README.md: qué es, controles, los dos modos, cómo crear sala y unirse, servidor dedicado, endpoint HTTP y capturas.
- Preset de exportación para Windows.
- Repasa la matriz de requisitos de docs/PLAN.md y dime, punto por punto, dónde se cumple cada uno en el código.
- Cierra docs/BITACORA.md con un resumen: tecnologías usadas, qué funcionó a la primera y qué hubo que reformular.
Commit "Fase 8: entrega".
```

---

## Prompt de ajuste de sensación (después de jugar)

```
Hemos jugado [n] partidas. Sensaciones: [ej. "el dash se queda corto", "el combo se pierde demasiado
pronto", "el Anillo sale demasiado"].
Propón cambios SOLO en game_config.gd, con el valor de antes y el de después y el motivo de cada uno.
No toques la lógica. Anótalo en docs/BITACORA.md.
```

## Cuando algo falla

```
Al hacer [qué hice] pasa [qué pasa] y esperaba [qué esperaba].
Error del panel Output:
[pegar el error]
Busca la causa raíz antes de tocar código y explícamela en 2-3 líneas.
Arregla la causa, no el síntoma. Si el fallo está en core/, añade un test. Anótalo en docs/BITACORA.md.
```

## Bitácora: lo que tenéis que apuntar vosotros

| Fecha | Fase | Prompt (resumen) | ¿Funcionó a la primera? | Qué reformulamos y por qué | Qué investigamos por nuestra cuenta |
|---|---|---|---|---|---|
| | | | | | |

**Temas que conviene entender bien antes de la presentación:**
- RPC reliable y unreliable en ENet.
- Por qué el servidor es autoritativo pero el movimiento lo calcula cada cliente.
- Interpolación de snapshots.
- La generación simétrica de la arena.
- El endpoint HTTP con `TCPServer`.
