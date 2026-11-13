"""Arenas de VoodooCombo: 4 mapas con obstáculos, decoración y trampas. Exporta vista previa y assets para Godot."""
import cairo, math, random, json, os, sys
from gfx import *
from chars import weave

TILE, GW, GH = 40, 30, 15
AW, AH = GW * TILE, GH * TILE
PAD = 40
OUTL2 = hexc('#0B0710')


# ================================================================ definición de las arenas (coordenadas en casillas)
def mirror4(items):
    out = []
    for (x, y, w, h, k) in items:
        for mx in (False, True):
            for my in (False, True):
                it = (GW - x - w if mx else x, GH - y - h if my else y, w, h, k)
                if it not in out:
                    out.append(it)
    return out


def mirrorx(items):
    out = []
    for (x, y, w, h, k) in items:
        for it in ((x, y, w, h, k), (GW - x - w, y, w, h, k)):
            if it not in out:
                out.append(it)
    return out


def mpts(x, y):
    """4 posiciones simétricas (en casillas, centro de casilla con decimales)."""
    pts = []
    for p in ((x, y), (GW - x, y), (x, GH - y), (GW - x, GH - y)):
        if p not in pts:
            pts.append(p)
    return pts


CORNERS = [(2.5, 2.5), (27.5, 2.5), (2.5, 12.5), (27.5, 12.5)]
SIDES = [(2.5, 7.5), (27.5, 7.5), (15.0, 1.5), (15.0, 13.5)]

ARENAS = {
    'cienaga': dict(
        name='Ciénaga Embrujada', floor=('#1C251B', '#161E15'), accent='#7BE042',
        obstacles=mirror4([(6, 3, 1, 1, 'stone'), (11, 6, 2, 1, 'log')]) + mirrorx([(4, 7, 1, 1, 'tree')]) + [(14, 7, 2, 1, 'bigstone')],
        hazards=[dict(type='lodo', x=p[0], y=p[1], rx=1.8, ry=1.1) for p in mpts(9.5, 4.2)] +
                [dict(type='raices', random=True, every=6.0, warn=0.7, active=1.0, radius=0.9)],
        spawns=[CORNERS, SIDES],
        rules={'lodo': 'Zona lenta: velocidad x0,6 mientras estás dentro. Los doblones también caen aquí.',
               'raices': 'Cada 6 s aparecen en un punto al azar: aviso verde 0,7 s y luego atrapan 1 s (no te mueves, sí puedes usar hechizo).'}),
    'cripta': dict(
        name='Cripta de Huesos', floor=('#24202C', '#1D1A24'), accent='#B06BFF',
        obstacles=mirror4([(5, 4, 2, 1, 'sarc'), (10, 2, 1, 1, 'column')]) + [(14, 7, 2, 1, 'altar')],
        hazards=[dict(type='pinchos', tiles=[(8, 7), (9, 7), (10, 7), (19, 7), (20, 7), (21, 7)], phase=0.0, down=2.0, warn=0.6, up=1.0),
                 dict(type='pinchos', tiles=[(14, 3), (15, 3), (14, 11), (15, 11)], phase=1.8, down=2.0, warn=0.6, up=1.0),
                 dict(type='fantasma', path=[(9, 4.5), (21, 4.5), (21, 10.5), (9, 10.5)], speed=120)],
        spawns=[CORNERS, SIDES],
        rules={'pinchos': 'Ciclo de 3,6 s: 2 s escondidos, 0,6 s de aviso en rojo y 1 s arriba. Si te pinchan, cuenta como un golpe (sueltas doblones).',
               'fantasma': 'Da vueltas alrededor del altar a 120 px/s. Si te toca: aturdido 0,6 s y sueltas 3 doblones.'}),
    'taller': dict(
        name='Taller Gnómico', floor=('#2A2420', '#231E1A'), accent='#FFB347',
        obstacles=mirror4([(6, 2, 1, 1, 'crate'), (10, 5, 1, 1, 'anvil')]) + [(14, 6, 2, 3, 'boiler')],
        hazards=[dict(type='cinta', tiles=[(x, 3) for x in range(9, 21)], dir=(1, 0), speed=140),
                 dict(type='cinta', tiles=[(x, 11) for x in range(9, 21)], dir=(-1, 0), speed=140),
                 dict(type='vapor', x=4.5, y=5.5, every=4.0, warn=0.6, blast=0.5, radius=70),
                 dict(type='vapor', x=25.5, y=5.5, every=4.0, warn=0.6, blast=0.5, radius=70),
                 dict(type='vapor', x=4.5, y=9.5, every=4.0, warn=0.6, blast=0.5, radius=70),
                 dict(type='vapor', x=25.5, y=9.5, every=4.0, warn=0.6, blast=0.5, radius=70),
                 dict(type='barril', x=7.5, y=7.5, fuse=0.8, radius=110, respawn=15),
                 dict(type='barril', x=22.5, y=7.5, fuse=0.8, radius=110, respawn=15)],
        spawns=[CORNERS, SIDES],
        rules={'cinta': 'Empuja a 140 px/s a jugadores y doblones en su dirección.',
               'vapor': 'Cada 4 s: aviso 0,6 s (humo) y chorro 0,5 s que empuja lejos y aturde 0,3 s.',
               'barril': 'Si le das con el dash, explota a los 0,8 s: empuja y hace soltar el 20 % de los doblones a todos en 110 px. Reaparece a los 15 s.'}),
    'biblioteca': dict(
        name='Biblioteca Arcana', floor=('#221A30', '#1C1528'), accent='#7FE7FF',
        obstacles=mirror4([(4, 3, 3, 1, 'shelf'), (9, 6, 1, 1, 'books')]),
        hazards=[dict(type='portal', a=(7.5, 1.5), b=(22.5, 13.5), color='#7FE7FF', cooldown=1.0),
                 dict(type='portal', a=(22.5, 1.5), b=(7.5, 13.5), color='#FF4FD8', cooldown=1.0),
                 dict(type='rayo', x=15.0, y=7.5, length=280, period=8.0, arms=2)],
        spawns=[CORNERS],
        rules={'portal': 'Entras por un portal y sales por su pareja (mismo color). 1 s de espera para volver a usarlo. Los doblones no lo cruzan.',
               'rayo': 'Dos rayos que giran desde el orbe central (una vuelta cada 8 s, 280 px). Si te toca, cuenta como un golpe.'}),
}
ORDER = ['cienaga', 'cripta', 'taller', 'biblioteca']


