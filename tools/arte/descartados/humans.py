"""Personajes v4: humanoides de fantasía oscura (maga, brujo, trol chamán, gnoma inventora). Diseños originales."""
import cairo, math, random
from gfx import *
from chars import OUT2, THREAD, BONE, weave, bez, stitched

KINDS = ['maga', 'trol', 'gnoma', 'brujo']
HERO_NAME = {'maga': 'BRASA', 'trol': 'COLMILLO', 'gnoma': 'TUERCA', 'brujo': 'CRIPTA'}
HERO_ROLE = {'maga': 'Maga del fuego', 'trol': 'Trol chamán', 'gnoma': 'Gnoma inventora', 'brujo': 'Brujo de las almas'}
PCOL4 = [hexc('#C9363F'), hexc('#2F6FC4'), hexc('#4E9A2E'), hexc('#D6CDB8')]


# ---------------------------------------------------------------- utilidades
def path_pts(ctx, pts, close=True):
    ctx.new_path(); ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    if close:
        ctx.close_path()


def ofill(ctx, path, fill, ow):
    path(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
    path()
    ctx.set_source(fill) if isinstance(fill, cairo.Pattern) else ctx.set_source_rgba(*fill)
    ctx.fill()


def vgrad(y0, y1, c0, c1, mid=None):
    g = cairo.LinearGradient(0, y0, 0, y1)
    g.add_color_stop_rgba(0, *c0)
    if mid:
        g.add_color_stop_rgba(0.5, *mid)
    g.add_color_stop_rgba(1, *c1)
    return g


def cloth(ctx, path, col, r, y0, y1, ow, tex=0.55):
    ofill(ctx, path, vgrad(y0, y1, shade(col, 0.15), shade(col, -0.45), col), ow)
    ctx.save(); path(); ctx.clip(); ctx.set_source(weave(r * 0.7)); ctx.paint_with_alpha(tex)
    ctx.translate(-0.05 * r, 0.02 * r); path(); ctx.set_source_rgba(*wa(hexc('#FFE8D0'), 0.22)); ctx.set_line_width(0.07 * r); ctx.stroke()
    ctx.restore()


def glow(ctx, x, y, rad, col, a):
    g = cairo.RadialGradient(x, y, 0, x, y, rad)
    g.add_color_stop_rgba(0, *wa(col, a)); g.add_color_stop_rgba(0.4, *wa(col, a * 0.45)); g.add_color_stop_rgba(1, *wa(col, 0))
    ctx.set_source(g); ctx.arc(x, y, rad, 0, 2 * math.pi); ctx.fill()


def robe_path(ctx, r, tw=0.34, hw=0.56, ty=-0.32, hy=0.86, tattered=False, seed=1):
    ctx.new_path(); ctx.move_to(-tw * r, ty * r)
    ctx.curve_to(-(tw + 0.1) * r, (ty + 0.35) * r, -hw * r, (hy - 0.45) * r, -hw * r, hy * r)
    n = 8; rng = random.Random(seed)
    for i in range(1, n + 1):
        x = -hw * r + i * (2 * hw * r / n)
        if tattered:
            ctx.line_to(x - hw * r / n * 0.5, hy * r + rng.uniform(0.04, 0.12) * r)
            ctx.line_to(x, hy * r - rng.uniform(0.0, 0.04) * r)
        else:
            ctx.curve_to(x - hw * r / n * 0.66, hy * r + 0.05 * r, x - hw * r / n * 0.33, hy * r + 0.05 * r, x, hy * r)
    ctx.curve_to(hw * r, (hy - 0.45) * r, (tw + 0.1) * r, (ty + 0.35) * r, tw * r, ty * r)
    ctx.curve_to(tw * 0.5 * r, (ty - 0.07) * r, -tw * 0.5 * r, (ty - 0.07) * r, -tw * r, ty * r)
    ctx.close_path()


def sleeve_path(ctx, r, s, cuff_y=0.24, wide=0.62):
    path_pts(ctx, [(s * 0.3 * r, -0.3 * r), (s * 0.44 * r, -0.26 * r), (s * 0.54 * r, -0.02 * r),
                   (s * wide * r, cuff_y * r), (s * 0.4 * r, (cuff_y + 0.02) * r), (s * 0.3 * r, -0.02 * r)])


def almond(ctx, r, ex, ey, look, iris, size=1.0):
    w, h = 0.075 * r * size, 0.06 * r * size
    def shape():
        ctx.new_path(); ctx.move_to(ex - w, ey + h * 0.1)
        ctx.curve_to(ex - w * 0.5, ey - h, ex + w * 0.5, ey - h * 1.05, ex + w, ey - h * 0.15)
        ctx.curve_to(ex + w * 0.55, ey + h * 0.85, ex - w * 0.5, ey + h * 0.85, ex - w, ey + h * 0.1); ctx.close_path()
    shape(); ctx.set_source_rgba(*hexc('#F4EEE6')); ctx.fill()
    ctx.save(); shape(); ctx.clip()
    ix, iy = ex + look[0] * w * 0.3, ey + look[1] * h * 0.2
    ctx.arc(ix, iy, h * 0.82, 0, 2 * math.pi); g = cairo.RadialGradient(ix, iy, 0, ix, iy, h * 0.82)
    g.add_color_stop_rgba(0, *shade(iris, 0.3)); g.add_color_stop_rgba(1, *shade(iris, -0.35)); ctx.set_source(g); ctx.fill()
    ctx.arc(ix, iy, h * 0.4, 0, 2 * math.pi); ctx.set_source_rgba(*hexc('#120A14')); ctx.fill()
    ctx.arc(ix + h * 0.3, iy - h * 0.3, h * 0.22, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.95); ctx.fill()
    ctx.restore()
    ctx.new_path(); ctx.move_to(ex - w * 1.1, ey + h * 0.15); ctx.curve_to(ex - w * 0.5, ey - h * 1.05, ex + w * 0.5, ey - h * 1.1, ex + w * 1.15, ey - h * 0.2)
    ctx.set_source_rgba(*hexc('#120A14')); ctx.set_line_width(0.028 * r); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()


def eyes(ctx, r, cx, cy, look, blink, glowcol=None, sep=0.13, brow=0.0, size=1.0, iris=None):
    for s in (-1, 1):
        ex, ey = cx + s * sep * r, cy
        if blink:
            ctx.move_to(ex - 0.055 * r, ey); ctx.line_to(ex + 0.055 * r, ey)
            ctx.set_line_width(0.03 * r); ctx.set_source_rgba(*OUT2); ctx.stroke(); continue
        if glowcol:
            glow(ctx, ex, ey, 0.24 * r * size, glowcol, 1.0)
            ellipse(ctx, ex, ey, 0.06 * r * size, 0.04 * r * size); ctx.set_source_rgba(*shade(glowcol, 0.6)); ctx.fill()
            ellipse(ctx, ex, ey, 0.03 * r * size, 0.02 * r * size); ctx.set_source_rgba(1, 1, 1, 1); ctx.fill()
        elif iris is not None:
            almond(ctx, r, ex, ey, (look[0] if s > 0 else look[0], look[1]), iris, size)
        else:
            ellipse(ctx, ex + look[0] * 0.012 * r, ey + look[1] * 0.01 * r, 0.045 * r * size, 0.064 * r * size)
            ctx.set_source_rgba(*hexc('#1A1020')); ctx.fill()
            ctx.arc(ex + look[0] * 0.012 * r + 0.015 * r, ey - 0.022 * r, 0.016 * r * size, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.9); ctx.fill()
        ctx.move_to(ex - s * 0.08 * r, cy - 0.11 * r - brow * r); ctx.curve_to(ex - s * 0.02 * r, cy - 0.125 * r, ex + s * 0.03 * r, cy - 0.12 * r + brow * r, ex + s * 0.08 * r, cy - 0.09 * r + brow * r)
        ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_line_width(0.035 * r); ctx.set_source_rgba(*OUT2); ctx.stroke()


def staff(ctx, r, x, top, bottom, wood=hexc('#5B3B22')):
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for (lw, c) in ((0.13 * r, OUT2), (0.065 * r, wood)):
        ctx.move_to(x, bottom * r); ctx.curve_to(x + 0.03 * r, (bottom - 0.6) * r, x - 0.02 * r, (top + 0.5) * r, x + 0.02 * r, top * r)
        ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()


def mini_voodoo(ctx, x, y, s, rot=0.0):
    ctx.save(); ctx.translate(x, y); ctx.rotate(rot)
    ctx.new_path(); ctx.arc(0, -s * 0.55, s * 0.42, 0, 2 * math.pi); ellipse(ctx, 0, s * 0.25, s * 0.38, s * 0.5)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(s * 0.22); ctx.stroke_preserve(); ctx.set_source_rgba(*hexc('#B89A6A')); ctx.fill()
    ctx.set_source(weave(s)); ctx.new_path(); ctx.arc(0, -s * 0.55, s * 0.42, 0, 2 * math.pi); ellipse(ctx, 0, s * 0.25, s * 0.38, s * 0.5); ctx.fill()
    for ex in (-0.15, 0.15):
        ctx.move_to(ex * s - s * 0.07, -s * 0.62); ctx.line_to(ex * s + s * 0.07, -s * 0.48)
        ctx.move_to(ex * s + s * 0.07, -s * 0.62); ctx.line_to(ex * s - s * 0.07, -s * 0.48)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(s * 0.07); ctx.stroke()
    for (a, c) in ((-0.9, hexc('#FF5A5F')), (-2.3, hexc('#FFD23F'))):
        x1, y1 = math.cos(a) * s * 0.9, -s * 0.2 + math.sin(a) * s * 0.9
        ctx.move_to(0, -s * 0.2); ctx.line_to(x1, y1); ctx.set_source_rgba(*hexc('#C9CCD8')); ctx.set_line_width(s * 0.07); ctx.stroke()
        ctx.arc(x1, y1, s * 0.13, 0, 2 * math.pi); fill_stroke(ctx, c, OUT2, s * 0.06)
    ctx.restore()


# ---------------------------------------------------------------- personajes
def draw_maga(ctx, r, t, col, look, blink, lift):
    ow = 0.06 * r
    skin = hexc('#EDBE98'); hair = hexc('#8A2E1C')
    # pelo largo por detrás
    def hair_back():
        ctx.new_path(); ctx.move_to(-0.36 * r, -0.85 * r)
        ctx.curve_to(-0.55 * r, -0.5 * r, -0.5 * r, -0.1 * r, -0.42 * r, 0.05 * r)
        ctx.curve_to(-0.3 * r, 0.0, -0.2 * r, -0.2 * r, 0, -0.25 * r)
        ctx.curve_to(0.2 * r, -0.2 * r, 0.3 * r, 0.0, 0.42 * r, 0.05 * r)
        ctx.curve_to(0.5 * r, -0.1 * r, 0.55 * r, -0.5 * r, 0.36 * r, -0.85 * r); ctx.close_path()
    ofill(ctx, hair_back, vgrad(-0.9 * r, 0.05 * r, shade(hair, 0.15), shade(hair, -0.4)), ow)
    # bastón con fuego (detrás de la mano derecha)
    staff(ctx, r, 0.62 * r, -1.0, 0.98)
    fl = 0.8 + 0.2 * math.sin(t * 13) * math.sin(t * 7.3)
    glow(ctx, 0.64 * r, -1.12 * r, 0.6 * r, hexc('#FF7A2A'), 0.75 * fl)
    ctx.new_path(); ctx.move_to(0.64 * r, -1.42 * r - 0.04 * r * math.sin(t * 11))
    ctx.curve_to(0.78 * r, -1.2 * r, 0.76 * r, -1.02 * r, 0.64 * r, -1.0 * r)
    ctx.curve_to(0.52 * r, -1.02 * r, 0.5 * r, -1.2 * r, 0.64 * r, -1.42 * r - 0.04 * r * math.sin(t * 11))
    fill_stroke(ctx, hexc('#FFB347'), OUT2, ow)
    ellipse(ctx, 0.64 * r, -1.1 * r, 0.05 * r, 0.08 * r); ctx.set_source_rgba(1, 0.96, 0.8, 1); ctx.fill()
    _legs(ctx, r, lift, hexc('#2A1B1B'), ow)
    cloth(ctx, lambda: robe_path(ctx, r), col, r, -0.35 * r, 0.9 * r, ow)
    ctx.save(); robe_path(ctx, r); ctx.clip()
    for (x0, x1) in ((-0.12, -0.25), (0.14, 0.3), (0.0, 0.02)):
        ctx.move_to(x0 * r, 0.2 * r); ctx.curve_to(x0 * r, 0.5 * r, x1 * r, 0.6 * r, x1 * r, 0.9 * r)
    ctx.set_source_rgba(*wa(shade(col, -0.6), 0.5)); ctx.set_line_width(0.03 * r); ctx.stroke()
    ctx.rectangle(-r, 0.8 * r, 2 * r, 0.12 * r); ctx.set_source_rgba(*wa(GOLD_DK, 0.9)); ctx.fill()
    ctx.restore()
    rrect(ctx, -0.36 * r, 0.1 * r, 0.72 * r, 0.11 * r, 0.03 * r); fill_stroke(ctx, hexc('#2A1408'), OUT2, ow)
    rrect(ctx, -0.07 * r, 0.085 * r, 0.14 * r, 0.14 * r, 0.03 * r); fill_stroke(ctx, GOLD, OUT2, ow * 0.7)
    mini_voodoo(ctx, -0.26 * r, 0.32 * r, 0.11 * r, 0.25)
    for s in (-1, 1):
        cloth(ctx, lambda s=s: sleeve_path(ctx, r, s), shade(col, -0.05), r, -0.3 * r, 0.3 * r, ow)
        ctx.arc(s * 0.52 * r, 0.31 * r, 0.075 * r, 0, 2 * math.pi); fill_stroke(ctx, skin, OUT2, ow)
    # cuello alto
    path_pts(ctx, [(-0.2 * r, -0.36 * r), (-0.27 * r, -0.5 * r), (0, -0.38 * r), (0.27 * r, -0.5 * r), (0.2 * r, -0.36 * r), (0, -0.28 * r)])
    fill_stroke(ctx, shade(col, -0.3), OUT2, ow * 2)
    _head(ctx, r, skin, ow, -0.72, 0.31, 0.35)
    eyes(ctx, r, 0, -0.7 * r, look, blink, sep=0.125, brow=0.025, iris=hexc('#F2A23A'))
    if not blink:
        for sx_ in (-1, 1):
            glow(ctx, sx_ * 0.125 * r, -0.7 * r, 0.12 * r, hexc('#FF7A2A'), 0.35)
    ctx.move_to(-0.06 * r, -0.565 * r); ctx.curve_to(-0.02 * r, -0.55 * r, 0.04 * r, -0.55 * r, 0.08 * r, -0.585 * r)
    ctx.set_source_rgba(*hexc('#7A2E2A')); ctx.set_line_width(0.025 * r); ctx.stroke()
    # flequillo
    ctx.new_path(); ctx.move_to(-0.33 * r, -0.72 * r); ctx.curve_to(-0.3 * r, -1.05 * r, 0.2 * r, -1.1 * r, 0.33 * r, -0.8 * r)
    ctx.curve_to(0.2 * r, -0.86 * r, 0.05 * r, -0.86 * r, -0.05 * r, -0.8 * r); ctx.curve_to(-0.15 * r, -0.9 * r, -0.25 * r, -0.8 * r, -0.33 * r, -0.72 * r)
    fill_stroke(ctx, vgrad(-1.05 * r, -0.72 * r, shade(hair, 0.2), hair), OUT2, ow * 2)
    # sombrero de bruja/maga
    def hat():
        ctx.new_path(); ctx.move_to(-0.3 * r, -0.98 * r)
        ctx.curve_to(-0.2 * r, -1.35 * r, 0.05 * r, -1.7 * r, 0.12 * r, -1.95 * r)
        ctx.curve_to(0.3 * r, -2.0 * r, 0.5 * r, -1.88 * r, 0.56 * r, -1.75 * r)
        ctx.curve_to(0.38 * r, -1.78 * r, 0.28 * r, -1.55 * r, 0.32 * r, -0.98 * r); ctx.close_path()
    hc = hexc('#2A1B3A')
    cloth(ctx, hat, hc, r, -2.0 * r, -0.95 * r, ow, tex=0.4)
    rrect(ctx, -0.32 * r, -1.08 * r, 0.64 * r, 0.1 * r, 0.03 * r); fill_stroke(ctx, col, OUT2, ow)
    star_path(ctx, 0.0, -1.03 * r, 0.06 * r); fill_stroke(ctx, GOLD, OUT2, ow * 0.6)
    ctx.new_path(); ellipse(ctx, 0, -0.97 * r, 0.62 * r, 0.12 * r)
    ofill(ctx, lambda: (ctx.new_path(), ellipse(ctx, 0, -0.97 * r, 0.62 * r, 0.12 * r)), vgrad(-1.1 * r, -0.85 * r, shade(hc, 0.2), hc), ow)


def draw_brujo(ctx, r, t, col, look, blink, lift):
    ow = 0.06 * r
    hood = hexc('#2A1F38'); skin = hexc('#C8C0D2')
    def hood_back():
        ctx.new_path(); ctx.move_to(0, -1.25 * r)
        ctx.curve_to(0.42 * r, -1.22 * r, 0.6 * r, -0.8 * r, 0.52 * r, -0.3 * r)
        ctx.line_to(-0.52 * r, -0.3 * r); ctx.curve_to(-0.6 * r, -0.8 * r, -0.42 * r, -1.22 * r, 0, -1.25 * r); ctx.close_path()
    cloth(ctx, hood_back, hood, r, -1.25 * r, -0.3 * r, ow)
    _legs(ctx, r, lift, hexc('#1A1420'), ow)
    cloth(ctx, lambda: robe_path(ctx, r, tattered=True, seed=7), col, r, -0.35 * r, 0.95 * r, ow)
    ctx.save(); robe_path(ctx, r, tattered=True, seed=7); ctx.clip()
    ctx.rectangle(-0.08 * r, -0.3 * r, 0.16 * r, 1.3 * r); ctx.set_source_rgba(*wa(hood, 0.9)); ctx.fill()
    for k in range(4):
        y = 0.0 + k * 0.2 * r
        ctx.move_to(-0.04 * r, y); ctx.line_to(0.04 * r, y + 0.05 * r); ctx.line_to(-0.02 * r, y + 0.1 * r)
    ctx.set_source_rgba(*hexc('#B06BFF')); ctx.set_line_width(0.025 * r); ctx.stroke()
    ctx.restore()
    for s in (-1, 1):
        cloth(ctx, lambda s=s: sleeve_path(ctx, r, s, wide=0.66), shade(col, -0.1), r, -0.3 * r, 0.3 * r, ow)
        ctx.arc(s * 0.54 * r, 0.32 * r, 0.07 * r, 0, 2 * math.pi); fill_stroke(ctx, skin, OUT2, ow)
    # hombreras de hueso
    for s in (-1, 1):
        ctx.new_path(); ctx.arc(s * 0.34 * r, -0.3 * r, 0.17 * r, math.pi, 2 * math.pi); ctx.close_path()
        ofill(ctx, lambda s=s: (ctx.new_path(), ctx.arc(s * 0.34 * r, -0.3 * r, 0.17 * r, math.pi * 0.95, math.pi * 2.05), ctx.close_path()),
              vgrad(-0.47 * r, -0.3 * r, hexc('#F2EAD8'), hexc('#A89878')), ow)
        for ex in (-0.05, 0.05):
            ellipse(ctx, s * 0.34 * r + ex * r, -0.38 * r, 0.03 * r, 0.035 * r); ctx.set_source_rgba(*OUT2); ctx.fill()
    # cara en sombra con ojos que brillan
    _head(ctx, r, skin, ow, -0.72, 0.29, 0.33)
    ctx.save(); ctx.new_path(); ellipse(ctx, 0, -0.72 * r, 0.29 * r, 0.33 * r); ctx.clip()
    ctx.set_source(vgrad(-1.05 * r, -0.4 * r, (0.04, 0.02, 0.07, 0.97), (0.04, 0.02, 0.07, 0.5))); ctx.paint(); ctx.restore()
    eyes(ctx, r, 0, -0.74 * r, look, blink, glowcol=hexc('#B06BFF'), sep=0.11, brow=0.03)
    ctx.move_to(-0.08 * r, -0.53 * r); ctx.line_to(0.08 * r, -0.53 * r); ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.025 * r); ctx.stroke()
    # capucha delantera
    ctx.new_path(); ctx.move_to(0, -1.25 * r)
    ctx.curve_to(0.42 * r, -1.22 * r, 0.58 * r, -0.8 * r, 0.42 * r, -0.36 * r)
    ctx.curve_to(0.36 * r, -0.7 * r, 0.25 * r, -1.0 * r, 0, -1.02 * r)
    ctx.curve_to(-0.25 * r, -1.0 * r, -0.36 * r, -0.7 * r, -0.42 * r, -0.36 * r)
    ctx.curve_to(-0.58 * r, -0.8 * r, -0.42 * r, -1.22 * r, 0, -1.25 * r); ctx.close_path()
    fill_stroke(ctx, vgrad(-1.25 * r, -0.36 * r, shade(hood, 0.25), hood), OUT2, ow * 2)
    ctx.move_to(0, -1.24 * r); ctx.curve_to(0.05 * r, -1.15 * r, 0.02 * r, -1.08 * r, 0, -1.03 * r)
    ctx.set_dash([0.05 * r, 0.035 * r]); ctx.set_line_width(0.02 * r); ctx.set_source_rgba(*wa(BONE, 0.5)); ctx.stroke(); ctx.set_dash([])
    # muñeco vudú en la mano derecha y llama de almas en la izquierda
    mini_voodoo(ctx, 0.6 * r, 0.18 * r, 0.13 * r, -0.2)
    fl = 0.8 + 0.2 * math.sin(t * 11)
    glow(ctx, -0.56 * r, 0.12 * r, 0.42 * r, hexc('#B06BFF'), 0.8 * fl)
    ctx.new_path(); ctx.move_to(-0.56 * r, -0.12 * r - 0.04 * r * math.sin(t * 9))
    ctx.curve_to(-0.45 * r, 0.02 * r, -0.46 * r, 0.2 * r, -0.56 * r, 0.22 * r)
    ctx.curve_to(-0.66 * r, 0.2 * r, -0.67 * r, 0.02 * r, -0.56 * r, -0.12 * r - 0.04 * r * math.sin(t * 9))
    fill_stroke(ctx, hexc('#D9A8FF'), OUT2, ow)
    for k in range(3):
        a = t * 1.8 + k * 2.09
        x, y = math.cos(a) * r * 0.95, -r * 0.55 + math.sin(a) * r * 0.35
        glow(ctx, x, y, r * 0.18, hexc('#B06BFF'), 0.7)
        ctx.arc(x, y, r * 0.035, 0, 2 * math.pi); ctx.set_source_rgba(1, 0.9, 1, 0.95); ctx.fill()


