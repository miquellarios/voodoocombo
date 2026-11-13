"""Hoja de personajes v3: mago, trol, gnomo y nigromante."""
import cairo, math, sys
from gfx import *
from heroes import *
from stylesheet import fog, logo2
from world import Doll


def main(out):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); ctx = cairo.Context(s)
    ctx.set_source_rgba(*hexc('#0B0710')); ctx.paint()
    g = cairo.RadialGradient(W / 2, 100, 50, W / 2, 200, 1100)
    g.add_color_stop_rgba(0, *wa(hexc('#4A1022'), 0.85)); g.add_color_stop_rgba(1, *wa(hexc('#0B0710'), 0))
    ctx.set_source(g); ctx.paint()
    fog(ctx, 3, 14, 700, 1000, hexc('#1E3A2A'), 0.35); fog(ctx, 4, 10, 0, 500, hexc('#2A1440'), 0.3)
    logo2(ctx, W / 2, 150, "New Rocker", 0.5)
    t = 1.3
    xs = [300, 740, 1180, 1620]
    for i, x in enumerate(xs):
        d = Doll(i); d.r = 105; d.x, d.y = x, 600; d.col = PCOL3[i]; d.marker = False; d.look = (0.35, 0.25)
        g2 = cairo.RadialGradient(x, 640, 20, x, 640, 270)
        g2.add_color_stop_rgba(0, *wa(d.col, 0.22)); g2.add_color_stop_rgba(1, *wa(d.col, 0))
        ctx.set_source(g2); ctx.arc(x, 640, 270, 0, 2 * math.pi); ctx.fill()
        draw_hero(ctx, d, t, t)
        k = KINDS[i]
        draw_text(ctx, HERO_NAME[k], x, 800, 50, fam="New Rocker", fill=d.col, ow=4, oc=OUT2)
        draw_text(ctx, HERO_ROLE[k], x, 845, 26, fam=FB, bold=True, fill=DIM)
    rrect(ctx, 360, 885, 1200, 172, 24); ctx.set_source_rgba(*hexc('#120C1A')); ctx.fill_preserve()
    ctx.set_source_rgba(*STITCH); ctx.set_line_width(3); ctx.set_dash([12, 9]); ctx.stroke(); ctx.set_dash([])
    ctx.save(); rrect(ctx, 366, 891, 1188, 160, 20); ctx.clip()
    for k in range(40):
        for j in range(6):
            ctx.rectangle(366 + k * 30, 891 + j * 30, 30, 30)
            ctx.set_source_rgba(*(hexc('#1A2219') if (k + j) % 2 == 0 else hexc('#151C14'))); ctx.fill()
    for i in range(4):
        d = Doll(i); d.r = 33; d.x, d.y = 780 + i * 175, 985; d.col = PCOL3[i]; d.look = (0.5, 0.3)
        draw_hero(ctx, d, t, t, crown=(i == 0))
        for c in range(3):
            draw_coin(ctx, d.x + 60 + c * 26, 1015 - c * 30, t + c, c * 1.3, r=14)
    ctx.restore()
    draw_text(ctx, "TAMAÑO REAL", 400, 955, 26, fam=FB, bold=True, fill=DIM, align="l")
    draw_text(ctx, "EN PARTIDA", 400, 989, 26, fam=FB, bold=True, fill=DIM, align="l")
    vignette(ctx, 0.55)
    s.write_to_png(out)


if __name__ == '__main__':
    main(sys.argv[1])
