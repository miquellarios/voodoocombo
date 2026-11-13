"""Exporta las arenas a assets de Godot: fondos, tiras de sprites de trampas y arenas.json."""
import cairo, json, math, os, sys, copy
from gfx import *
from arenas import *

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_arenas'
AD = os.path.join(OUT, 'assets', 'arenas'); HD = os.path.join(AD, 'trampas')
os.makedirs(HD, exist_ok=True)
S = 2  # escala de exportación


def surface(wpx, hpx):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(wpx * S), int(hpx * S)); return s, cairo.Context(s)


def strip(name, fw, fh, n, draw):
    """draw(ctx, i): dibuja el frame i con el centro del frame en (fw/2, fh/2) en unidades del mundo."""
    s, ctx = surface(fw * n, fh)
    for i in range(n):
        ctx.save(); ctx.scale(S, S); ctx.rectangle(i * fw, 0, fw, fh); ctx.clip(); ctx.translate(i * fw, 0)
        draw(ctx, i); ctx.restore()
    s.write_to_png(os.path.join(HD, name + '.png'))
    return {"file": "trampas/" + name + ".png", "frame_w": fw * S, "frame_h": fh * S, "frames": n, "scale": 1 / S}


def at(ctx, fw, fh, wx, wy):
    ctx.translate(fw / 2 - wx, fh / 2 - wy)


# Huella de cada obstáculo en el suelo (lo que se ve), en píxeles relativos a su rect de casillas (x, y, w, h).
# El juego choca contra esto, no contra la casilla entera: así un árbol o una columna no ocupan "dos casillas".
HITBOX = {
    'stone':    lambda x, y, w, h: (x + 6, y + 14, w - 12, h - 16),
    'bigstone': lambda x, y, w, h: (x + 8, y + 10, w - 16, h - 12),
    'log':      lambda x, y, w, h: (x + 4, y + 9, w - 8, h - 14),
    'tree':     lambda x, y, w, h: (x + w / 2 - 10, y + h - 16, 20, 14),
    'sarc':     lambda x, y, w, h: (x + 4, y + 5, w - 8, h - 10),
    'column':   lambda x, y, w, h: (x + w / 2 - 12, y + h - 14, 24, 12),
    'altar':    lambda x, y, w, h: (x + 2, y + 4, w - 4, h - 4),
    'crate':    lambda x, y, w, h: (x + 4, y + 4, w - 8, h - 8),
    'anvil':    lambda x, y, w, h: (x + 6, y + 10, w - 12, h - 12),
    'boiler':   lambda x, y, w, h: (x + 6, y + 6, w - 12, h - 10),
    'shelf':    lambda x, y, w, h: (x + 3, y + 4, w - 6, h - 4),
    'books':    lambda x, y, w, h: (x + w / 2 - 15, y + h / 2 - 8, 30, 26),
}