def draw_trol(ctx, r, t, col, look, blink, lift):
    ow = 0.06 * r
    skin = hexc('#4F8F86'); hairc = hexc('#E8E2D6')
    # pelo blanco salvaje por detrás
    rng = random.Random(3)
    for k in range(7):
        a = math.radians(-160 + k * 23)
        x0, y0 = math.cos(a) * 0.2 * r, -0.92 * r + math.sin(a) * 0.15 * r
        x1, y1 = math.cos(a) * 0.62 * r, -0.95 * r + math.sin(a) * 0.55 * r + 0.25 * r
        for (lw, c) in ((0.14 * r, OUT2), (0.085 * r, hairc)):
            ctx.move_to(x0, y0); ctx.curve_to(x0, y0 - 0.2 * r, x1, y1 - 0.2 * r, x1, y1)
            ctx.set_line_width(lw); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_source_rgba(*c); ctx.stroke()
    for s in (-1, 1):
        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        for (lw, c) in ((0.14 * r, OUT2), (0.085 * r, hairc)):
            ctx.move_to(s * 0.22 * r, -0.85 * r); ctx.curve_to(s * 0.45 * r, -0.6 * r, s * 0.42 * r, -0.2 * r, s * 0.48 * r, 0.05 * r)
            ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()
    # bastón con farol del pantano (izquierda)
    staff(ctx, r, -0.62 * r, -1.15, 0.98, wood=hexc('#4A3A2A'))
    ctx.move_to(-0.6 * r, -1.1 * r); ctx.line_to(-0.72 * r, -0.95 * r); ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.03 * r); ctx.stroke()
    fl = 0.8 + 0.2 * math.sin(t * 8)
    glow(ctx, -0.74 * r, -0.85 * r, 0.45 * r, hexc('#7BE042'), 0.7 * fl)
    rrect(ctx, -0.82 * r, -0.96 * r, 0.16 * r, 0.2 * r, 0.04 * r); fill_stroke(ctx, wa(hexc('#B8F78A'), 0.9), OUT2, ow)
    for k, a in enumerate((-0.5, -0.2)):
        ctx.move_to(-0.6 * r, -1.0 * r); ctx.line_to(-0.6 * r + math.sin(a) * 0.25 * r, -1.0 * r + math.cos(a) * 0.25 * r)
        ctx.set_source_rgba(*[hexc('#C9363F'), hexc('#2F6FC4')][k]); ctx.set_line_width(0.05 * r); ctx.stroke()
    # piernas con vendas
    for i, s in enumerate((-1, 1)):
        ly = lift[i] * r
        rrect(ctx, s * 0.18 * r - 0.08 * r, 0.45 * r - ly, 0.16 * r, 0.42 * r, 0.06 * r); fill_stroke(ctx, skin, OUT2, ow * 2)
        for k in range(3):
            ctx.move_to(s * 0.18 * r - 0.08 * r, (0.6 + k * 0.08) * r - ly); ctx.line_to(s * 0.18 * r + 0.08 * r, (0.64 + k * 0.08) * r - ly)
        ctx.set_source_rgba(*hexc('#B8A888')); ctx.set_line_width(0.035 * r); ctx.stroke()
        ellipse(ctx, s * 0.2 * r, 0.9 * r - ly, 0.13 * r, 0.07 * r); fill_stroke(ctx, shade(skin, -0.25), OUT2, ow * 2)
    cloth(ctx, lambda: robe_path(ctx, r, tw=0.32, hw=0.48, hy=0.55, tattered=True, seed=3), col, r, -0.35 * r, 0.6 * r, ow)
    # brazos desnudos largos con brazaletes
    for s in (-1, 1):
        def arm(s=s):
            path_pts(ctx, [(s * 0.3 * r, -0.28 * r), (s * 0.46 * r, -0.22 * r), (s * 0.58 * r, 0.35 * r), (s * 0.44 * r, 0.38 * r), (s * 0.32 * r, 0.0)])
        ofill(ctx, arm, vgrad(-0.3 * r, 0.4 * r, shade(skin, 0.15), shade(skin, -0.25)), ow)
        rrect(ctx, s * 0.51 * r - 0.08 * r, 0.12 * r, 0.16 * r, 0.1 * r, 0.03 * r); fill_stroke(ctx, hexc('#8A5A33'), OUT2, ow)
        ctx.arc(s * 0.53 * r, 0.42 * r, 0.08 * r, 0, 2 * math.pi); fill_stroke(ctx, skin, OUT2, ow)
    # collar de colmillos
    ctx.new_path(); ctx.arc(0, -0.42 * r, 0.24 * r, math.radians(20), math.radians(160)); ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.04 * r); ctx.stroke()
    for kk in range(5):
        a = math.radians(35 + kk * 27); x, y = math.cos(a) * 0.24 * r, -0.42 * r + math.sin(a) * 0.24 * r
        ctx.save(); ctx.translate(x, y); ctx.rotate(a - math.pi / 2)
        path_pts(ctx, [(-0.03 * r, 0), (0.03 * r, 0), (0, 0.1 * r)]); fill_stroke(ctx, BONE, OUT2, ow * 0.6); ctx.restore()
    # orejas largas
    for s in (-1, 1):
        ofill(ctx, lambda s=s: path_pts(ctx, [(s * 0.22 * r, -0.86 * r), (s * 0.85 * r, -1.02 * r), (s * 0.7 * r, -0.92 * r),
                                               (s * 0.76 * r, -0.86 * r), (s * 0.24 * r, -0.66 * r)]),
              vgrad(-1.0 * r, -0.66 * r, shade(skin, 0.15), shade(skin, -0.2)), ow)
        ctx.arc(s * 0.6 * r, -0.86 * r, 0.03 * r, 0, 2 * math.pi); fill_stroke(ctx, GOLD, OUT2, ow * 0.5)
    _head(ctx, r, skin, ow, -0.72, 0.27, 0.36)
    eyes(ctx, r, 0, -0.78 * r, look, blink, glowcol=hexc('#FFC93C'), sep=0.11, brow=0.03, size=0.85)
    def nose():
        ctx.new_path(); ctx.move_to(-0.03 * r, -0.76 * r)
        ctx.curve_to(0.06 * r, -0.74 * r, 0.12 * r, -0.6 * r, 0.06 * r, -0.56 * r); ctx.curve_to(0.0, -0.54 * r, -0.06 * r, -0.6 * r, -0.03 * r, -0.76 * r)
    ofill(ctx, nose, shade(skin, -0.15), ow * 0.7)
    ctx.move_to(-0.12 * r, -0.48 * r); ctx.curve_to(-0.04 * r, -0.44 * r, 0.06 * r, -0.44 * r, 0.13 * r, -0.49 * r)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.03 * r); ctx.stroke()
    for s in (-1, 1):
        ofill(ctx, lambda s=s: path_pts(ctx, [(s * 0.1 * r, -0.46 * r), (s * 0.17 * r, -0.62 * r), (s * 0.15 * r, -0.45 * r)]),
              hexc('#F4ECDA'), ow * 0.6)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for k in range(3):
        ctx.move_to(-0.1 * r + k * 0.1 * r, -1.05 * r); ctx.line_to(-0.08 * r + k * 0.1 * r, -0.95 * r)
    ctx.set_source_rgba(*hexc('#C9363F')); ctx.set_line_width(0.03 * r); ctx.stroke()


