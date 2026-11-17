# Interfaz: menú, botones, marcador

Generado por Claude con `tools/arte/export_ui.py`. Referencias de cómo tiene que quedar: `docs/media/menu_referencia.png` y `docs/media/hud_referencia.png`.

| Archivo | Tamaño (px) | Uso |
|---|---|---|
| `menu_fondo.png` | 1920×1080 | Fondo del menú principal: los 4 personajes con focos y velas. Deja libre la columna central para el logo y los botones |
| `logo.png` | 986×446 | Logo con transparencia. En el menú, a unos 560 px de ancho (scale ≈ 0,57) |
| `boton.png`, `boton_hover.png`, `boton_pulsado.png` | 120×84 | Botón en 9-slice (margen 24): normal, con el ratón o el foco encima, y pulsado |
| `panel.png` | 120×84 | Panel en 9-slice (margen 24): fichas del marcador, cajas de resultados |
| `ranura.png` | 160×160 | Ranura del hechizo del HUD. Dibujar a 80×80 con el icono encima |
| `retrato_<personaje>_<color>.png` | 112×112 | Cabeza en un círculo con el borde del color del jugador, para el marcador. Dibujar a 44-56 px |

Personajes: `mago`, `trol`, `gnomo`, `nigro`. Colores: `coral`, `azul`, `lima`, `hueso` (los mismos que `assets/characters/`).

## Botones con `StyleBoxTexture`

La costura del borde está hecha para repetirse: usa `TILE_FIT` para que no se estire.

```gdscript
static func box(path: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.set_texture_margin_all(24.0)
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	sb.set_content_margin_all(14.0)
	return sb

# En ui/theme_builder.gd:
#   theme.set_stylebox("normal", "Button", box("res://assets/ui/boton.png"))
#   theme.set_stylebox("hover", "Button", box("res://assets/ui/boton_hover.png"))
#   theme.set_stylebox("focus", "Button", box("res://assets/ui/boton_hover.png"))
#   theme.set_stylebox("pressed", "Button", box("res://assets/ui/boton_pulsado.png"))
#   theme.set_stylebox("panel", "PanelContainer", box("res://assets/ui/panel.png"))
```

## Fase 10

`fase10.json` tiene los datos de todo esto.

| Archivo | Tamaño (px) | Uso |
|---|---|---|
| `hechizo_ranura.png` | 192×192 | Ranura nueva del hechizo (aro de oro). Dibujar a 96×96; el icono va en el hueco del centro |
| `hechizo_brillo.png` | 192×192 | Aro de luz encima de la ranura cuando hay un hechizo listo para usar. Late |
| `tecla_e.png`, `tecla_b.png` | 72×72 | Tecla que hay que pulsar: E con teclado, B con mando. Abajo a la derecha de la ranura |
| `emotes.png` | 8 × 128×128 | Emotes en bocadillo: risa, enfado, llanto, corazón, GG, calavera, pulgar, fuego. Pico abajo en (64, 120). Dibujar a 64×64 |
| `marco_<id>.png` | 128×128 | Marcos cosméticos del retrato: madera, hueso, plata, oro, almas |
| `podio.png` | 1080×400 | Los tres bloques del podio. `fase10.json` dice dónde va cada personaje |
| `resultados_fondo.png` | 1920×1080 | Fondo limpio de la pantalla de resultados |
| `zona_niebla.png` | 256×256 | Niebla que se repite sin costuras, para lo que queda fuera de la zona segura |

## Menú de mapas y pantalla de carga

`carga.json` tiene los datos de esto.

| Archivo | Tamaño (px) | Uso |
|---|---|---|
| `arena_<id>_mini.png` | 960×540 | Vista de cada arena con sus trampas (`cienaga`, `cripta`, `taller`, `biblioteca`), para ELIGE ARENA y la pantalla de carga |
| `trampas_iconos.png` | 9 × 128×128 | Un icono por trampa: lodo, raíces, pinchos, fantasma, cinta, vapor, barril, portal, rayo. Dibujar a 48-64 px |
