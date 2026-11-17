#!/usr/bin/env python3
"""Estilo "Brasa minimal": logo nuevo y referencia del menú y de los textos en partida.
Uso: python3 export_tipografia.py [carpeta_salida]"""
import cairo, math, os, random, sys
from gfx import *

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_tipo'
UI = os.path.join(OUT, 'assets', 'ui'); REF = os.path.join(OUT, 'referencias')
for d in (UI, REF):
    os.makedirs(d, exist_ok=True)
BONEW = hexc('#EFE7DA'); EMBER = hexc('#FF6A2B'); RED = hexc('#FF3B3B'); D = (0.03, 0.02, 0.04, 1)
B = cairo.FONT_WEIGHT_BOLD


def tpath(c, s, x, y, size, fam, track, weight, align='c'):
    c.select_font_face(fam, cairo.FONT_SLANT_NORMAL, weight); c.set_font_size(size)
    adv = [c.text_extents(ch).x_advance for ch in s]; tot = sum(adv) + track * size * (len(s) - 1)
    x0 = x - tot / 2 if align == 'c' else (x if align == 'l' else x - tot)
    c.new_path(); cx = x0
    for ch, a in zip(s, adv):
        c.move_to(cx, y + size * 0.35); c.text_path(ch); cx += a + track * size
    return x0, tot


def txt(c, s, x, y, size, fam="Cinzel", fill=BONEW, track=0.12, weight=B, align='c', glow=None, outline=None, ow=0):
    x0, tot = tpath(c, s, x, y, size, fam, track, weight, align)
    if glow:
        for k in range(10, 0, -1):
            c.set_source_rgba(glow[0], glow[1], glow[2], 0.05); c.set_line_width(size * 0.035 * k + 1); c.set_line_join(cairo.LINE_JOIN_ROUND); c.stroke_preserve()
    if outline:
        c.set_source_rgba(*outline); c.set_line_width(ow); c.set_line_join(cairo.LINE_JOIN_ROUND); c.stroke_preserve()
    c.set_source_rgba(*fill); c.fill()
    return x0, tot


def embers(c, x, y, w, h, n, seed):
    r = random.Random(seed)
    for _ in range(n):
        ex, ey = x + r.uniform(0, w), y + r.uniform(0, h); rr = r.uniform(1.2, 3.2)
        g = cairo.RadialGradient(ex, ey, 0, ex, ey, rr * 3); g.add_color_stop_rgba(0, 1, 0.62, 0.28, 0.95); g.add_color_stop_rgba(1, 1, 0.4, 0.1, 0)
        c.set_source(g); c.arc(ex, ey, rr * 3, 0, 2 * math.pi); c.fill()


def logo(path):
    Wl, Hl = 1100, 420; s = cairo.ImageSurface(cairo.FORMAT_ARGB32, Wl, Hl); c = cairo.Context(s)
    txt(c, "VOODOO", Wl / 2, 120, 130, track=0.16)
    x0, tot = txt(c, "COMBO", Wl / 2, 280, 150, fill=EMBER, track=0.14, glow=EMBER)
    embers(c, x0, 170, tot, 60, 18, 3)
    c.rectangle(Wl / 2 - 300, 372, 600, 4); c.set_source_rgba(*EMBER); c.fill()
    c.save(); c.translate(x0 + tot - 70, 250); c.rotate(-math.pi / 4)                   # alfiler fino
    c.move_to(-150, 0); c.line_to(120, 0); c.set_source_rgba(*BONEW); c.set_line_width(5); c.set_line_cap(cairo.LINE_CAP_ROUND); c.stroke()
    c.arc(130, 0, 14, 0, 2 * math.pi); c.set_source_rgba(*EMBER); c.fill()
    c.restore()
    s.write_to_png(path)


def reference_menu(path):
    bg = cairo.ImageSurface.create_from_png('out/godot_ui/assets/ui/menu_fondo.png')
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(s); c.set_source_surface(bg, 0, 0); c.paint()
    c.set_source_rgba(0, 0, 0, 0.25); c.paint()
    lg = cairo.ImageSurface.create_from_png(os.path.join(UI, 'logo_brasa.png'))
    c.save(); c.translate(W / 2 - 440, 40); c.scale(0.8, 0.8); c.set_source_surface(lg, 0, 0); c.paint(); c.restore()
    items = ["JUGAR", "TAQUILLA", "CÓMO SE JUEGA", "AJUSTES", "HISTORIAL", "SALIR"]
    for k, it in enumerate(items):
        y = 470 + k * 84; on = k == 0
        x0, tot = txt(c, it, W / 2, y, 44 if on else 38, fill=EMBER if on else BONEW, track=0.22, glow=EMBER if on else None)
        if on:
            c.arc(x0 - 34, y + 2, 7, 0, 2 * math.pi); c.set_source_rgba(*EMBER); c.fill()
            c.rectangle(W / 2 - tot / 2, y + 36, tot, 3); c.fill()
            embers(c, x0, y - 40, tot, 30, 8, 5)
    txt(c, "WASD MOVER  ·  ESPACIO DASH  ·  E HECHIZO", W / 2, 1040, 22, fam="Oswald", fill=wa(BONEW, 0.6), track=0.15, weight=cairo.FONT_WEIGHT_NORMAL)
    s.write_to_png(path)


def reference_ingame(path):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1600, 360); c = cairo.Context(s); c.set_source_rgba(*hexc('#14121A')); c.paint()
    row = [("+1", BONEW, 64), ("+3", EMBER, 76), ("-4", RED, 76), ("¡ROBO!", EMBER, 66), ("x3", EMBER, 76), ("¡ZAS!", FROST, 66), ("1:23", BONEW, 64)]
    for k, (t_, col, sz) in enumerate(row):
        txt(c, t_, 120 + k * 220, 110, sz, fam="Oswald", fill=col, track=0.02, outline=D, ow=7)
    txt(c, "¡VOODOO COMBO!", 800, 270, 84, fill=EMBER, track=0.12, glow=EMBER)
    s.write_to_png(path)


def main():
    logo(os.path.join(UI, 'logo_brasa.png'))
    reference_menu(os.path.join(REF, 'menu_brasa_referencia.png'))
    reference_ingame(os.path.join(REF, 'textos_partida_referencia.png'))
    print('ok', OUT)


if __name__ == '__main__':
    main()