def draw_gnoma(ctx, r, t, col, look, blink, lift):
    ow = 0.06 * r
    skin = hexc('#F2C7A5'); hairc = hexc('#D9682A')
    # mochila con engranajes y chimenea
    rrect(ctx, -0.42 * r, -0.4 * r, 0.84 * r, 0.62 * r, 0.1 * r); fill_stroke(ctx, hexc('#6B4A2E'), OUT2, ow * 2)
    rrect(ctx, 0.22 * r, -0.85 * r, 0.12 * r, 0.45 * r, 0.03 * r); fill_stroke(ctx, hexc('#4A4A55'), OUT2, ow * 2)
    for k in range(3):
        u = (t * 0.7 + k / 3) % 1
        ctx.arc(0.28 * r + math.sin(u * 6) * 0.05 * r, -0.9 * r - u * 0.5 * r, (0.05 + u * 0.08) * r, 0, 2 * math.pi)
        ctx.set_source_rgba(0.75, 0.72, 0.8, 0.6 * (1 - u)); ctx.fill()
    ctx.save(); ctx.translate(-0.4 * r, -0.35 * r); ctx.rotate(t * 1.2)
    star_path(ctx, 0, 0, 0.15 * r, n=8, inner=0.72, rot=0); fill_stroke(ctx, hexc('#B98A3A'), OUT2, ow * 1.4)
    ctx.arc(0, 0, 0.04 * r, 0, 2 * math.pi); ctx.set_source_rgba(*OUT2); ctx.fill(); ctx.restore()
    _legs(ctx, r, lift, hexc('#3A2A1E'), ow, boot=1.25)
    # peto (mono de trabajo)
    cloth(ctx, lambda: robe_path(ctx, r, tw=0.3, hw=0.42, ty=-0.25, hy=0.75), hexc('#E8DCC4'), r, -0.3 * r, 0.8 * r, ow, tex=0.35)
    def overall():
        path_pts(ctx, [(-0.24 * r, -0.12 * r), (0.24 * r, -0.12 * r), (0.3 * r, 0.2 * r), (0.4 * r, 0.75 * r), (-0.4 * r, 0.75 * r), (-0.3 * r, 0.2 * r)])
    cloth(ctx, overall, col, r, -0.15 * r, 0.8 * r, ow)
    for s in (-1, 1):
        ctx.move_to(s * 0.2 * r, -0.12 * r); ctx.line_to(s * 0.24 * r, -0.32 * r); ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.09 * r); ctx.stroke()
        ctx.move_to(s * 0.2 * r, -0.12 * r); ctx.line_to(s * 0.24 * r, -0.32 * r); ctx.set_source_rgba(*shade(col, -0.2)); ctx.set_line_width(0.05 * r); ctx.stroke()
        ctx.arc(s * 0.2 * r, -0.1 * r, 0.035 * r, 0, 2 * math.pi); fill_stroke(ctx, GOLD, OUT2, ow * 0.5)
    rrect(ctx, -0.12 * r, 0.12 * r, 0.24 * r, 0.16 * r, 0.03 * r); ctx.set_dash([0.04 * r, 0.03 * r]); ctx.set_line_width(0.02 * r)
    ctx.set_source_rgba(*BONE); ctx.stroke(); ctx.set_dash([])
    for s in (-1, 1):
        cloth(ctx, lambda s=s: sleeve_path(ctx, r, s, cuff_y=0.18, wide=0.52), hexc('#E8DCC4'), r, -0.3 * r, 0.25 * r, ow, tex=0.35)
        ctx.arc(s * 0.46 * r, 0.25 * r, 0.08 * r, 0, 2 * math.pi); fill_stroke(ctx, hexc('#6B4A2E'), OUT2, ow)
    # llave inglesa
    ctx.save(); ctx.translate(0.5 * r, 0.2 * r); ctx.rotate(-0.5)
    rrect(ctx, -0.035 * r, -0.45 * r, 0.07 * r, 0.5 * r, 0.03 * r); fill_stroke(ctx, hexc('#9AA0B5'), OUT2, ow * 1.4)
    ctx.new_path(); ctx.arc(0, -0.5 * r, 0.1 * r, math.radians(-60), math.radians(240)); ctx.close_path(); fill_stroke(ctx, hexc('#9AA0B5'), OUT2, ow * 1.4)
    ctx.restore()
    _head(ctx, r, skin, ow, -0.68, 0.34, 0.34)
    for (fx, fy) in ((-0.17, -0.6), (-0.13, -0.57), (0.14, -0.6), (0.18, -0.57)):
        ctx.arc(fx * r, fy * r, 0.012 * r, 0, 2 * math.pi); ctx.set_source_rgba(*hexc('#B5653A')); ctx.fill()
    eyes(ctx, r, 0, -0.68 * r, look, blink, sep=0.13, brow=-0.01, size=1.15, iris=hexc('#3E8A5A'))
    ctx.arc(0, -0.6 * r, 0.045 * r, 0, 2 * math.pi); fill_stroke(ctx, hexc('#E39A7A'), OUT2, ow * 0.6)
    ctx.move_to(-0.1 * r, -0.52 * r); ctx.curve_to(-0.04 * r, -0.46 * r, 0.05 * r, -0.46 * r, 0.1 * r, -0.53 * r)
    ctx.set_source_rgba(*hexc('#7A2E2A')); ctx.set_line_width(0.03 * r); ctx.stroke()
    # pelo: moño desordenado con lápiz y mechones
    ctx.new_path(); ctx.arc(0.0, -1.06 * r, 0.17 * r, 0, 2 * math.pi)
    fill_stroke(ctx, vgrad(-1.22 * r, -0.9 * r, shade(hairc, 0.2), hairc), OUT2, ow * 2)
    ctx.move_to(-0.2 * r, -1.2 * r); ctx.line_to(0.2 * r, -0.95 * r); ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.07 * r); ctx.stroke()
    ctx.move_to(-0.2 * r, -1.2 * r); ctx.line_to(0.2 * r, -0.95 * r); ctx.set_source_rgba(*GOLD); ctx.set_line_width(0.035 * r); ctx.stroke()
    ctx.new_path(); ctx.move_to(-0.34 * r, -0.7 * r); ctx.curve_to(-0.36 * r, -1.0 * r, 0.36 * r, -1.05 * r, 0.34 * r, -0.72 * r)
    ctx.curve_to(0.2 * r, -0.86 * r, 0.0, -0.9 * r, -0.12 * r, -0.84 * r); ctx.curve_to(-0.2 * r, -0.9 * r, -0.3 * r, -0.82 * r, -0.34 * r, -0.7 * r)
    fill_stroke(ctx, vgrad(-1.0 * r, -0.7 * r, shade(hairc, 0.2), hairc), OUT2, ow * 2)
    # gafas de inventora
    rrect(ctx, -0.36 * r, -0.92 * r, 0.72 * r, 0.08 * r, 0.03 * r); fill_stroke(ctx, hexc('#4A3020'), OUT2, ow)
    for k, s in enumerate((-1, 1)):
        cx_ = s * 0.15 * r
        ctx.arc(cx_, -0.88 * r, 0.12 * r, 0, 2 * math.pi); fill_stroke(ctx, hexc('#B98A3A'), OUT2, ow * 1.2)
        ctx.arc(cx_, -0.88 * r, 0.085 * r, 0, 2 * math.pi)
        g = cairo.LinearGradient(cx_ - 0.08 * r, -0.96 * r, cx_ + 0.08 * r, -0.8 * r)
        g.add_color_stop_rgba(0, *hexc('#BFF4FF')); g.add_color_stop_rgba(1, *hexc('#2E7A8A')); ctx.set_source(g); ctx.fill()
        ctx.move_to(cx_ - 0.05 * r, -0.92 * r); ctx.line_to(cx_ - 0.01 * r, -0.96 * r); ctx.set_source_rgba(1, 1, 1, 0.8); ctx.set_line_width(0.02 * r); ctx.stroke()
        if k == 1:
            ctx.move_to(cx_ + 0.03 * r, -0.96 * r); ctx.line_to(cx_ - 0.01 * r, -0.88 * r); ctx.line_to(cx_ + 0.05 * r, -0.81 * r)
            ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.015 * r); ctx.stroke()


