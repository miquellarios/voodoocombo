# Arenas y trampas — VoodooCombo

Fondos y sprites generados por **Claude** por código (Python + Cairo), con el mismo estilo que los personajes. No usan assets de terceros.
`arenas.json` contiene todo lo que necesita el juego: obstáculos, trampas, salidas y reglas.

## Las 4 arenas

| id | Nombre | Trampas |
|---|---|---|
| `cienaga` | Ciénaga Embrujada | Lodo, Raíces |
| `cripta` | Cripta de Huesos | Pinchos, Fantasma |
| `taller` | Taller Gnómico | Cintas transportadoras, Vapor, Barril explosivo |
| `biblioteca` | Biblioteca Arcana | Portales, Rayo arcano |

- **Elección:** cada partida elige una arena al azar, sin repetir la anterior. La semilla de la partida decide cuál.
- **Doblones y cofres:** en casillas libres al azar. Nunca en obstáculos ni en trampas fijas (pinchos, cintas, rejillas de vapor, portales, barriles). Sobre el lodo sí, porque es riesgo y recompensa.
- **Salidas:** de `spawn_sets` se elige uno al azar y se reparte entre los jugadores. La biblioteca solo tiene esquinas, porque el rayo alcanza los centros de los lados.

## Archivos

```
assets/arenas/
  arenas.json            ← mapa de cada arena + info de cada sprite
  <arena>/fondo.png      ← suelo + decoración + lodo + obstáculos ya dibujados (2560×1360)
  trampas/*.png          ← tiras de sprites en horizontal (un frame detrás de otro)
```

- **Coordenadas:** todas las de `arenas.json` están en píxeles del mundo. La arena mide 1200×600 y la casilla, 40 px.
- **Escala:** los PNG están exportados al doble de resolución (`export_scale: 2`), así que los `Sprite2D` y `AnimatedSprite2D` van con `scale = 0.5`.
- **Fondo:** `Sprite2D` con `centered = false`, en `position = (-40, -40)` y con `scale = 0.5`.
- **Obstáculos:** ya están dibujados en el fondo. La colisión es `obstacles[i].hitbox` (`[x, y, ancho, alto]`): la huella del objeto en el suelo, que es lo que se ve. `rect` son las casillas que ocupa y solo sirve para la rejilla de los bots y para no poner doblones encima.

## Cargar una tira de sprites (Godot 4)

```gdscript
static func strip_frames(info: Dictionary, fps: float, loop: bool = true) -> SpriteFrames:
	var tex: Texture2D = load("res://assets/arenas/" + String(info["file"]))
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	sf.set_animation_loop("default", loop)
	var fw := int(info["frame_w"])
	var fh := int(info["frame_h"])
	for i in int(info["frames"]):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame("default", at)
	return sf
```

La información de cada sprite está en `arenas.json → sprites.<nombre>`. Todos van centrados en la posición de la trampa, salvo los pinchos y las cintas, que van en el centro de su casilla.

## Reglas de cada trampa

**Sincronización:** las trampas periódicas (pinchos, vapor, fantasma, rayo) se calculan con el **reloj de la partida**, así que todos los clientes las ven igual sin mandar nada por red. Las que dependen de algo aleatorio o de un jugador (raíces y barril) las decide el **servidor** y las comunica con `hazard_event`.

**Golpe:** cuando una regla dice "cuenta como un golpe", significa lo mismo que el dash: sueltas el 25 % de los doblones (mínimo 3, máximo 12), quedas aturdido 0,4 s, pierdes el combo y quedas invulnerable 1,5 s. La Capa Élfica lo bloquea.

| Trampa | Dónde | Regla | Sprites |
|---|---|---|---|
| **Lodo** | Elipses `center` y `radius` | Mientras estás dentro: velocidad x0,6 | Ya está en el fondo |
| **Raíces** | Punto libre al azar cada 6 s (servidor) | Aviso de 0,7 s y después atrapan 1 s a quien esté a ≤36 px: no se mueve, puede usar el hechizo y suelta 2 doblones | `raices_aviso` (6), `raices_activas` (6) |
| **Pinchos** | Casillas `tiles` | Ciclo `down` 2 s → `warn` 0,6 s → `up` 1 s, con `phase` de desfase. Pisarlos arriba cuenta como un golpe | `pinchos`: frame 0 abajo, 1 aviso, 2 arriba |
| **Fantasma** | Recorre `path` en bucle a 120 px/s | Si toca a alguien (radio 22): aturdido 0,6 s y suelta 3 doblones. Después ignora a ese jugador 2 s | `fantasma` (8, bucle). `flip_h` según la dirección |
| **Cinta** | Casillas `tiles` y dirección `dir` | Empuja a jugadores y doblones a 140 px/s | `cinta` (4 frames por casilla, `flip_h` si dir = -1) y `cinta_rodillo` en los extremos |
| **Vapor** | `center` | Cada 4 s: aviso 0,6 s y chorro 0,5 s. Quien esté a ≤70 px sale empujado 90 px, queda aturdido 0,3 s y suelta 2 doblones | `vapor_rejilla` (fija), `vapor_aviso` (4), `vapor_chorro` (5) |
| **Barril** | `center` | Si lo golpeas con un dash, explota a los 0,8 s. Todos a ≤110 px salen empujados 90 px y sueltan el 20 % de sus doblones (mínimo 2). Reaparece a los 15 s | `barril`, `barril_mecha` (4), `barril_explosion` (6, sin bucle) |
| **Portal** | Parejas `a` y `b` del mismo color | Al entrar (radio 22) apareces en el otro portal. 1 s de espera por jugador. Los doblones no lo cruzan | `portal_cian` y `portal_magenta` (8, bucle) |
| **Rayo** | Orbe en `center` | Dos brazos opuestos de 280 px. Una vuelta cada 8 s. Tocarlo (10 px de grosor) cuenta como un golpe | `rayo_orbe` (4) y `rayo_haz`. El haz empieza en x=6: offset y rotación |

## Prompt para Codex

```
Integra las arenas de assets/arenas según ARENAS.md y arenas.json:
- core/arena_data.gd carga arenas.json. core/arena_gen.gd elige la arena con la semilla (sin repetir la anterior),
  elige las salidas de spawn_sets y coloca los doblones y cofres en casillas libres según las reglas de ARENAS.md.
- La escena de partida pone el fondo, crea las colisiones de los obstáculos y los nodos de cada trampa con sus sprites.
- net/hazards.gd: lógica de las trampas en el servidor. Las periódicas se calculan con el reloj de la partida; raíces y barril
  van como eventos reliable hazard_event(type, data).
- Tests en core/: que ninguna salida, doblón o cofre caiga en un obstáculo o en una trampa fija, y los estados de los ciclos
  de pinchos y vapor en varios tiempos.
Actualiza docs/BITACORA.md y haz commit.
```