def export_backgrounds(meta):
    for aid in ORDER:
        os.makedirs(os.path.join(AD, aid), exist_ok=True)
        s, ctx = surface(AW + 2 * PAD, AH + 2 * PAD)
        ctx.scale(S, S); ctx.translate(PAD, PAD)
        draw_static(ctx, aid, 0.0, with_obstacles=True)
        s.write_to_png(os.path.join(AD, aid, 'fondo.png'))
        A = ARENAS[aid]
        meta['arenas'][aid] = {
            "name": A['name'], "accent": A['accent'],
            "background": {"file": f"{aid}/fondo.png", "offset": [-PAD, -PAD], "scale": 1 / S,
                           "note": "Sprite2D con centered=false en la posición (-40,-40) y escala 0.5: la esquina (0,0) de la arena coincide con el mundo"},
            "obstacles": [{"kind": k, "rect": [px(x), px(y), px(w), px(h)], "hitbox": [round(v) for v in HITBOX[k](px(x), px(y), px(w), px(h))]} for (x, y, w, h, k) in A['obstacles']],
            "hazards": [], "spawn_sets": [[[px(a), px(b)] for (a, b) in ss] for ss in A['spawns']], "rules": A['rules'],
        }
        for h in A['hazards']:
            hz = {"type": h['type']}
            if h['type'] == 'lodo':
                hz.update(center=[px(h['x']), px(h['y'])], radius=[px(h['rx']), px(h['ry'])], speed_mult=0.6, sprite=None)
            elif h['type'] == 'raices':
                hz.update(every=h['every'], warn=h['warn'], active=h['active'], radius=px(h['radius']), random_position=True,
                          sprite_warn="raices_aviso", sprite_active="raices_activas")
            elif h['type'] == 'pinchos':
                hz.update(tiles=[[px(a), px(b), TILE, TILE] for (a, b) in h['tiles']], phase=h['phase'], down=h['down'], warn=h['warn'], up=h['up'],
                          sprite="pinchos", frames={"down": 0, "warn": 1, "up": 2})
            elif h['type'] == 'fantasma':
                hz.update(path=[[px(a), px(b)] for (a, b) in h['path']], speed=h['speed'], radius=22, stun=0.6, drop=3, sprite="fantasma")
            elif h['type'] == 'cinta':
                hz.update(tiles=[[px(a), px(b), TILE, TILE] for (a, b) in h['tiles']], dir=list(h['dir']), speed=h['speed'],
                          sprite="cinta", sprite_roller="cinta_rodillo")
            elif h['type'] == 'vapor':
                hz.update(center=[px(h['x']), px(h['y'])], every=h['every'], warn=h['warn'], blast=h['blast'], radius=h['radius'],
                          knockback=220, stun=0.3, sprite_grate="vapor_rejilla", sprite_warn="vapor_aviso", sprite_blast="vapor_chorro")
            elif h['type'] == 'barril':
                hz.update(center=[px(h['x']), px(h['y'])], fuse=h['fuse'], radius=h['radius'], respawn=h['respawn'], drop_pct=0.2,
                          sprite_idle="barril", sprite_fuse="barril_mecha", sprite_boom="barril_explosion")
            elif h['type'] == 'portal':
                hz.update(a=[px(h['a'][0]), px(h['a'][1])], b=[px(h['b'][0]), px(h['b'][1])], color=h['color'], radius=22,
                          cooldown=h['cooldown'], sprite="portal_" + ("cian" if h['color'] == '#7FE7FF' else "magenta"))
            elif h['type'] == 'rayo':
                hz.update(center=[px(h['x']), px(h['y'])], length=h['length'], period=h['period'], arms=h['arms'], hit_width=10,
                          sprite_orb="rayo_orbe", sprite_beam="rayo_haz")
            meta['arenas'][aid]['hazards'].append(hz)