def _legs(ctx, r, lift, col, ow, boot=1.0):
    for i, s in enumerate((-1, 1)):
        ly = lift[i] * r
        ellipse(ctx, s * 0.2 * r, 0.9 * r - ly, 0.15 * r * boot, 0.08 * r * boot); fill_stroke(ctx, col, OUT2, ow * 2)


def _head(ctx, r, skin, ow, cy, rx, ry):
    ctx.new_path(); ellipse(ctx, 0, cy * r, rx * r, ry * r)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.stroke()
    ctx.new_path(); ellipse(ctx, 0, cy * r, rx * r, ry * r)
    g = cairo.RadialGradient(-rx * 0.4 * r, (cy - ry * 0.4) * r, 0.02 * r, 0, cy * r, max(rx, ry) * 1.1 * r)
    g.add_color_stop_rgba(0, *shade(skin, 0.15)); g.add_color_stop_rgba(0.6, *skin); g.add_color_stop_rgba(1, *shade(skin, -0.3))
    ctx.set_source(g); ctx.fill()


DRAW = {'maga': draw_maga, 'trol': draw_trol, 'gnoma': draw_gnoma, 'brujo': draw_brujo}
CROWN_Y = {'maga': -2.2, 'trol': -1.35, 'gnoma': -1.45, 'brujo': -1.5}


