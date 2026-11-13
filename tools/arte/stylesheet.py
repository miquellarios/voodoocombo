"""Hoja de estilo v2: logo en dos opciones + los cuatro muñecos nuevos + tamaño real en partida."""
import cairo, math, random, sys
from gfx import *
from chars import *
from world import Doll, build_arena_bg

PCOL2 = [hexc('#D8484F'), hexc('#3C7FD0'), hexc('#63A83A'), hexc('#D9D0BE')]
BLOOD = hexc('#5C1018')


def fog(ctx, seed, n, ymin, ymax, col, amax):
    r = random.Random(seed)
    for _ in range(n):
        x, y, rad = r.uniform(-100, W + 100), r.uniform(ymin, ymax), r.uniform(150, 380)
        g = cairo.RadialGradient(x, y, 0, x, y, rad)
        g.add_color_stop_rgba(0, *wa(col, r.uniform(0.3, 1) * amax)); g.add_color_stop_rgba(1, *wa(col, 0))
        ctx.set_source(g); ctx.arc(x, y, rad, 0, 2 * math.pi); ctx.fill()


def logo2(ctx, cx, cy, fam, sc=1.0, sizes=(180, 220)):
    ctx.save(); ctx.translate(cx, cy); ctx.scale(sc, sc)
    bone = lambda x, y, w, h: _lin(y, h, [hexc('#F4ECDA'), hexc('#D8CBB0'), hexc('#A8977A')])
    gold = lambda x, y, w, h: _lin(y, h, [hexc('#FFE7A0'), hexc('#E0A92E'), hexc('#8A5A12')])
    draw_text(ctx, "VOODOO", 0, -sizes[0] * 0.55, sizes[0], fam=fam, grad=bone, ow=10, oc=OUT2, shadow=(0, 12, BLOOD),
              stitch=(tex_pat(sizes[0]), 0.55))
    draw_text(ctx, "COMBO", 0, sizes[1] * 0.45, sizes[1], fam=fam, grad=gold, ow=11, oc=OUT2, shadow=(0, 14, hexc('#3A1A06')),
              stitch=(tex_pat(sizes[1]), 0.5))
    ctx.select_font_face(fam); ctx.set_font_size(sizes[1])
    wc = ctx.text_extents("COMBO").x_advance; wo = ctx.text_extents("O").x_advance
    draw_pin_big(ctx, wc / 2 - wo / 2, sizes[1] * 0.45, sizes[1] * 1.15, -math.pi / 4, head=sizes[1] * 0.1)
    ctx.restore()


def tex_pat(size):
    p = weave(size * 0.3)
    return p


def _lin(y, h, cols):
    g = cairo.LinearGradient(0, y, 0, y + h)
    for i, c in enumerate(cols):
        g.add_color_stop_rgba(i / (len(cols) - 1), *c)
    return g


def main(out):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); ctx = cairo.Context(s)
    ctx.set_source_rgba(*hexc('#0B0710')); ctx.paint()
    g = cairo.RadialGradient(W / 2, 120, 50, W / 2, 200, 1100)
    g.add_color_stop_rgba(0, *wa(hexc('#4A1022'), 0.85)); g.add_color_stop_rgba(1, *wa(hexc('#0B0710'), 0))
    ctx.set_source(g); ctx.paint()
    fog(ctx, 3, 14, 700, 1000, hexc('#1E3A2A'), 0.35)
    fog(ctx, 4, 10, 0, 500, hexc('#2A1440'), 0.35)
    logo2(ctx, 500, 205, "New Rocker", 0.62)
    logo2(ctx, 1420, 205, "Metal Mania", 0.62)
    draw_text(ctx, "A · GÓTICA (New Rocker)", 500, 360, 30, fam=FB, bold=True, fill=DIM)
    draw_text(ctx, "B · DESGARRADA (Metal Mania)", 1420, 360, 30, fam=FB, bold=True, fill=DIM)
    ctx.move_to(960, 60); ctx.line_to(960, 370); ctx.set_dash([10, 8]); ctx.set_line_width(2); ctx.set_source_rgba(*wa(STITCH, 0.8)); ctx.stroke(); ctx.set_dash([])
    t = 1.3
    xs = [300, 740, 1180, 1620]
    for i, x in enumerate(xs):
        d = Doll(i); d.r = 112; d.x, d.y = x, 600; d.col = PCOL2[i]; d.marker = False; d.look = (0.35, 0.25)
        g2 = cairo.RadialGradient(x, 640, 20, x, 640, 260)
        g2.add_color_stop_rgba(0, *wa(d.col, 0.22)); g2.add_color_stop_rgba(1, *wa(d.col, 0))
        ctx.set_source(g2); ctx.arc(x, 640, 260, 0, 2 * math.pi); ctx.fill()
        draw_doll2(ctx, d, t, t, crown=(i == 0))
        draw_text(ctx, PL[i]['name'], x, 790, 44, fam="New Rocker", fill=d.col, ow=4, oc=OUT2)
        sub = ["Botón y ojo en X · alfiler de oro", "Chistera raída · botones desparejados",
               "Seta del pantano · ojo cosido", "Cuernos de hueso · ojo hueco"][i]
        draw_text(ctx, sub, x, 834, 24, fam=FB, bold=True, fill=DIM)
    # tamaño real en partida
    rrect(ctx, 360, 880, 1200, 175, 24); ctx.set_source_rgba(*hexc('#120C1A')); ctx.fill_preserve()
    ctx.set_source_rgba(*STITCH); ctx.set_line_width(3); ctx.set_dash([12, 9]); ctx.stroke(); ctx.set_dash([])
    ctx.save(); rrect(ctx, 366, 886, 1188, 163, 20); ctx.clip()
    for k in range(40):
        for j in range(6):
            ctx.rectangle(366 + k * 30, 886 + j * 30, 30, 30)
            ctx.set_source_rgba(*(hexc('#1A2219') if (k + j) % 2 == 0 else hexc('#151C14'))); ctx.fill()
    for i in range(4):
        d = Doll(i); d.r = 33; d.x, d.y = 780 + i * 175, 975; d.col = PCOL2[i]; d.look = (0.5, 0.3)
        draw_doll2(ctx, d, t, t, crown=(i == 0))
        for c in range(3):
            draw_coin(ctx, d.x + 60 + c * 26, 1010 - c * 30, t + c, c * 1.3, r=14)
    ctx.restore()
    draw_text(ctx, "TAMAÑO REAL", 400, 950, 26, fam=FB, bold=True, fill=DIM, align="l"); draw_text(ctx, "EN PARTIDA", 400, 984, 26, fam=FB, bold=True, fill=DIM, align="l")
    vignette(ctx, 0.55)
    s.write_to_png(out)


if __name__ == '__main__':
    main(sys.argv[1])