def export_hazard_sprites(meta):
    sp = meta['sprites']
    sp['raices_aviso'] = strip('raices_aviso', 90, 90, 6, lambda c, i: (at(c, 90, 90, 0, 0), hz_raices(c, 0, 0, 'warn', i / 6)))
    sp['raices_activas'] = strip('raices_activas', 90, 90, 6, lambda c, i: (at(c, 90, 90, 0, 0), hz_raices(c, 0, 0, 'active', i / 6 * 0.45)))
    sp['pinchos'] = strip('pinchos', 40, 40, 3, lambda c, i: hz_pincho_tile(c, 0, 0, ['down', 'warn', 'up'][i]))
    sp['fantasma'] = strip('fantasma', 100, 100, 8, lambda c, i: (at(c, 100, 100, 0, 0), hz_fantasma(c, 0, 0, i / 8 * 2 * math.pi / 3, 1)))

    def belt_tile(c, i, dx=1):
        c.rectangle(0, 6, 40, 28); c.set_source_rgba(*hexc('#24222C')); c.fill()
        c.move_to(0, 6); c.line_to(40, 6); c.move_to(0, 34); c.line_to(40, 34); c.set_source_rgba(*OUTL2); c.set_line_width(5); c.stroke()
        c.save(); c.rectangle(0, 9, 40, 22); c.clip()
        off = i / 4 * 20
        for k in range(-1, 3):
            cx = k * 20 + off
            c.move_to(cx - 5, 13); c.line_to(cx + 3, 20); c.line_to(cx - 5, 27)
        c.set_source_rgba(*wa(hexc('#FFB347'), 0.75)); c.set_line_width(3.5); c.set_line_cap(cairo.LINE_CAP_ROUND); c.stroke(); c.restore()
    sp['cinta'] = strip('cinta', 40, 40, 4, belt_tile)
    sp['cinta']['note'] = "Las flechas apuntan a +x; para dir=(-1,0) usar flip_h"

    def roller(c, i):
        c.arc(20, 20, 9, 0, 2 * math.pi); fill_stroke(c, hexc('#55556A'), OUTL2, 3)
        a = i / 4 * math.pi
        c.move_to(20, 20); c.line_to(20 + math.cos(a) * 7, 20 + math.sin(a) * 7); c.set_source_rgba(*OUTL2); c.set_line_width(2); c.stroke()
    sp['cinta_rodillo'] = strip('cinta_rodillo', 40, 40, 4, roller)
    hv = dict(x=2.0, y=2.0, every=4, warn=0.6, blast=0.5, radius=70)
    sp['vapor_rejilla'] = strip('vapor_rejilla', 160, 160, 1, lambda c, i: hz_vapor(c, hv, 'idle', 0))
    sp['vapor_aviso'] = strip('vapor_aviso', 160, 160, 4, lambda c, i: hz_vapor(c, hv, 'warn', i / 4))
    sp['vapor_chorro'] = strip('vapor_chorro', 160, 160, 5, lambda c, i: hz_vapor(c, hv, 'blast', i / 5))
    hb = dict(x=3.0, y=3.0, radius=110)
    sp['barril'] = strip('barril', 120, 120, 1, lambda c, i: (c.translate(-60, -60), hz_barril(c, hb, 'idle', 0)))
    sp['barril_mecha'] = strip('barril_mecha', 120, 120, 4, lambda c, i: (c.translate(-60, -60), hz_barril(c, hb, 'fuse', i / 4 + 0.05, i * 0.02)))
    sp['barril_explosion'] = strip('barril_explosion', 240, 240, 6, lambda c, i: hz_barril(c, hb, 'boom', (i + 1) / 7))
    for name, col in (('portal_cian', '#7FE7FF'), ('portal_magenta', '#FF4FD8')):
        sp[name] = strip(name, 80, 80, 8, lambda c, i, col=col: (at(c, 80, 80, 0, 0), hz_portal(c, 0, 0, col, i / 8 * 2 * math.pi / 3)))
    def orb(c, i):
        at(c, 80, 80, 0, 0)
        g = cairo.RadialGradient(0, 0, 2, 0, 0, 40); g.add_color_stop_rgba(0, 0.8, 1, 1, 0.9); g.add_color_stop_rgba(1, 0.4, 0.8, 1, 0)
        c.set_source(g); c.arc(0, 0, 40, 0, 2 * math.pi); c.fill()
        c.arc(0, 0, 15 + math.sin(i / 4 * 2 * math.pi) * 1.5, 0, 2 * math.pi); fill_stroke(c, hexc('#BFF4FF'), OUTL2, 4)
        c.arc(-4, -4, 4, 0, 2 * math.pi); c.set_source_rgba(1, 1, 1, 0.9); c.fill()
    sp['rayo_orbe'] = strip('rayo_orbe', 80, 80, 4, orb)
    def beam(c, i):
        c.set_line_cap(cairo.LINE_CAP_ROUND)
        for (lw, al, col) in ((24, 0.15, (0.5, 0.9, 1)), (14, 0.35, (0.5, 0.9, 1)), (6, 0.9, (0.5, 0.9, 1)), (2.5, 1.0, (1, 1, 1))):
            c.move_to(6, 15); c.line_to(286, 15); c.set_source_rgba(col[0], col[1], col[2], al); c.set_line_width(lw); c.stroke()
    sp['rayo_haz'] = strip('rayo_haz', 292, 30, 1, beam)
    sp['rayo_haz']['note'] = "El haz empieza en x=6 px (mundo); poner offset para que el inicio quede en el centro del orbe y rotar el nodo"


def main():
    meta = {"tile": TILE, "grid": [GW, GH], "arena_px": [AW, AH], "export_scale": S, "arenas": {}, "sprites": {},
            "selection": "Cada partida elige una arena al azar (sin repetir la anterior). Doblones y cofres en casillas libres al azar, fuera de obstáculos y trampas fijas."}
    export_backgrounds(meta)
    export_hazard_sprites(meta)
    with open(os.path.join(AD, 'arenas.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    print('ok', len(os.listdir(HD)), 'sprites')


if __name__ == '__main__':
    main()
