#!/usr/bin/env python3
"""Miniaturas de las arenas (menú de mapas y pantalla de carga) e iconos de las trampas.
Uso: python3 export_carga.py [carpeta_salida]   (por defecto out/godot_carga; copiar su assets/ a la raíz del proyecto)"""
import cairo, json, math, os, sys
from gfx import *
from arenas import *

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_carga'
UI = os.path.join(OUT, 'assets', 'ui'); os.makedirs(UI, exist_ok=True)
DARK = hexc('#0B0710')


def arena_mini(aid, path, w=960, h=540):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h); c = cairo.Context(s)
    c.set_source_rgba(*DARK); c.paint()
    sc = w / (AW + 2 * PAD); c.scale(sc, sc); c.translate(PAD, PAD + (h / sc - AH - 2 * PAD) / 2)
    draw_static(c, aid, 0.0, with_obstacles=False)
    draw_hazards(c, aid, 2.2, demo=True, layer='ground')
    draw_obstacles(c, aid, 0.0)
    draw_hazards(c, aid, 2.2, demo=True, layer='top')
    s.write_to_png(path)


TRAPS = ['lodo', 'raices', 'pinchos', 'fantasma', 'cinta', 'vapor', 'barril', 'portal', 'rayo']


def trap_icon(c, kind):
    c.arc(64, 64, 58, 0, 2 * math.pi); fill_stroke(c, hexc('#241838'), DARK, 6)
    c.save(); c.arc(64, 64, 54, 0, 2 * math.pi); c.clip()
    if kind == 'lodo':
        hz_lodo(c, dict(x=1.6, y=1.6, rx=1.2, ry=0.75), 0.3, static=False)
    elif kind == 'raices':
        hz_raices(c, 64, 78, 'active', 0.6, r=40)
    elif kind == 'pinchos':
        c.translate(22, 22); c.scale(2.1, 2.1); hz_pincho_tile(c, 0, 0, 'up')
    elif kind == 'fantasma':
        c.translate(64, 64); c.scale(1.5, 1.5); hz_fantasma(c, 0, 0, 0.0, 1)
    elif kind == 'cinta':
        c.translate(-12, 44); hz_cinta(c, dict(tiles=[(0, 0), (1, 0), (2, 0), (3, 0)], dir=(1, 0), speed=140), 0.2)
    elif kind == 'vapor':
        c.translate(64 - 80 * 0.8, 70 - 80 * 0.8); c.scale(0.8, 0.8); hz_vapor(c, dict(x=2.0, y=2.0, radius=70), 'blast', 0.35)
    elif kind == 'barril':
        c.translate(64 - 120 * 1.3, 66 - 120 * 1.3); c.scale(1.3, 1.3); hz_barril(c, dict(x=3.0, y=3.0, radius=110), 'fuse', 0.3, 0.1)
    elif kind == 'portal':
        c.translate(64, 64); c.scale(1.35, 1.35); hz_portal(c, 0, 0, '#7FE7FF', 0.5)
    elif kind == 'rayo':
        c.translate(64 - 80 * 0.3, 64 - 80 * 0.3); c.scale(0.3, 0.3); hz_rayo(c, dict(x=2.0, y=2.0, length=280, period=8.0, arms=2), 1.0)
    c.restore()


def main():
    for aid in ORDER:
        arena_mini(aid, os.path.join(UI, f'arena_{aid}_mini.png'))
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 128 * len(TRAPS), 128); c = cairo.Context(s)
    for i, k in enumerate(TRAPS):
        c.save(); c.translate(i * 128, 0); trap_icon(c, k); c.restore()
    s.write_to_png(os.path.join(UI, 'trampas_iconos.png'))
    meta = {"arena_mini": {"file": "arena_<id>_mini.png", "size": [960, 540], "ids": ORDER,
                           "note": "Vista de la arena con sus trampas, para el menú de mapas y la pantalla de carga."},
            "trampas_iconos": {"file": "trampas_iconos.png", "frame_w": 128, "frame_h": 128, "frames": len(TRAPS), "order": TRAPS,
                               "note": "Un icono por trampa, para la pantalla de carga y CÓMO SE JUEGA. Dibujar a 48-64 px."}}
    with open(os.path.join(UI, 'carga.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    print('ok', OUT)


if __name__ == '__main__':
    main()
