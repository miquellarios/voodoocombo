# Arte generado por código

Todo el arte de VoodooCombo (personajes, arenas, trampas y tráiler) sale de estos scripts de Python + Cairo.
No hay imágenes de terceros: si se cambia el dibujo, se vuelven a generar los assets.

## Preparar el PC (una vez)

```bash
pip install -r requirements.txt     # en Linux con Python del sistema: añadir --break-system-packages
python3 instalar_fuentes.py         # copia las fuentes de assets/fonts a ~/.fonts
```

Para el tráiler hace falta también `ffmpeg`.

## Qué genera cada script

Se ejecutan desde esta carpeta. Lo generado va a `out/`, que git ignora.

| Script | Qué hace | Salida |
|---|---|---|
| `sprites3.py` | Sprites de los 4 personajes en 4 colores, retratos y corona | `out/godot_sprites/assets/characters/` → copiar a `assets/characters/` |
| `export_arenas.py` | Fondos de las arenas, sprites de las trampas y `arenas.json` | `out/godot_arenas/assets/arenas/` → copiar a `assets/arenas/` |
| `export_ui.py` | Doblón, cofre, iconos de hechizos, logo, fondo del menú, botones, paneles y retratos del marcador | `out/godot_ui/assets/items/` y `assets/ui/` → copiar a `assets/`; referencias en `out/godot_ui/referencias/` |
| `arena_preview.py` | Vista previa de las 4 arenas con personajes | `out/arenas_preview.jpg` |
| `stylesheet3.py` | Hoja de estilo de los personajes (la de la presentación) | `out/` |
| `trailer.py full` | Tráiler completo con música y sonido sintetizados (≈4 min) | `out/VoodooCombo-trailer.mp4` |
| `trailer.py samples 9.6 31.2` | Solo fotogramas sueltos (segundos) para revisar | `out/sample_*.png` |

`SPRITES.md` y `ARENAS.md` (dentro de `assets/`) explican cómo se cargan en Godot.

## Módulos

| Módulo | Contenido |
|---|---|
| `gfx.py` | Colores, fuentes, texto, logo, iconos, curvas de animación |
| `chars.py` | Tela, costuras, botones, alfileres (base de los muñecos) |
| `heroes.py` | Personajes v3: Brasa, Colmillo, Tuerca y Cripta |
| `arenas.py` | Las 4 arenas: mapa, obstáculos y trampas |
| `world.py` | Simulación del tráiler: muñecos, doblones, cámara, HUD |
| `audio.py` | Música y efectos sintetizados |
| `trailer.py` | Escenas del tráiler y render |

## Otros

- `teaser/`: teaser animado en HTML (el primero que se hizo) y `shot.js`, que hace capturas con Playwright.
- `descartados/`: estilos que se probaron y no se eligieron (humanos v4, chibi v5, sprites de prueba).
  Se guardan como registro de `docs/HISTORIA-IA.md` §10. Para ejecutarlos: `PYTHONPATH=. python3 descartados/stylesheet4.py`.
  `stylesheet.py` (estilo v2) sigue en la carpeta principal porque `stylesheet3.py` usa sus funciones.