# ================================================================ dibujo de obstáculos
def shadow(ctx, x, y, w):
    ellipse(ctx, x, y, w, w * 0.22); ctx.set_source_rgba(0, 0, 0, 0.45); ctx.fill()


def ob_stone(ctx, x, y, w, h, label=None, moss=True):
    shadow(ctx, x + w / 2, y + h - 2, w * 0.55)
    ctx.new_path(); ctx.move_to(x + 4, y + h - 3); ctx.line_to(x + 4, y + h * 0.45)
    ctx.arc(x + w / 2, y + h * 0.45, w / 2 - 4, math.pi, 2 * math.pi); ctx.line_to(x + w - 4, y + h - 3); ctx.close_path()
    g = cairo.LinearGradient(0, y, 0, y + h); g.add_color_stop_rgba(0, *hexc('#5E5878')); g.add_color_stop_rgba(1, *hexc('#36304C'))
    fill_stroke(ctx, g, OUTL2, 5)
    ctx.set_source_rgba(*hexc('#26213A')); ctx.set_line_width(2.6); ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    if label:
        draw_text(ctx, label, x + w / 2, y + h * 0.58, 14, fam=FG, fill=hexc('#26213A'))
    else:
        ctx.move_to(x + w / 2, y + h * 0.3); ctx.line_to(x + w / 2, y + h * 0.72)
        ctx.move_to(x + w / 2 - 7, y + h * 0.44); ctx.line_to(x + w / 2 + 7, y + h * 0.44); ctx.stroke()
    if moss:
        ellipse(ctx, x + w * 0.3, y + h * 0.82, 7, 3); ctx.set_source_rgba(*wa(hexc('#5E8A4A'), 0.6)); ctx.fill()


def ob_log(ctx, x, y, w, h):
    shadow(ctx, x + w / 2, y + h - 3, w * 0.5)
    rrect(ctx, x + 3, y + 7, w - 6, h - 12, 12)
    g = cairo.LinearGradient(0, y, 0, y + h); g.add_color_stop_rgba(0, *hexc('#6A5440')); g.add_color_stop_rgba(1, *hexc('#3E3024'))
    fill_stroke(ctx, g, OUTL2, 5)
    ellipse(ctx, x + w - 9, y + h / 2 - 2, 7, 11); fill_stroke(ctx, hexc('#97795A'), OUTL2, 3)
    ellipse(ctx, x + w - 9, y + h / 2 - 2, 3, 5); ctx.set_source_rgba(*hexc('#6A5440')); ctx.fill()
    for (mx, my) in ((x + 18, y + 10), (x + w * 0.55, y + h - 12)):
        ellipse(ctx, mx, my, 9, 3.5); ctx.set_source_rgba(*wa(hexc('#4E7A3A'), 0.8)); ctx.fill()


def ob_tree(ctx, x, y, w, h):
    cx, by = x + w / 2, y + h
    shadow(ctx, cx, by - 2, w * 0.6)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    def trunk():
        ctx.new_path(); ctx.move_to(cx - 8, by - 2); ctx.curve_to(cx - 4, by - 18, cx - 7, by - 30, cx - 2, by - 44)
        ctx.line_to(cx + 3, by - 44); ctx.curve_to(cx + 2, by - 28, cx + 6, by - 16, cx + 9, by - 2); ctx.close_path()
    trunk(); ctx.set_source_rgba(*OUTL2); ctx.set_line_width(8); ctx.stroke()
    br = [((cx - 1, by - 30), (cx - 14, by - 40), (cx - 20, by - 52)), ((cx + 1, by - 36), (cx + 14, by - 44), (cx + 18, by - 58)),
          ((cx, by - 42), (cx - 4, by - 54), (cx + 2, by - 64)), ((cx - 14, by - 40), (cx - 24, by - 42), (cx - 28, by - 48))]
    for (lw, c) in ((8, OUTL2), (4, hexc('#3A2E26'))):
        for (a, b2, c2) in br:
            ctx.move_to(*a); ctx.curve_to(a[0], a[1], b2[0], b2[1], c2[0], c2[1])
        ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()
    trunk(); g = cairo.LinearGradient(cx - 8, 0, cx + 9, 0); g.add_color_stop_rgba(0, *hexc('#5A463A')); g.add_color_stop_rgba(1, *hexc('#2E241C'))
    ctx.set_source(g); ctx.fill()
    ellipse(ctx, cx + 1, by - 22, 2.5, 3.5); ctx.set_source_rgba(*OUTL2); ctx.fill()


