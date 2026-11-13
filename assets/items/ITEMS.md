# Objetos: doblones, cofres e iconos de hechizos

Generados por Claude con `tools/arte/export_ui.py` (mismo dibujo que el tráiler). No son assets de terceros.
Están exportados **al doble de tamaño**: se dibujan a escala 0,5. `items.json` tiene los mismos datos.

| Archivo | Frame (px) | Frames | Uso |
|---|---|---|---|
| `doblon.png` | 64×64 | 8 · 10 fps · bucle | El doblón girando. El centro del frame es el centro del doblón |
| `doblon_sombra.png` | 64×24 | 1 | Sombra en el suelo, 11 px por debajo del centro del doblón |
| `cofre.png` | 224×256 | 6 · 20 fps · sin bucle | 0 cerrado · 1-4 abriéndose · 5 abierto. El cofre se apoya 16 px por debajo del centro del frame |
| `hechizos.png` | 128×128 | 7 | Iconos en el orden de `ITEMS`: magnet, boots, cloak, pin, frost, sheep, ring |

## Dibujarlos desde `_draw()`

```gdscript
const COIN_TEX := preload("res://assets/items/doblon.png")
const COIN_SHADOW := preload("res://assets/items/doblon_sombra.png")
const CHEST_TEX := preload("res://assets/items/cofre.png")
const SPELL_TEX := preload("res://assets/items/hechizos.png")

# Dibuja el frame `frame` de una tira horizontal, centrado en `pos`, a escala 0,5.
func draw_strip_frame(tex: Texture2D, frame_size: Vector2, frame: int, pos: Vector2, scale: float = 0.5) -> void:
	var src := Rect2(Vector2(frame * frame_size.x, 0.0), frame_size)
	var size := frame_size * scale
	draw_texture_rect_region(tex, Rect2(pos - size * 0.5, size), src)

# Doblón: cada uno con su desfase (phase) para que no giren todos a la vez.
#   var f := int(elapsed * 10.0 + coin.phase) % 8
#   draw_texture_rect(COIN_SHADOW, Rect2(coin.pos + Vector2(-16, 5), Vector2(32, 12)), false)   # sombra a escala 0,5
#   draw_strip_frame(COIN_TEX, Vector2(64, 64), f, coin.pos + Vector2(0, -2.0 * abs(sin(elapsed * 3.0 + coin.phase))))
```

Con nodos también vale: `AnimatedSprite2D` con un `SpriteFrames` hecho de `AtlasTexture` (igual que en `assets/arenas/ARENAS.md`) y `scale = 0.5`.
