# Sprites de personajes — VoodooCombo

Estos sprites los ha generado **Claude** por código (Python + Cairo), a partir del diseño aprobado: muñecos vudú de arpillera con aspecto de personaje de fantasía.
Es el mismo código de dibujo que el del tráiler, así que el juego y el tráiler se ven igual.
Están hechos para el proyecto; no usan ningún asset de terceros.

## Archivos

| Archivo | Qué es |
|---|---|
| `<personaje>_<color>.png` | Hoja de sprites. Personajes: `mago`, `trol`, `gnomo`, `nigro`. Colores: `coral`, `azul`, `lima`, `hueso` (16 hojas en total) |
| `portrait_<personaje>.png` | Retrato grande (512×640) para el menú, la selección de personaje y el podio |
| `crown.png` | Corona del líder, que se dibuja encima del personaje |
| `characters.json` | Metadatos: tamaño de frame, origen, animaciones, nombres y colores |

## Formato de la hoja

- **Frames:** de 224×256 px.
- **Filas:** cada fila es una animación.
- **Columnas:** cada columna es un frame.
- **Origen:** el punto del personaje que corresponde a su posición en el juego es `(112, 168)` dentro del frame. Los pies quedan en `y ≈ 227`.
- **Orientación:** miran a la derecha; para ir a la izquierda, `flip_h = true`.
- **Escala:** el personaje está dibujado con radio 60 px. En el juego el radio de colisión es de 22 px, así que el `AnimatedSprite2D` va con `scale ≈ 0.37`, o 0.5 si se quiere un poco más grande.

| Animación | Fila | Frames | FPS | Bucle |
|---|---|---|---|---|
| `idle` | 0 | 6 | 6 | sí |
| `walk` | 1 | 8 | 12 | sí |
| `dash` | 2 | 2 | 12 | sí |
| `hurt` | 3 | 2 | 10 | no |
| `win` | 4 | 6 | 10 | sí |

## Cómo cargarlos en Godot 4 (para Codex)

```gdscript
# autoload/char_sprites.gd
extends Node

const DIR := "res://assets/characters/"
var meta: Dictionary = {}
var _cache: Dictionary = {}

func _ready() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "characters.json"))

func frames_for(character: String, color: String) -> SpriteFrames:
	var key := character + "_" + color
	if _cache.has(key):
		return _cache[key]
	var sheet: Texture2D = load(DIR + key + ".png")
	var fw := int(meta["frame_w"])
	var fh := int(meta["frame_h"])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim_name in meta["animations"]:
		var a: Dictionary = meta["animations"][anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(a["fps"]))
		frames.set_animation_loop(anim_name, bool(a["loop"]))
		for i in int(a["frames"]):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * fw, int(a["row"]) * fh, fw, fh)
			frames.add_frame(anim_name, at)
	_cache[key] = frames
	return frames
```

Uso en el jugador:

```gdscript
@onready var sprite: AnimatedSprite2D = $Sprite

func setup_look(character: String, color: String) -> void:
	sprite.sprite_frames = CharSprites.frames_for(character, color)
	sprite.centered = false
	sprite.offset = Vector2(-112, -168)   # el origen del frame queda en la posición del jugador
	sprite.scale = Vector2(0.37, 0.37)
	sprite.play("idle")
```

- `walk` cuando se mueve; `idle` cuando está quieto.
- `dash` durante el dash y `hurt` al recibir un golpe.
- `win` en el podio.
- `flip_h` según la dirección horizontal.

## Personajes y colores

- **El personaje es un cosmético:** se elige en Personalizar y viaja en `request_join`.
- **El color depende del jugador:** J1 coral, J2 azul, J3 lima, J4 hueso.
- **Combinaciones:** cualquier personaje puede salir con cualquier color, porque hay una hoja para cada combinación.

| id | Nombre | Rol |
|---|---|---|
| `mago` | Brasa | Mago del fuego |
| `trol` | Colmillo | Trol del pantano |
| `gnomo` | Tuerca | Gnomo inventor |
| `nigro` | Cripta | Nigromante |