def ob_sarc(ctx, x, y, w, h):
    shadow(ctx, x + w / 2, y + h - 1, w * 0.5)
    ctx.new_path(); ctx.move_to(x + 6, y + 6); ctx.line_to(x + w - 14, y + 4); ctx.line_to(x + w - 3, y + h / 2)
    ctx.line_to(x + w - 14, y + h - 4); ctx.line_to(x + 6, y + h - 6); ctx.line_to(x + 3, y + h / 2); ctx.close_path()
    g = cairo.LinearGradient(0, y, 0, y + h); g.add_color_stop_rgba(0, *hexc('#6B6680')); g.add_color_stop_rgba(1, *hexc('#3B374C'))
    fill_stroke(ctx, g, OUTL2, 5)
    ctx.move_to(x + w * 0.35, y + h / 2); ctx.line_to(x + w * 0.65, y + h / 2)
    ctx.move_to(x + w * 0.45, y + h * 0.3); ctx.line_to(x + w * 0.45, y + h * 0.7)
    ctx.set_source_rgba(*hexc('#26213A')); ctx.set_line_width(3); ctx.stroke()
    ctx.move_to(x + 10, y + 9); ctx.line_to(x + w - 16, y + 8); ctx.set_source_rgba(1, 1, 1, 0.15); ctx.set_line_width(2); ctx.stroke()


def ob_column(ctx, x, y, w, h):
    cx, by = x + w / 2, y + h
    shadow(ctx, cx, by - 2, w * 0.5)
    rrect(ctx, cx - 15, by - 10, 30, 8, 2); fill_stroke(ctx, hexc('#4A4560'), OUTL2, 4)
    g = cairo.LinearGradient(cx - 11, 0, cx + 11, 0); g.add_color_stop_rgba(0, *hexc('#7A7494')); g.add_color_stop_rgba(1, *hexc('#4A4560'))
    ctx.new_path(); ctx.move_to(cx - 11, by - 10); ctx.line_to(cx - 11, by - 40); ctx.line_to(cx - 4, by - 46); ctx.line_to(cx + 2, by - 38)
    ctx.line_to(cx + 7, by - 44); ctx.line_to(cx + 11, by - 36); ctx.line_to(cx + 11, by - 10); ctx.close_path()
    fill_stroke(ctx, g, OUTL2, 4)
    for xx in (cx - 5, cx + 1, cx + 6):
        ctx.move_to(xx, by - 12); ctx.line_to(xx, by - 34)
    ctx.set_source_rgba(*hexc('#3B374C')); ctx.set_line_width(1.6); ctx.stroke()
    for (dx, dy) in ((18, -4), (-19, -2)):
        ctx.new_path(); ctx.move_to(cx + dx - 5, by + dy); ctx.line_to(cx + dx, by + dy - 6); ctx.line_to(cx + dx + 6, by + dy - 1); ctx.close_path()
        fill_stroke(ctx, hexc('#5E5878'), OUTL2, 2.5)


def ob_altar(ctx, x, y, w, h, t=0.0):
    shadow(ctx, x + w / 2, y + h, w * 0.55)
    rrect(ctx, x + 2, y + 2, w - 4, h - 2, 6)
    g = cairo.LinearGradient(0, y, 0, y + h); g.add_color_stop_rgba(0, *hexc('#4E4664')); g.add_color_stop_rgba(1, *hexc('#2E2840'))
    fill_stroke(ctx, g, OUTL2, 5)
    rrect(ctx, x + 10, y + 8, w - 20, h - 18, 4); ctx.set_source_rgba(*hexc('#5A1A2A')); ctx.fill()
    for cx in (x + 10, x + w - 10):
        rrect(ctx, cx - 3, y - 8, 6, 14, 1.5); fill_stroke(ctx, hexc('#E8DCC4'), OUTL2, 2)
        ellipse(ctx, cx, y - 12, 2.4, 4); ctx.set_source_rgba(1, 0.85, 0.45, 1); ctx.fill()
    ellipse(ctx, x + w / 2, y + h * 0.42, 8, 7); fill_stroke(ctx, hexc('#E8DCC4'), OUTL2, 3)
    for ex in (-3, 3):
        ctx.arc(x + w / 2 + ex, y + h * 0.4, 1.8, 0, 2 * math.pi); ctx.set_source_rgba(*OUTL2); ctx.fill()


def ob_crate(ctx, x, y, w, h):
    shadow(ctx, x + w / 2, y + h, w * 0.55)
    rrect(ctx, x + 3, y + 3, w - 6, h - 6, 4); fill_stroke(ctx, hexc('#8A5E36'), OUTL2, 5)
    ctx.rectangle(x + 7, y + 7, w - 14, h - 14); ctx.set_source_rgba(*hexc('#A8743F')); ctx.fill()
    ctx.move_to(x + 7, y + 7); ctx.line_to(x + w - 7, y + h - 7); ctx.move_to(x + w - 7, y + 7); ctx.line_to(x + 7, y + h - 7)
    ctx.set_source_rgba(*hexc('#6B4626')); ctx.set_line_width(3.5); ctx.stroke()
    for (bx, by) in ((x + 6, y + 6), (x + w - 6, y + 6), (x + 6, y + h - 6), (x + w - 6, y + h - 6)):
        ctx.arc(bx, by, 1.8, 0, 2 * math.pi); ctx.set_source_rgba(*hexc('#C9CCD8')); ctx.fill()


def ob_anvil(ctx, x, y, w, h):
    cx = x + w / 2
    shadow(ctx, cx, y + h - 2, w * 0.5)
    rrect(ctx, cx - 9, y + h * 0.5, 18, h * 0.42, 3); fill_stroke(ctx, hexc('#3A3A46'), OUTL2, 5)
    ctx.new_path(); ctx.move_to(x + 2, y + 10); ctx.curve_to(x + 6, y + 6, x + 10, y + 8, x + 14, y + 8)
    ctx.line_to(x + w - 4, y + 8); ctx.line_to(x + w - 4, y + 20); ctx.line_to(x + 12, y + 20); ctx.curve_to(x + 8, y + 18, x + 4, y + 14, x + 2, y + 10); ctx.close_path()
    fill_stroke(ctx, hexc('#55556A'), OUTL2, 5)
    ctx.move_to(x + 14, y + 10); ctx.line_to(x + w - 6, y + 10); ctx.set_source_rgba(1, 1, 1, 0.3); ctx.set_line_width(2); ctx.stroke()