def draw_human(ctx, d, t, st, crown=False, crown_drop=1.0, alpha=1.0):
    kind = getattr(d, 'kind', KINDS[d.pid])
    r = d.r * (0.88 if kind == 'gnoma' else 1.0); x, y = d.x, d.y
    sp = math.hypot(d.vx, d.vy); moving = sp > 25
    blink_inv = st < d.invuln_until and int(t * 16) % 2 == 0
    a_all = alpha * (0.35 if blink_inv else 1.0)
    pop = e_out_back(prog(st, d.spawn_t, d.spawn_t + 0.3)) if d.spawn_t > -5 else 1.0
    if pop <= 0.01:
        return
    if a_all < 1:
        ctx.push_group()
    ellipse(ctx, x, y + d.r * 1.0, d.r * 0.75 * pop, d.r * 0.24 * pop); ctx.set_source_rgba(0, 0, 0, 0.5); ctx.fill()
    if d.marker:
        shape_path(ctx, d.shape, x, y + d.r * 1.42, d.r * 0.2 * pop); fill_stroke(ctx, d.col, OUT2, d.r * 0.16)
    if st < d.sheep_until:
        draw_sheep(ctx, x, y, d.r * 1.05, t, d.col, d.face)
    else:
        if st < d.ring_until:
            g = cairo.RadialGradient(x, y - r * 0.4, r * 0.4, x, y - r * 0.4, r * 2.0)
            g.add_color_stop_rgba(0, *wa(GOLD, 0.55 + 0.2 * math.sin(t * 10))); g.add_color_stop_rgba(1, *wa(GOLD, 0))
            ctx.set_source(g); ctx.arc(x, y - r * 0.4, r * 2.0, 0, 2 * math.pi); ctx.fill()
        ctx.save()
        bob = -abs(math.sin(d.walk * 0.11)) * r * 0.1 if moving else math.sin(t * 3.4 + d.pid * 1.3) * r * 0.02
        ctx.translate(x, y + bob + (d.r - r) * 0.95); ctx.scale(pop, pop)
        stv = clamp(sp / 1600.0, 0, 0.18)
        if stv > 0.01:
            ang = math.atan2(d.vy, d.vx); ctx.rotate(ang); ctx.scale(1 + stv, 1 - stv * 0.5); ctx.rotate(-ang)
        if abs(d.squash) > 0.001:
            ctx.translate(0, r * 0.95); ctx.scale(1 + d.squash, 1 - d.squash); ctx.translate(0, -r * 0.95)
        lean = clamp(d.vx / 900.0, -0.12, 0.12) if moving else 0
        ctx.rotate(lean + d.tilt)
        if d.face < 0:
            ctx.scale(-1, 1)
        lift = math.sin(d.walk * 0.11) if moving else 0
        blink = ((t + d.blink_off) % 3.3) < 0.11
        look = (d.look[0] * d.face, d.look[1])
        DRAW[kind](ctx, r, t, d.col, look, blink, (max(0, lift) * 0.12, max(0, -lift) * 0.12))
        if st < d.flash_until:
            ctx.new_path(); ellipse(ctx, 0, -0.72 * r, 0.36 * r, 0.38 * r); robe_path(ctx, r)
            ctx.set_source_rgba(1, 1, 1, 0.75); ctx.fill()
        if crown:
            if d.face < 0:
                ctx.scale(-1, 1)
            off = -r * 1.6 * (1 - e_out_bounce(crown_drop))
            draw_crown(ctx, 0, CROWN_Y[kind] * r + off, r * 0.7)
        ctx.restore()
        if st < d.frozen_until:
            draw_ice(ctx, x, y - r * 0.3, d.r * 1.05, t)
        if st < d.stun_until:
            for k2 in range(3):
                a = t * 7 + k2 * 2.09
                star_path(ctx, x + math.cos(a) * r * 0.6, y - r * 1.6 + math.sin(a) * r * 0.18, r * 0.17)
                fill_stroke(ctx, GOLD, OUT2, 2.5)
    if a_all < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(a_all)
