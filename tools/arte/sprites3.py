"""Exporta los personajes como hojas de sprites para Godot (mismo código de dibujo que el tráiler)."""
import cairo, json, math, os, sys
from gfx import *
from heroes import draw_hero as draw_human, KINDS, HERO_NAME, HERO_ROLE, PCOL3 as PCOL4
from world import Doll

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_sprites'
CHAR_DIR = os.path.join(OUT, 'assets', 'characters')
os.makedirs(CHAR_DIR, exist_ok=True)

R = 60                      # radio de dibujo dentro del sprite
FW, FH = 224, 256           # tamaño de cada frame
CX, CY = 112, 168           # centro del muñeco dentro del frame (los pies quedan en y≈227)
COLORS = ['coral', 'azul', 'lima', 'hueso']
T_IDLE = 2 * math.pi / 3.4
WALK_CYCLE = 2 * math.pi / 0.11

ANIMS = [  # nombre, frames, fps, loop
    ('idle', 6, 6, True),
    ('walk', 8, 12, True),
    ('dash', 2, 12, True),
    ('hurt', 2, 10, False),
    ('win', 6, 10, True),
]


def make_doll(kind_i, col_i):
    d = Doll(kind_i); d.kind = KINDS[kind_i]; d.col = PCOL4[col_i]; d.r = R; d.marker = False
    d.x, d.y = CX, CY; d.look = (0.3, 0.25); d.blink_off = 99.0
    return d


def pose(d, anim, i, n):
    d.vx = d.vy = 0.0; d.walk = 0.0; d.squash = 0.0; d.tilt = 0.0; d.flash_until = -9; d.y = CY; d.face = 1
    t = 0.0
    if anim == 'idle':
        t = i * T_IDLE / n
        d.blink_off = (0.03 - t) % 3.3 if i == 4 else 99.0
    elif anim == 'walk':
        d.vx = 140.0; d.walk = i * WALK_CYCLE / n; t = i * 0.08
    elif anim == 'dash':
        d.vx = 900.0; d.squash = -0.04 if i == 0 else 0.02; t = i * 0.08
    elif anim == 'hurt':
        d.flash_until = 99 if i == 0 else -9; d.tilt = -0.18 if i == 1 else -0.08; d.squash = 0.12 if i == 1 else 0.0; t = 0.3
    elif anim == 'win':
        u = i / n
        d.y = CY - abs(math.sin(math.pi * u * 2)) * R * 0.3
        d.squash = 0.1 * math.cos(math.pi * u * 4); d.tilt = 0.1 * math.sin(math.pi * u * 2); t = u
    return t


def render_sheet(kind_i, col_i):
    cols = max(a[1] for a in ANIMS)
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, FW * cols, FH * len(ANIMS))
    ctx = cairo.Context(surf)
    d = make_doll(kind_i, col_i)
    for row, (anim, n, fps, loop) in enumerate(ANIMS):
        for i in range(n):
            t = pose(d, anim, i, n)
            ctx.save(); ctx.rectangle(i * FW, row * FH, FW, FH); ctx.clip()
            ctx.translate(i * FW, row * FH)
            draw_human(ctx, d, t, 0.0)
            ctx.restore()
    path = os.path.join(CHAR_DIR, f"{KINDS[kind_i]}_{COLORS[col_i]}.png")
    surf.write_to_png(path)
    return path


def render_portrait(kind_i):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 512, 640); ctx = cairo.Context(s)
    d = make_doll(kind_i, kind_i); d.r = 140; d.x, d.y = 256, 420
    draw_human(ctx, d, 0.0, 0.0)
    path = os.path.join(CHAR_DIR, f"portrait_{KINDS[kind_i]}.png"); s.write_to_png(path)


def render_crown():
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 96, 72); ctx = cairo.Context(s)
    draw_crown(ctx, 48, 40, 76)
    s.write_to_png(os.path.join(CHAR_DIR, 'crown.png'))


def main():
    for k in range(4):
        for c in range(4):
            render_sheet(k, c)
        render_portrait(k)
    render_crown()
    meta = {
        "frame_w": FW, "frame_h": FH,
        "origin": {"x": CX, "y": CY, "note": "punto del muñeco que corresponde a su posición en el juego (pies en y≈227)"},
        "draw_radius_px": R,
        "files": "assets/characters/<personaje>_<color>.png",
        "characters": {KINDS[k]: {"name": HERO_NAME[KINDS[k]], "role": HERO_ROLE[KINDS[k]], "portrait": f"portrait_{KINDS[k]}.png"} for k in range(4)},
        "colors": {COLORS[i]: "#%02X%02X%02X" % tuple(int(v * 255) for v in PCOL4[i][:3]) for i in range(4)},
        "animations": {a[0]: {"row": i, "frames": a[1], "fps": a[2], "loop": a[3]} for i, a in enumerate(ANIMS)},
        "facing": "los sprites miran a la derecha; para la izquierda usar flip_h",
    }
    with open(os.path.join(CHAR_DIR, 'characters.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    print('ok')


if __name__ == '__main__':
    main()