def ob_boiler(ctx, x, y, w, h, t=0.0):
    cx, cy = x + w / 2, y + h / 2
    shadow(ctx, cx, y + h, w * 0.6)
    rrect(ctx, x + 4, y + 4, w - 8, h - 8, 26)
    g = cairo.LinearGradient(x, 0, x + w, 0)
    g.add_color_stop_rgba(0, *hexc('#7A3E1E')); g.add_color_stop_rgba(0.35, *hexc('#D07A3A')); g.add_color_stop_rgba(1, *hexc('#6B3418'))
    fill_stroke(ctx, g, OUTL2, 6)
    for yy in (y + 26, y + h - 26):
        ctx.move_to(x + 6, yy); ctx.line_to(x + w - 6, yy)
    ctx.set_source_rgba(*hexc('#4A2410')); ctx.set_line_width(4); ctx.stroke()
    ctx.arc(cx, cy, 13, 0, 2 * math.pi); fill_stroke(ctx, hexc('#E8DCC4'), OUTL2, 4)
    a = -2.4 + 1.2 * math.sin(t * 2)
    ctx.move_to(cx, cy); ctx.line_to(cx + math.cos(a) * 10, cy + math.sin(a) * 10); ctx.set_source_rgba(*hexc('#C9363F')); ctx.set_line_width(2.5); ctx.stroke()
    for (bx, by) in ((x + 12, y + 14), (x + w - 12, y + 14), (x + 12, y + h - 14), (x + w - 12, y + h - 14)):
        ctx.arc(bx, by, 2.4, 0, 2 * math.pi); ctx.set_source_rgba(*hexc('#3A1A0A')); ctx.fill()
    rrect(ctx, cx - 6, y - 6, 12, 14, 3); fill_stroke(ctx, hexc('#55556A'), OUTL2, 4)


def ob_shelf(ctx, x, y, w, h):
    shadow(ctx, x + w / 2, y + h, w * 0.5)
    rrect(ctx, x + 2, y + 2, w - 4, h - 2, 4); fill_stroke(ctx, hexc('#4A2E22'), OUTL2, 5)
    rng = random.Random(int(x * 7 + y))
    bx = x + 7
    cols = ['#8E1F2B', '#2F5A8A', '#4E7A2E', '#C9971C', '#5A3D7A', '#2A6B6B']
    while bx < x + w - 10:
        bw = rng.uniform(5, 9); bh = rng.uniform(h * 0.5, h * 0.7)
        ctx.rectangle(bx, y + h - 6 - bh, bw, bh); ctx.set_source_rgba(*hexc(rng.choice(cols))); ctx.fill_preserve()
        ctx.set_source_rgba(*OUTL2); ctx.set_line_width(1.2); ctx.stroke()
        bx += bw + 1
    ctx.move_to(x + 4, y + h - 6); ctx.line_to(x + w - 4, y + h - 6); ctx.set_source_rgba(*hexc('#2E1A12')); ctx.set_line_width(3); ctx.stroke()


def ob_books(ctx, x, y, w, h, t=0.0):
    cx, cy = x + w / 2, y + h / 2
    shadow(ctx, cx, y + h - 2, w * 0.5)
    ctx.arc(cx, cy + 6, 15, 0, 2 * math.pi); fill_stroke(ctx, hexc('#3A3050'), OUTL2, 5)
    for k, (c, dx) in enumerate((('#8E1F2B', -2), ('#2F5A8A', 2), ('#C9971C', -1))):
        rrect(ctx, cx - 11 + dx, cy + 2 - k * 6, 22, 6, 1.5); fill_stroke(ctx, hexc(c), OUTL2, 2.5)
    g = cairo.RadialGradient(cx, cy - 16, 1, cx, cy - 16, 22)
    g.add_color_stop_rgba(0, *wa(FROST, 0.8)); g.add_color_stop_rgba(1, *wa(FROST, 0))
    ctx.set_source(g); ctx.arc(cx, cy - 16, 22, 0, 2 * math.pi); ctx.fill()
    ctx.arc(cx, cy - 16 + math.sin(t * 3) * 2, 6, 0, 2 * math.pi); fill_stroke(ctx, hexc('#BFF4FF'), OUTL2, 2.5)


OBSTACLE_DRAW = {'stone': ob_stone, 'log': ob_log, 'tree': ob_tree, 'bigstone': lambda c, x, y, w, h: ob_stone(c, x + 4, y - 6, w - 8, h + 6, label='R.I.P.'),
                 'sarc': ob_sarc, 'column': ob_column, 'altar': ob_altar, 'crate': ob_crate, 'anvil': ob_anvil, 'boiler': ob_boiler,
                 'shelf': ob_shelf, 'books': ob_books}


# ================================================================ suelo y decoración
def floor(ctx, aid, seed=5):
    A = ARENAS[aid]; ca, cb = hexc(A['floor'][0]), hexc(A['floor'][1])
    rng = random.Random(seed)
    rrect(ctx, -10, -10, AW + 20, AH + 20, 26); ctx.set_source_rgba(*hexc('#0E0817')); ctx.fill()
    ctx.save(); rrect(ctx, 0, 0, AW, AH, 18); ctx.clip()
    for ty in range(GH):
        for tx in range(GW):
            c = ca if (tx + ty) % 2 == 0 else cb
            ctx.rectangle(tx * TILE, ty * TILE, TILE, TILE); ctx.set_source_rgba(*shade(c, rng.uniform(-0.05, 0.05))); ctx.fill()
    if aid == 'cripta':
        ctx.set_source_rgba(0, 0, 0, 0.35); ctx.set_line_width(1.5)
        for ty in range(GH + 1):
            ctx.move_to(0, ty * TILE); ctx.line_to(AW, ty * TILE)
        for tx in range(GW + 1):
            ctx.move_to(tx * TILE, 0); ctx.line_to(tx * TILE, AH)
        ctx.stroke()
        for _ in range(40):
            x, y = rng.uniform(0, AW), rng.uniform(0, AH)
            ctx.move_to(x, y)
            for k in range(3):
                x += rng.uniform(-14, 14); y += rng.uniform(-14, 14); ctx.line_to(x, y)
            ctx.set_source_rgba(0, 0, 0, 0.4); ctx.set_line_width(1.2); ctx.stroke()
    if aid == 'taller':
        for ty in range(GH):
            ctx.move_to(0, ty * TILE + 0.5); ctx.line_to(AW, ty * TILE + 0.5)
            off = (ty % 2) * 60
            for x0 in range(-60 + off, AW, 120):
                ctx.move_to(x0, ty * TILE); ctx.line_to(x0, ty * TILE + TILE)
        ctx.set_source_rgba(0, 0, 0, 0.45); ctx.set_line_width(1.5); ctx.stroke()
        for _ in range(16):
            ellipse(ctx, rng.uniform(30, AW - 30), rng.uniform(30, AH - 30), rng.uniform(14, 26), rng.uniform(6, 12))
            ctx.set_source_rgba(0.05, 0.04, 0.06, 0.5); ctx.fill()
    if aid == 'biblioteca':
        rrect(ctx, 120, AH / 2 - 46, AW - 240, 92, 8); ctx.set_source_rgba(*hexc('#4A1430')); ctx.fill_preserve()
        ctx.set_source_rgba(*hexc('#C9971C')); ctx.set_line_width(3); ctx.stroke()
        ctx.arc(AW / 2, AH / 2, 110, 0, 2 * math.pi); ctx.set_source_rgba(*wa(hexc('#C9971C'), 0.6)); ctx.set_line_width(3); ctx.stroke()
        ctx.arc(AW / 2, AH / 2, 92, 0, 2 * math.pi); ctx.set_line_width(1.5); ctx.stroke()
        ctx.set_source_rgba(*wa(hexc('#C9971C'), 0.85)); ctx.set_line_width(1.8); ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        for k in range(12):
            a = k * math.pi / 6; gx, gy = AW / 2 + math.cos(a) * 101, AH / 2 + math.sin(a) * 101
            ctx.move_to(gx, gy - 5); ctx.line_to(gx, gy + 5)
            if k % 3 == 0:
                ctx.move_to(gx, gy - 5); ctx.line_to(gx + 4, gy - 1)
            elif k % 3 == 1:
                ctx.move_to(gx - 4, gy - 3); ctx.line_to(gx + 4, gy + 1)
            else:
                ctx.move_to(gx, gy); ctx.line_to(gx + 4, gy + 4); ctx.move_to(gx, gy); ctx.line_to(gx - 4, gy + 4)
        ctx.stroke()
    for _ in range(26 if aid == 'cienaga' else 10):
        x, y = rng.uniform(20, AW - 20), rng.uniform(20, AH - 20)
        ellipse(ctx, x, y, rng.uniform(16, 30), rng.uniform(7, 12)); ctx.set_source_rgba(0, 0, 0, 0.22); ctx.fill()
    for _ in range(160):
        x, y = rng.uniform(8, AW - 8), rng.uniform(8, AH - 8)
        if aid == 'cienaga':
            ctx.set_source_rgba(*wa(hexc('#2C3B29'), 0.8)); ctx.set_line_width(1.6); ctx.set_line_cap(cairo.LINE_CAP_ROUND)
            for k in (-1, 0, 1):
                ctx.move_to(x + k * 2.5, y); ctx.line_to(x + k * 4.5, y - 6)
            ctx.stroke()
        elif aid == 'cripta' and rng.random() < 0.25:
            ctx.set_source_rgba(*wa(hexc('#CFC6B0'), 0.35)); ctx.set_line_width(2.2); ctx.set_line_cap(cairo.LINE_CAP_ROUND)
            ctx.move_to(x - 5, y); ctx.line_to(x + 5, y + 2); ctx.stroke()
        elif aid == 'taller' and rng.random() < 0.15:
            ctx.arc(x, y, 1.8, 0, 2 * math.pi); ctx.set_source_rgba(*wa(hexc('#9AA0B5'), 0.5)); ctx.fill()
        elif aid == 'biblioteca' and rng.random() < 0.12:
            ctx.save(); ctx.translate(x, y); ctx.rotate(rng.uniform(0, 3))
            ctx.rectangle(-5, -3.5, 10, 7); ctx.set_source_rgba(*wa(hexc('#E8DCC4'), 0.25)); ctx.fill(); ctx.restore()
    ctx.restore()
    rrect(ctx, 0, 0, AW, AH, 18); ctx.set_source_rgba(*hexc('#0E0817')); ctx.set_line_width(6); ctx.stroke()
    rrect(ctx, -6, -6, AW + 12, AH + 12, 22); ctx.set_dash([14, 10]); ctx.set_line_width(3.5)
    ctx.set_source_rgba(*wa(hexc(A['accent']), 0.55)); ctx.stroke(); ctx.set_dash([])


# ================================================================ trampas (dibujo según el tiempo)
def px(v):
    return v * TILE


def hz_lodo(ctx, h, t, static=True):
    x, y, rx, ry = px(h['x']), px(h['y']), px(h['rx']), px(h['ry'])
    ellipse(ctx, x, y, rx + 4, ry + 3); ctx.set_source_rgba(*hexc('#0E120B')); ctx.fill()
    ellipse(ctx, x, y, rx, ry)
    g = cairo.RadialGradient(x - rx * 0.3, y - ry * 0.3, 4, x, y, rx)
    g.add_color_stop_rgba(0, *hexc('#4A4A26')); g.add_color_stop_rgba(1, *hexc('#2A2A16')); ctx.set_source(g); ctx.fill()
    rng = random.Random(int(x + y))
    for k in range(6):
        bx, by = x + rng.uniform(-0.7, 0.7) * rx, y + rng.uniform(-0.6, 0.6) * ry
        u = (t * 0.6 + k / 6) % 1
        if not static or k < 3:
            ctx.arc(bx, by, 2 + u * 5, 0, 2 * math.pi); ctx.set_source_rgba(0.55, 0.55, 0.3, 0.6 * (1 - u)); ctx.set_line_width(1.5); ctx.stroke()


def hz_raices(ctx, x, y, state, u, r=36):
    if state == 'warn':
        a = 0.4 + 0.4 * math.sin(u * 20)
        ctx.arc(x, y, r, 0, 2 * math.pi); ctx.set_source_rgba(0.48, 0.88, 0.26, 0.2 + 0.2 * a); ctx.fill_preserve()
        ctx.set_dash([8, 6]); ctx.set_line_width(3); ctx.set_source_rgba(0.48, 0.88, 0.26, 0.9); ctx.stroke(); ctx.set_dash([])
    else:
        grow = e_out_back(min(1, u * 3))
        for k in range(7):
            a = k * 2 * math.pi / 7 + 0.3
            bx, by = x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.55
            ctx.move_to(bx, by + 6)
            ctx.curve_to(bx + math.cos(a) * 4, by - 14 * grow, bx - math.cos(a) * 10, by - 22 * grow, x + math.cos(a) * 8, y - 26 * grow)
            ctx.set_line_cap(cairo.LINE_CAP_ROUND)
            ctx.set_source_rgba(*OUTL2); ctx.set_line_width(8); ctx.stroke_preserve()
            ctx.set_source_rgba(*hexc('#5A4630')); ctx.set_line_width(4.5); ctx.stroke()
        ellipse(ctx, x, y + 4, r * 0.85, r * 0.4); ctx.set_source_rgba(0.2, 0.15, 0.08, 0.5); ctx.fill()


def hz_pincho_tile(ctx, tx, ty, state):
    x, y = px(tx), px(ty)
    rrect(ctx, x + 3, y + 3, TILE - 6, TILE - 6, 5); fill_stroke(ctx, hexc('#2A2634'), OUTL2, 3)
    holes = [(x + 11 + i * 9, y + 11 + j * 9) for i in range(3) for j in range(3)]
    if state == 'warn':
        g = cairo.RadialGradient(x + 20, y + 20, 2, x + 20, y + 20, 22)
        g.add_color_stop_rgba(0, 1, 0.25, 0.3, 0.7); g.add_color_stop_rgba(1, 1, 0.2, 0.25, 0.1)
        ctx.rectangle(x + 4, y + 4, TILE - 8, TILE - 8); ctx.set_source(g); ctx.fill()
    for (hx, hy) in holes:
        if state == 'up':
            ctx.move_to(hx - 4, hy + 3); ctx.line_to(hx, hy - 9); ctx.line_to(hx + 4, hy + 3); ctx.close_path()
            g = cairo.LinearGradient(hx, hy - 9, hx, hy + 3); g.add_color_stop_rgba(0, *hexc('#EEF0F7')); g.add_color_stop_rgba(1, *hexc('#6E7388'))
            fill_stroke(ctx, g, OUTL2, 1.8)
        else:
            ctx.arc(hx, hy, 2.2, 0, 2 * math.pi); ctx.set_source_rgba(*(hexc('#FF4D5E') if state == 'warn' else OUTL2)); ctx.fill()


def pinchos_state(h, t):
    cyc = h['down'] + h['warn'] + h['up']; u = (t + h['phase']) % cyc
    if u < h['down']:
        return 'down'
    return 'warn' if u < h['down'] + h['warn'] else 'up'


def path_pos(path, speed, t):
    pts = [(px(a), px(b)) for (a, b) in path] + [(px(path[0][0]), px(path[0][1]))]
    segs = [math.hypot(pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]) for i in range(len(pts) - 1)]
    d = (t * speed) % sum(segs)
    for i, L in enumerate(segs):
        if d <= L:
            u = d / L
            return lerp(pts[i][0], pts[i + 1][0], u), lerp(pts[i][1], pts[i + 1][1], u), pts[i + 1][0] - pts[i][0]
        d -= L
    return pts[0][0], pts[0][1], 1


def hz_fantasma(ctx, x, y, t, face=1):
    y += math.sin(t * 3) * 4
    g = cairo.RadialGradient(x, y, 4, x, y, 46); g.add_color_stop_rgba(0, 0.75, 0.6, 1, 0.35); g.add_color_stop_rgba(1, 0.75, 0.6, 1, 0)
    ctx.set_source(g); ctx.arc(x, y, 46, 0, 2 * math.pi); ctx.fill()
    ctx.push_group()
    ctx.new_path(); ctx.move_to(x - 18, y + 16); ctx.line_to(x - 18, y - 4); ctx.arc(x, y - 4, 18, math.pi, 2 * math.pi); ctx.line_to(x + 18, y + 16)
    for k in range(4):
        xx = x + 18 - (k + 1) * 9
        ctx.curve_to(xx + 6, y + 16 + 6 * math.sin(t * 8 + k), xx + 3, y + 10, xx, y + 16)
    ctx.close_path()
    fill_stroke(ctx, hexc('#EDE6FA'), OUTL2, 4)
    for ex in (-7, 7):
        ctx.arc(x + ex + face * 2, y - 6, 4.2, 0, 2 * math.pi); ctx.set_source_rgba(*hexc('#1E1430')); ctx.fill()
        ctx.arc(x + ex + face * 2 + 1.2, y - 7.2, 1.2, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.9); ctx.fill()
    ctx.move_to(x - 5 + face * 2, y + 4); ctx.curve_to(x - 2, y + 7, x + 2, y + 7, x + 5 + face * 2, y + 4)
    ctx.set_source_rgba(*OUTL2); ctx.set_line_width(2); ctx.stroke()
    ctx.pop_group_to_source(); ctx.paint_with_alpha(0.88)


def hz_cinta(ctx, h, t):
    tiles = h['tiles']; dx = h['dir'][0]
    x0 = px(min(a for a, b in tiles)); x1 = px(max(a for a, b in tiles) + 1); y = px(tiles[0][1])
    rrect(ctx, x0, y + 6, x1 - x0, TILE - 12, 8); fill_stroke(ctx, hexc('#24222C'), OUTL2, 5)
    ctx.save(); rrect(ctx, x0 + 3, y + 9, x1 - x0 - 6, TILE - 18, 6); ctx.clip()
    off = (t * h['speed'] * 0.25) % 20 * dx
    for k in range(int((x1 - x0) / 20) + 3):
        cx = x0 - 20 + k * 20 + off
        ctx.move_to(cx - 5 * dx, y + 13); ctx.line_to(cx + 3 * dx, y + 20); ctx.line_to(cx - 5 * dx, y + 27)
    ctx.set_source_rgba(*wa(hexc('#FFB347'), 0.75)); ctx.set_line_width(3.5); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    ctx.restore()
    for cx in (x0 + 6, x1 - 6):
        ctx.arc(cx, y + 20, 9, 0, 2 * math.pi); fill_stroke(ctx, hexc('#55556A'), OUTL2, 3)
        a = t * 6 * dx
        ctx.move_to(cx, y + 20); ctx.line_to(cx + math.cos(a) * 7, y + 20 + math.sin(a) * 7); ctx.set_source_rgba(*OUTL2); ctx.set_line_width(2); ctx.stroke()


def vapor_state(h, t):
    u = t % h['every']; idle = h['every'] - h['warn'] - h['blast']
    if u < idle:
        return 'idle', 0.0
    if u < idle + h['warn']:
        return 'warn', (u - idle) / h['warn']
    return 'blast', (u - idle - h['warn']) / h['blast']


def hz_vapor(ctx, h, state, u):
    x, y = px(h['x']), px(h['y'])
    rrect(ctx, x - 17, y - 17, 34, 34, 6); fill_stroke(ctx, hexc('#3A3A46'), OUTL2, 4)
    for k in range(4):
        ctx.move_to(x - 11, y - 9 + k * 6); ctx.line_to(x + 11, y - 9 + k * 6)
    ctx.set_source_rgba(*OUTL2); ctx.set_line_width(2.5); ctx.stroke()
    if state == 'warn':
        for k in range(4):
            a = k * 1.6 + u * 3; rr = 6 + u * 10
            ctx.arc(x + math.cos(a) * 8, y - 8 - u * 16 - k * 3, rr * 0.5, 0, 2 * math.pi); ctx.set_source_rgba(0.85, 0.85, 0.9, 0.35 * (1 - u * 0.5)); ctx.fill()
    elif state == 'blast':
        R = h['radius'] * (0.4 + 0.6 * e_out_cubic(min(1, u * 2.5)))
        g = cairo.RadialGradient(x, y, 4, x, y, R); g.add_color_stop_rgba(0, 1, 1, 1, 0.85); g.add_color_stop_rgba(1, 0.9, 0.9, 0.95, 0.0)
        ctx.set_source(g); ctx.arc(x, y, R, 0, 2 * math.pi); ctx.fill()
        for k in range(8):
            a = k * math.pi / 4
            ctx.arc(x + math.cos(a) * R * 0.75, y + math.sin(a) * R * 0.75, 8 + u * 6, 0, 2 * math.pi)
            ctx.set_source_rgba(0.95, 0.95, 1, 0.5 * (1 - u)); ctx.fill()


def hz_barril(ctx, h, state, u, t=0.0):
    x, y = px(h['x']), px(h['y'])
    if state == 'boom':
        R = h['radius'] * e_out_cubic(u)
        g = cairo.RadialGradient(x, y, 4, x, y, R); g.add_color_stop_rgba(0, 1, 0.95, 0.7, 1 - u)
        g.add_color_stop_rgba(0.4, 1, 0.55, 0.15, 0.85 * (1 - u)); g.add_color_stop_rgba(1, 0.6, 0.1, 0.05, 0)
        ctx.set_source(g); ctx.arc(x, y, R, 0, 2 * math.pi); ctx.fill()
        ctx.arc(x, y, R, 0, 2 * math.pi); ctx.set_source_rgba(1, 0.8, 0.4, 0.7 * (1 - u)); ctx.set_line_width(6 * (1 - u) + 1); ctx.stroke()
        return
    shadow(ctx, x, y + 17, 15)
    blink = state == 'fuse' and int(u * 10) % 2 == 0
    sq = 1 + (0.06 * math.sin(t * 40) if state == 'fuse' else 0)
    ctx.save(); ctx.translate(x, y); ctx.scale(sq, 1 / sq)
    rrect(ctx, -14, -18, 28, 36, 8); fill_stroke(ctx, hexc('#FF6A5A') if blink else hexc('#B8322A'), OUTL2, 5)
    for yy in (-10, 10):
        ctx.move_to(-14, yy); ctx.line_to(14, yy)
    ctx.set_source_rgba(*hexc('#3A3A46')); ctx.set_line_width(3.5); ctx.stroke()
    star_path(ctx, 0, 0, 7, n=6, inner=0.5); fill_stroke(ctx, GOLD, OUTL2, 2)
    ctx.restore()
    ctx.move_to(x + 4, y - 18); ctx.curve_to(x + 8, y - 26, x + 2, y - 28, x + 7, y - 33); ctx.set_source_rgba(*OUTL2); ctx.set_line_width(2.5); ctx.stroke()
    if state == 'fuse':
        g = cairo.RadialGradient(x + 7, y - 33, 1, x + 7, y - 33, 10); g.add_color_stop_rgba(0, 1, 0.9, 0.4, 1); g.add_color_stop_rgba(1, 1, 0.5, 0.1, 0)
        ctx.set_source(g); ctx.arc(x + 7, y - 33, 10, 0, 2 * math.pi); ctx.fill()


def hz_portal(ctx, x, y, col, t):
    c = hexc(col)
    g = cairo.RadialGradient(x, y, 4, x, y, 38); g.add_color_stop_rgba(0, *wa(c, 0.9)); g.add_color_stop_rgba(0.6, *wa(shade(c, -0.5), 0.6)); g.add_color_stop_rgba(1, *wa(c, 0))
    ctx.set_source(g); ctx.arc(x, y, 38, 0, 2 * math.pi); ctx.fill()
    ellipse(ctx, x, y, 22, 22); ctx.set_source_rgba(*OUTL2); ctx.set_line_width(5); ctx.stroke()
    for k in range(3):
        a0 = t * 3 + k * 2 * math.pi / 3
        ctx.new_path(); ctx.arc(x, y, 18 - k * 4, a0, a0 + 2.2)
        ctx.set_source_rgba(*wa(shade(c, 0.4), 0.95)); ctx.set_line_width(3.5); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    ctx.arc(x, y, 5, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.9); ctx.fill()


def hz_rayo(ctx, h, t):
    x, y, L = px(h['x']), px(h['y']), h['length']
    a0 = t * 2 * math.pi / h['period']
    for k in range(h['arms']):
        a = a0 + k * 2 * math.pi / h['arms']
        ex, ey = x + math.cos(a) * L, y + math.sin(a) * L
        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        for (lw, al) in ((24, 0.15), (14, 0.35), (6, 0.9), (2.5, 1.0)):
            ctx.move_to(x, y); ctx.line_to(ex, ey)
            col = (1, 1, 1) if lw < 3 else (0.5, 0.9, 1.0)
            ctx.set_source_rgba(col[0], col[1], col[2], al); ctx.set_line_width(lw); ctx.stroke()
        g = cairo.RadialGradient(ex, ey, 1, ex, ey, 16); g.add_color_stop_rgba(0, 0.8, 1, 1, 0.9); g.add_color_stop_rgba(1, 0.5, 0.9, 1, 0)
        ctx.set_source(g); ctx.arc(ex, ey, 16, 0, 2 * math.pi); ctx.fill()
    g = cairo.RadialGradient(x, y, 2, x, y, 40); g.add_color_stop_rgba(0, 0.8, 1, 1, 0.9); g.add_color_stop_rgba(1, 0.4, 0.8, 1, 0)
    ctx.set_source(g); ctx.arc(x, y, 40, 0, 2 * math.pi); ctx.fill()
    ctx.arc(x, y, 15, 0, 2 * math.pi); fill_stroke(ctx, hexc('#BFF4FF'), OUTL2, 4)
    ctx.arc(x - 4, y - 4, 4, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.9); ctx.fill()


# ================================================================ dibujo completo de una arena
def draw_static(ctx, aid, t=0.0, with_obstacles=True):
    floor(ctx, aid)
    A = ARENAS[aid]
    for h in A['hazards']:
        if h['type'] == 'lodo':
            hz_lodo(ctx, h, t)
    if with_obstacles:
        draw_obstacles(ctx, aid, t)


def draw_obstacles(ctx, aid, t=0.0):
    for (x, y, w, h, k) in sorted(ARENAS[aid]['obstacles'], key=lambda o: o[1]):
        f = OBSTACLE_DRAW[k]
        if k in ('altar', 'boiler', 'books'):
            f(ctx, px(x), px(y), px(w), px(h), t)
        else:
            f(ctx, px(x), px(y), px(w), px(h))


GROUND = {'lodo', 'pinchos', 'cinta', 'vapor', 'portal'}


def draw_hazards(ctx, aid, t, demo=True, layer=None):
    A = ARENAS[aid]
    for h in A['hazards']:
        ty = h['type']
        if layer == 'ground' and ty not in GROUND:
            continue
        if layer == 'top' and ty in GROUND:
            continue
        if ty == 'lodo':
            hz_lodo(ctx, h, t, static=False)
        elif ty == 'raices' and demo:
            hz_raices(ctx, px(13.5), px(4.5), 'warn', t)
            hz_raices(ctx, px(17.0), px(11.0), 'active', 0.6)
        elif ty == 'pinchos':
            st = pinchos_state(h, t)
            for (tx, tyy) in h['tiles']:
                hz_pincho_tile(ctx, tx, tyy, st)
        elif ty == 'fantasma':
            x, y, dx = path_pos(h['path'], h['speed'], t)
            hz_fantasma(ctx, x, y, t, 1 if dx >= 0 else -1)
        elif ty == 'cinta':
            hz_cinta(ctx, h, t)
        elif ty == 'vapor':
            st, u = vapor_state(h, t); hz_vapor(ctx, h, st, u)
        elif ty == 'barril':
            hz_barril(ctx, h, 'idle', 0, t)
        elif ty == 'portal':
            hz_portal(ctx, px(h['a'][0]), px(h['a'][1]), h['color'], t)
            hz_portal(ctx, px(h['b'][0]), px(h['b'][1]), h['color'], t + 1)
        elif ty == 'rayo':
            hz_rayo(ctx, h, t)
