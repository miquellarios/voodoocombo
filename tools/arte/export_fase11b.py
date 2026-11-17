#!/usr/bin/env python3
"""Fase 11 (v2): lobby de mazmorra, cartas de arena para la votación, brillo de la ruleta y emotes nuevos.
Uso: python3 export_fase11b.py [carpeta_salida]   (por defecto out/godot_f11b; copiar su assets/ a la raíz del proyecto)"""
import cairo, json, math, os, random, sys
from gfx import *
from heroes import draw_hero
from world import Doll, fog_layer
import arenas as AR

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_f11b'
UI = os.path.join(OUT, 'assets', 'ui'); REF = os.path.join(OUT, 'referencias')
for d in (UI, REF):
    os.makedirs(d, exist_ok=True)
DARK = hexc('#0B0710'); BONE = hexc('#E8DCC4'); WEB = (0.85, 0.82, 0.9)
SLOTS = (420, 780, 1140, 1500); GY = 760


def cobweb(c, x, y, r, ang0, span=math.pi / 2, a=0.55):
    """Telaraña de esquina: radios y hilos colgantes."""
    n = 6; c.set_line_cap(cairo.LINE_CAP_ROUND)
    pts = []
    for k in range(n + 1):
        ang = ang0 + span * k / n; pts.append(ang)
        c.move_to(x, y); c.line_to(x + math.cos(ang) * r, y + math.sin(ang) * r)
    c.set_source_rgba(*WEB, a); c.set_line_width(1.6); c.stroke()
    for ring in range(1, 6):
        rr = r * ring / 5.5
        for k in range(n):
            a1, a2 = pts[k], pts[k + 1]; am = (a1 + a2) / 2
            p1 = (x + math.cos(a1) * rr, y + math.sin(a1) * rr); p2 = (x + math.cos(a2) * rr, y + math.sin(a2) * rr)
            pm = (x + math.cos(am) * rr * 0.86, y + math.sin(am) * rr * 0.86)
            c.move_to(*p1); c.curve_to(pm[0], pm[1], pm[0], pm[1], *p2)
        c.set_source_rgba(*WEB, a * (1 - ring * 0.08)); c.set_line_width(1.2); c.stroke()


def torch(c, x, y, t=0.0):
    g = cairo.RadialGradient(x, y - 30, 4, x, y - 30, 260)
    g.add_color_stop_rgba(0, 1, 0.62, 0.25, 0.42); g.add_color_stop_rgba(1, 1, 0.4, 0.1, 0)
    c.set_source(g); c.arc(x, y - 30, 260, 0, 2 * math.pi); c.fill()
    rrect(c, x - 9, y - 8, 18, 70, 4); fill_stroke(c, hexc('#3A2A20'), DARK, 4)
    c.move_to(x - 22, y - 10); c.line_to(x + 22, y - 10); c.line_to(x + 14, y + 6); c.line_to(x - 14, y + 6); c.close_path(); fill_stroke(c, hexc('#55556A'), DARK, 4)
    for (dx, h, col) in ((0, 64, '#FF8A3A'), (-8, 44, '#FFB347'), (7, 40, '#FFB347'), (0, 34, '#FFF2C4')):
        c.move_to(x + dx - 13 * h / 64, y - 10); c.curve_to(x + dx - 16 * h / 64, y - 10 - h * 0.5, x + dx - 2, y - 10 - h * 0.8, x + dx, y - 10 - h)
        c.curve_to(x + dx + 4, y - 10 - h * 0.7, x + dx + 16 * h / 64, y - 10 - h * 0.45, x + dx + 13 * h / 64, y - 10); c.close_path()
        c.set_source_rgba(*hexc(col)); c.fill()


def stone_wall(c, y0, y1, rng):
    for row, y in enumerate(range(int(y0), int(y1), 64)):
        off = (row % 2) * 70
        for x in range(-140 + off, W + 140, 140):
            sh = rng.uniform(-0.05, 0.05)
            rrect(c, x + 3, y + 3, 134, 58, 8); c.set_source_rgba(*shade(hexc('#241C2C'), sh)); c.fill()
            c.move_to(x + 10, y + 8); c.line_to(x + 128, y + 8); c.set_source_rgba(1, 1, 1, 0.04); c.set_line_width(2); c.stroke()
            if rng.random() < 0.18:
                c.move_to(x + rng.uniform(20, 110), y + 6)
                for _ in range(3):
                    c.rel_line_to(rng.uniform(-12, 12), rng.uniform(8, 16))
                c.set_source_rgba(0, 0, 0, 0.5); c.set_line_width(1.5); c.stroke()
            if rng.random() < 0.12:
                ellipse(c, x + rng.uniform(20, 120), y + 56, rng.uniform(10, 26), 5); c.set_source_rgba(*wa(hexc('#3E5A2E'), 0.6)); c.fill()


def banner(c, x, y, col, rune):
    c.move_to(x - 10, y - 6); c.line_to(x + 110, y - 6); c.set_source_rgba(*hexc('#3A2A20')); c.set_line_width(10); c.stroke()
    c.move_to(x, y); c.line_to(x + 100, y); c.line_to(x + 100, y + 230); c.line_to(x + 50, y + 200); c.line_to(x, y + 230); c.close_path()
    g = cairo.LinearGradient(0, y, 0, y + 230); g.add_color_stop_rgba(0, *shade(col, -0.2)); g.add_color_stop_rgba(1, *shade(col, -0.6))
    c.set_source(g); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(4); c.stroke()
    c.move_to(x + 8, y + 10); c.line_to(x + 92, y + 10); c.set_dash([8, 6]); c.set_source_rgba(*GOLD_DK); c.set_line_width(2.5); c.stroke(); c.set_dash([])
    c.save(); c.translate(x + 50, y + 100); c.set_source_rgba(*wa(GOLD, 0.85)); c.set_line_width(5); c.set_line_cap(cairo.LINE_CAP_ROUND)
    if rune == 0:
        c.move_to(0, -40); c.line_to(0, 40); c.move_to(0, -10); c.line_to(22, -30); c.move_to(0, 10); c.line_to(-22, -10)
    elif rune == 1:
        c.move_to(-20, 40); c.line_to(0, -40); c.line_to(20, 40); c.move_to(-12, 10); c.line_to(12, 10)
    else:
        c.arc(0, -10, 18, 0, 2 * math.pi); c.move_to(0, 8); c.line_to(0, 40); c.move_to(-16, 26); c.line_to(16, 26)
    c.stroke(); c.restore()


def chain(c, x, y0, y1):
    y = y0
    while y < y1:
        ellipse(c, x, y + 9, 6, 11); c.set_source_rgba(*DARK); c.set_line_width(6); c.stroke_preserve()
        c.set_source_rgba(*hexc('#6E6680')); c.set_line_width(3); c.stroke(); y += 18


def skulls(c, x, y, n, rng):
    for k in range(n):
        sx, sy = x + rng.uniform(-60, 60), y + rng.uniform(-12, 12) - k * 3
        c.arc(sx, sy, 15, math.pi * 0.85, math.pi * 2.15); c.line_to(sx + 9, sy + 15); c.line_to(sx - 9, sy + 15); c.close_path()
        fill_stroke(c, hexc('#CFC6B0'), DARK, 3)
        for ex in (-6, 6):
            c.arc(sx + ex, sy + 1, 4, 0, 2 * math.pi); c.set_source_rgba(*DARK); c.fill()


def dungeon_background(path):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(s)
    c.set_source_rgba(*hexc('#08050C')); c.paint()
    rng = random.Random(21)
    stone_wall(c, -20, GY + 40, rng)
    for ax in (200, W - 200):                                  # arcos de la mazmorra
        c.save(); c.translate(ax, 0)
        c.move_to(-170, GY + 40); c.line_to(-170, 380); c.arc(0, 380, 170, math.pi, 2 * math.pi); c.line_to(170, GY + 40); c.close_path()
        c.set_source_rgba(0.02, 0.01, 0.03, 0.9); c.fill()
        c.arc(0, 380, 170, math.pi, 2 * math.pi); c.set_source_rgba(*hexc('#3A3046')); c.set_line_width(26); c.stroke()
        for k in range(9):
            a = math.pi + k * math.pi / 8
            c.move_to(math.cos(a) * 157, 380 + math.sin(a) * 157); c.line_to(math.cos(a) * 183, 380 + math.sin(a) * 183)
        c.set_source_rgba(*DARK); c.set_line_width(3); c.stroke()
        for k in range(5):                                     # ojos en la oscuridad
            if k % 2 == 0:
                ex, ey = rng.uniform(-80, 80), rng.uniform(420, 640)
                for dx in (-9, 9):
                    c.arc(ex + dx, ey, 3.2, 0, 2 * math.pi); c.set_source_rgba(1, 0.75, 0.2, 0.75); c.fill()
        c.restore()
    for (bx, col, rn) in ((560, hexc('#5C1018'), 0), (1260, hexc('#2A4A26'), 1), (900, hexc('#3A1E5A'), 2)):
        banner(c, bx, 40, col, rn)
    for x in (120, 470, 1450, 1800):
        chain(c, x, 0, rng.uniform(160, 300))
    for x in (380, 960, 1540):
        torch(c, x, 330)
    c.rectangle(0, GY + 40, W, H); lg = cairo.LinearGradient(0, GY + 40, 0, H)
    lg.add_color_stop_rgba(0, *hexc('#1A1222')); lg.add_color_stop_rgba(1, *hexc('#050307')); c.set_source(lg); c.fill()
    for k in range(14):                                        # losas del suelo
        x = k * 150 - 40
        c.move_to(x, GY + 40); c.line_to(x - 120 + k * 8, H); c.set_source_rgba(0, 0, 0, 0.5); c.set_line_width(2); c.stroke()
    for i, x in enumerate(SLOTS):                              # estrados de piedra con runas
        big = i == 1; rx = 180 if big else 158
        cone = cairo.LinearGradient(0, 0, 0, GY + 110)
        cone.add_color_stop_rgba(0, 0.7, 0.45, 1, 0); cone.add_color_stop_rgba(1, 0.7, 0.45, 1, 0.13 if big else 0.08)
        c.move_to(x - 30, -10); c.line_to(x + 30, -10); c.line_to(x + 200, GY + 112); c.line_to(x - 200, GY + 112); c.close_path(); c.set_source(cone); c.fill()
        ellipse(c, x, GY + 120, rx, 44); fill_stroke(c, hexc('#2A2434'), DARK, 7)
        ellipse(c, x, GY + 104, rx, 40); fill_stroke(c, hexc('#3A3046'), DARK, 7)
        ellipse(c, x, GY + 104, rx - 26, 28); c.set_source_rgba(*wa(hexc('#B06BFF'), 0.55)); c.set_line_width(2.5); c.stroke()
        for k in range(10):
            a = k * 2 * math.pi / 10
            gx, gy = x + math.cos(a) * (rx - 14), GY + 104 + math.sin(a) * 34
            c.move_to(gx, gy - 6); c.line_to(gx, gy + 6); c.move_to(gx, gy - 6); c.line_to(gx + 5, gy - 1)
        c.set_source_rgba(*wa(hexc('#B06BFF'), 0.8)); c.set_line_width(2); c.stroke()
    skulls(c, 140, GY + 160, 5, rng); skulls(c, W - 150, GY + 170, 4, rng)
    for (x, y) in ((70, 990), (W - 70, 985), (W / 2 - 520, 1050), (W / 2 + 520, 1050)):
        gl = cairo.RadialGradient(x, y - 10, 2, x, y - 10, 100); gl.add_color_stop_rgba(0, 1, 0.75, 0.4, 0.35); gl.add_color_stop_rgba(1, 1, 0.5, 0.2, 0)
        c.set_source(gl); c.arc(x, y - 10, 100, 0, 2 * math.pi); c.fill()
        for (dx, h) in ((-9, 26), (5, 34), (15, 18)):
            rrect(c, x + dx - 4.5, y + 12 - h, 9, h, 2.5); fill_stroke(c, hexc('#E8DCC4'), DARK, 3)
            ellipse(c, x + dx, y + 12 - h - 8, 3.6, 6.5); c.set_source_rgba(1, 0.85, 0.45, 0.95); c.fill()
    cobweb(c, 0, 0, 330, 0, a=0.5); cobweb(c, W, 0, 330, math.pi / 2, a=0.5)
    cobweb(c, 0, H, 220, -math.pi / 2, a=0.35); cobweb(c, W, H, 220, math.pi, a=0.35)
    cobweb(c, 380, 40, 120, 0.2, span=math.pi * 0.7, a=0.3)
    c.move_to(260, 0); c.curve_to(262, 60, 258, 120, 260, 170); c.set_source_rgba(*WEB, 0.5); c.set_line_width(1.2); c.stroke()   # araña colgando
    c.arc(260, 182, 11, 0, 2 * math.pi); c.set_source_rgba(*DARK); c.fill()
    for k in range(4):
        for sgn in (-1, 1):
            c.move_to(260 + sgn * 6, 178 + k * 3); c.curve_to(260 + sgn * 20, 168 + k * 6, 260 + sgn * 24, 186 + k * 6, 260 + sgn * 28, 196 + k * 4)
    c.set_line_width(2.4); c.stroke()
    c.arc(256, 179, 2, 0, 2 * math.pi); c.arc(264, 179, 2, 0, 2 * math.pi); c.set_source_rgba(1, 0.2, 0.2, 0.9); c.fill()
    fog_layer(c, 2.0, a=1.0); vignette(c, 0.62)
    s.write_to_png(path)


# ---------------------------------------------------------------- cartas de arena (estilo carta de fantasía, diseño propio)
CARD_W, CARD_H = 640, 960
PREMISAS = {
    'cienaga': "Aquí se hundió el tesoro de un rey avaro. El barro todavía tiene hambre… y las raíces, memoria.",
    'cripta': "Los muertos guardan sus doblones con celo. Pisa donde no brillan los pinchos y no despiertes al guardián.",
    'taller': "Un gnomo dejó todas sus máquinas encendidas y se fue de vacaciones. Lo que no explota, sale por la cinta.",
    'biblioteca': "Libros que muerden, portales que te escupen y un rayo que nunca duerme. Silencio, por favor.",
}
TRAPS_OF = {'cienaga': [0, 1], 'cripta': [2, 3], 'taller': [4, 5, 6], 'biblioteca': [7, 8]}


def card(aid, path, with_text=False):
    A = AR.ARENAS[aid]; acc = hexc(A['accent'])
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, CARD_W, CARD_H); c = cairo.Context(s)
    rrect(c, 6, 6, CARD_W - 12, CARD_H - 12, 34)
    g = cairo.LinearGradient(0, 0, CARD_W, CARD_H); g.add_color_stop_rgba(0, *hexc('#3A2A20')); g.add_color_stop_rgba(0.5, *hexc('#1E1410')); g.add_color_stop_rgba(1, *hexc('#3A2A20'))
    c.set_source(g); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(8); c.stroke()
    rrect(c, 22, 22, CARD_W - 44, CARD_H - 44, 24)
    g = cairo.LinearGradient(0, 22, 0, CARD_H - 22); g.add_color_stop_rgba(0, *hexc('#FFE7A0')); g.add_color_stop_rgba(0.5, *hexc('#C9971C')); g.add_color_stop_rgba(1, *hexc('#6B4210'))
    c.set_source(g); c.set_line_width(7); c.stroke()
    for (x, y) in ((22, 22), (CARD_W - 22, 22), (22, CARD_H - 22), (CARD_W - 22, CARD_H - 22)):
        star_path(c, x, y, 16, n=4, inner=0.35, rot=0); fill_stroke(c, GOLD, DARK, 3)
    rrect(c, 46, 120, CARD_W - 92, 430, 16); c.set_source_rgba(*DARK); c.fill()        # ilustración
    mini = cairo.ImageSurface.create_from_png(f'out/godot_carga/assets/ui/arena_{aid}_mini.png')
    c.save(); rrect(c, 52, 126, CARD_W - 104, 418, 12); c.clip()
    sc = 418 / 540 * 1.25; c.translate(52 + (CARD_W - 104) / 2, 126 + 209); c.scale(sc, sc); c.translate(-480, -270)
    c.set_source_surface(mini, 0, 0); c.paint(); c.restore()
    c.save(); rrect(c, 52, 126, CARD_W - 104, 418, 12); c.clip()
    gv = cairo.RadialGradient(CARD_W / 2, 335, 120, CARD_W / 2, 335, 330); gv.add_color_stop_rgba(0, 0, 0, 0, 0); gv.add_color_stop_rgba(1, 0, 0, 0, 0.7)
    c.set_source(gv); c.paint(); c.restore()
    rrect(c, 52, 126, CARD_W - 104, 418, 12); c.set_source_rgba(*acc); c.set_line_width(4); c.stroke()
    rrect(c, 46, 40, CARD_W - 92, 66, 14); fill_stroke(c, hexc('#241838'), GOLD_DK, 4)           # placa del nombre
    c.arc(CARD_W - 78, 73, 18, 0, 2 * math.pi); fill_stroke(c, acc, DARK, 4)                     # gema del color de la arena
    c.arc(CARD_W - 83, 67, 5, 0, 2 * math.pi); c.set_source_rgba(1, 1, 1, 0.7); c.fill()
    rrect(c, 46, 572, CARD_W - 92, 250, 14)                                                    # caja de texto (pergamino)
    g = cairo.LinearGradient(0, 572, 0, 822); g.add_color_stop_rgba(0, *hexc('#E8DCC4')); g.add_color_stop_rgba(1, *hexc('#BFAE8A'))
    c.set_source(g); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(4); c.stroke()
    icons = cairo.ImageSurface.create_from_png('out/godot_carga/assets/ui/trampas_iconos.png')
    tr = TRAPS_OF[aid]; x0 = CARD_W / 2 - (len(tr) * 96 - 16) / 2
    for k, ti in enumerate(tr):
        c.save(); c.translate(x0 + k * 96, 838); c.scale(80 / 128, 80 / 128); c.rectangle(0, 0, 128, 128); c.clip()
        c.set_source_surface(icons, -ti * 128, 0); c.paint(); c.restore()
    if with_text:
        draw_text(c, A['name'].upper(), 60, 74, 34, fam=FG, grad=bone_grad, ow=4, oc=DARK, align='l')
        words = PREMISAS[aid].split(); lines, cur = [], ""
        c.select_font_face(FB, cairo.FONT_SLANT_ITALIC); c.set_font_size(30)
        for wd in words:
            if c.text_extents(cur + " " + wd).x_advance > CARD_W - 140 and cur:
                lines.append(cur); cur = wd
            else:
                cur = (cur + " " + wd).strip()
        lines.append(cur)
        for k, ln in enumerate(lines):
            draw_text(c, ln, CARD_W / 2, 618 + k * 40, 29, fam=FB, bold=True, fill=hexc('#3A2A20'))
    s.write_to_png(path)


def card_glow(path):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, CARD_W + 120, CARD_H + 120); c = cairo.Context(s)
    for k in range(18, 0, -1):
        rrect(c, 60 - k * 3, 60 - k * 3, CARD_W + k * 6, CARD_H + k * 6, 34 + k * 3); c.set_source_rgba(1, 0.82, 0.25, 0.035); c.set_line_width(6); c.stroke()
    rrect(c, 56, 56, CARD_W + 8, CARD_H + 8, 36); c.set_source_rgba(1, 0.95, 0.6, 1); c.set_line_width(6); c.stroke()
    for k in range(12):
        a = k * math.pi / 6
        star_path(c, 60 + CARD_W / 2 + math.cos(a) * (CARD_W / 2 + 30), 60 + CARD_H / 2 + math.sin(a) * (CARD_H / 2 + 30), 10 + (k % 3) * 4, n=4, inner=0.3, rot=0)
        c.set_source_rgba(1, 1, 0.85, 0.9); c.fill()
    s.write_to_png(path)


# ---------------------------------------------------------------- emotes nuevos (más risas)
EMOTES2 = ['dado', 'jarra', 'rana', 'zzz', 'pregunta', 'jaja', 'pollo', 'grito']


def bubble(c):
    c.new_path(); rrect(c, 8, 6, 112, 92, 30); c.move_to(50, 96); c.line_to(64, 120); c.line_to(76, 96); c.close_path()
    c.set_source_rgba(*DARK); c.set_line_width(9); c.stroke_preserve(); c.set_source_rgba(*BONE); c.fill()
    rrect(c, 16, 14, 96, 76, 24); c.set_dash([7, 5]); c.set_line_width(2.2); c.set_source_rgba(*wa(hexc('#A8977A'), 0.9)); c.stroke(); c.set_dash([])


def emote2(c, k):
    bubble(c); c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_line_join(cairo.LINE_JOIN_ROUND)
    if k == 'dado':                                            # dado de 20 caras con un 20
        pts = [(64 + math.cos(a) * 32, 52 + math.sin(a) * 32) for a in [math.pi / 2 + i * math.pi / 3 for i in range(6)]]
        c.move_to(*pts[0]); [c.line_to(*p) for p in pts[1:]]; c.close_path(); fill_stroke(c, hexc('#B06BFF'), DARK, 4)
        for p in pts[::2]:
            c.move_to(64, 52); c.line_to(*p)
        c.set_source_rgba(*wa(DARK, 0.5)); c.set_line_width(2); c.stroke()
        draw_text(c, "20", 64, 54, 26, fill=GOLD, ow=3, oc=DARK)
    elif k == 'jarra':                                          # jarra de hidromiel
        rrect(c, 42, 30, 38, 52, 6); fill_stroke(c, hexc('#C9971C'), DARK, 4)
        c.arc(84, 54, 11, -math.pi / 2, math.pi / 2); c.set_source_rgba(*DARK); c.set_line_width(5); c.stroke()
        for x in (46, 58, 70):
            c.arc(x, 28, 9, 0, 2 * math.pi); fill_stroke(c, WHITE, DARK, 3)
        for y in (44, 60):
            c.move_to(42, y); c.line_to(80, y)
        c.set_source_rgba(*hexc('#6B4210')); c.set_line_width(3); c.stroke()
    elif k == 'rana':
        ellipse(c, 64, 58, 34, 24); fill_stroke(c, hexc('#63A83A'), DARK, 4)
        for ex in (48, 80):
            c.arc(ex, 36, 10, 0, 2 * math.pi); fill_stroke(c, hexc('#63A83A'), DARK, 4)
            c.arc(ex, 36, 4.5, 0, 2 * math.pi); c.set_source_rgba(*DARK); c.fill()
        c.move_to(46, 62); c.curve_to(56, 72, 72, 72, 82, 62); c.set_source_rgba(*DARK); c.set_line_width(3.5); c.stroke()
        c.move_to(64, 69); c.curve_to(62, 82, 70, 88, 76, 80); c.set_source_rgba(*hexc('#D8484F')); c.set_line_width(5); c.stroke()
    elif k == 'zzz':
        for (x, y, s_) in ((44, 66, 34), (66, 46, 28), (86, 30, 22)):
            draw_text(c, "Z", x, y, s_, fill=hexc('#3C7FD0'), ow=3, oc=DARK)
    elif k == 'pregunta':
        draw_text(c, "¿?", 64, 52, 58, fam=FG, fill=hexc('#FF9F1C'), ow=5, oc=DARK)
    elif k == 'jaja':
        draw_text(c, "JA", 52, 40, 30, fill=hexc('#D8484F'), ow=3, oc=DARK, rot=-0.15)
        draw_text(c, "JA", 78, 66, 34, fill=hexc('#FF4FD8'), ow=3, oc=DARK, rot=0.12)
    elif k == 'pollo':                                          # pollito asustado ("¡gallina!")
        c.arc(64, 54, 26, 0, 2 * math.pi); fill_stroke(c, hexc('#FFD23F'), DARK, 4)
        c.move_to(84, 52); c.line_to(100, 56); c.line_to(84, 62); c.close_path(); fill_stroke(c, hexc('#FF9F1C'), DARK, 3)
        c.arc(72, 46, 5, 0, 2 * math.pi); c.set_source_rgba(*WHITE); c.fill(); c.arc(73, 46, 2.5, 0, 2 * math.pi); c.set_source_rgba(*DARK); c.fill()
        for k2 in range(3):
            c.move_to(56 + k2 * 6, 28); c.line_to(52 + k2 * 8, 18)
        c.set_source_rgba(*DARK); c.set_line_width(3); c.stroke()
        c.arc(40, 34, 4, 0, 2 * math.pi); c.set_source_rgba(*FROST); c.fill()
    elif k == 'grito':                                          # grito de guerra: hacha y "¡ARGH!"
        c.save(); c.translate(64, 54); c.rotate(-0.5)
        c.move_to(0, -30); c.line_to(0, 34); c.set_source_rgba(*hexc('#6B4210')); c.set_line_width(7); c.stroke()
        c.move_to(0, -26); c.curve_to(26, -34, 30, -6, 0, -4); c.close_path(); fill_stroke(c, hexc('#C9CCD8'), DARK, 3)
        c.restore()
        draw_text(c, "¡ARGH!", 64, 80, 22, fill=hexc('#D8484F'), ow=3, oc=DARK)


def emotes2(path):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 128 * len(EMOTES2), 128); c = cairo.Context(s)
    for i, k in enumerate(EMOTES2):
        c.save(); c.translate(i * 128, 0); emote2(c, k); c.restore()
    s.write_to_png(path)


# ---------------------------------------------------------------- referencias
def reference_lobby(path):
    dungeon_background(path)
    s = cairo.ImageSurface.create_from_png(path); c = cairo.Context(s)
    names = ['Joel', 'Miquel', 'Bot Costura', None]; ready = [True, False, True, None]
    for i, x in enumerate(SLOTS):
        if names[i] is None:
            ellipse(c, x, GY - 60, 70, 110); c.set_source_rgba(1, 1, 1, 0.05); c.fill()
            draw_text(c, "+", x, GY - 70, 120, fill=wa(DIM, 0.5))
            draw_text(c, "INVITAR", x, GY + 185, 34, fam=FG, grad=bone_grad, ow=4, oc=DARK)
            continue
        pid = [1, 0, 2][i]
        d = Doll(pid); d.r = 118 if i == 1 else 100; d.x, d.y = x, GY; d.look = (0.0, 0.3); d.marker = False; d.blink_off = 1.0 + i
        d.face = 1 if x < W / 2 else -1
        if i == 2:
            d.tilt = 0.28; d.squash = 0.12; d.y -= 30                         # bailando
        draw_hero(c, d, 0.5, 0.5, crown=(i == 0))
        rrect(c, x - 150, GY + 158, 300, 58, 22); fill_stroke(c, wa(PANEL, 0.95), PL[pid]['col'], 5)
        draw_text(c, names[i], x - 128, GY + 187, 28, fam=FB, bold=True, fill=WHITE, align='l')
        rrect(c, x + 40, GY + 170, 96, 34, 14); c.set_source_rgba(*(hexc('#3E8E3A') if ready[i] else hexc('#4A3170'))); c.fill()
        draw_text(c, "LISTO" if ready[i] else "...", x + 88, GY + 188, 22, fill=WHITE)
    for k in range(3):                                         # notas de baile
        draw_text(c, "♪", SLOTS[2] - 110 + k * 90, GY - 300 - (k % 2) * 30, 44, fill=GOLD, ow=3, oc=DARK)
    draw_text(c, "¡A LA CARGA, CAMARADA!", SLOTS[0], GY - 360, 40, fam=FG, grad=oldgold_grad, ow=5, oc=DARK, shadow=(0, 6, hexc('#5C1018')), rot=-0.05)
    e2 = cairo.ImageSurface.create_from_png(os.path.join(UI, 'emotes2.png'))
    c.save(); c.translate(SLOTS[1] + 60, GY - 400); c.rectangle(0, 0, 128, 128); c.clip(); c.set_source_surface(e2, -5 * 128, 0); c.paint(); c.restore()
    rrect(c, 40, 34, 470, 120, 26); fill_stroke(c, wa(PANEL, 0.95), PANEL_LN, 6)
    draw_text(c, "CÓDIGO DE SALA", 70, 66, 24, fam=FB, bold=True, fill=DIM, align='l')
    draw_text(c, "VUDU7", 70, 118, 64, fill=GOLD, ow=5, oc=DARK, align='l')
    rrect(c, 360, 92, 128, 46, 14); fill_stroke(c, hexc('#3A2758'), GOLD, 3); draw_text(c, "COPIAR", 424, 116, 24, fam=FB, bold=True, fill=WHITE)
    rrect(c, W - 520, 34, 480, 120, 26); fill_stroke(c, wa(PANEL, 0.95), PANEL_LN, 6)
    draw_text(c, "MODO", W - 490, 66, 24, fam=FB, bold=True, fill=DIM, align='l')
    draw_text(c, "‹ VOODOOCOMBO ›", W - 490, 112, 40, fam=FG, grad=oldgold_grad, ow=4, oc=DARK, align='l')
    for k, (lab, w_) in enumerate((("TAQUILLA", 280), ("¡LISTO!", 400), ("BAILES", 240), ("SALIR", 200))):
        x = [260, W / 2, W - 520, W - 200][k]; y = 1000
        rrect(c, x - w_ / 2, y - 40, w_, 80, 24); fill_stroke(c, GOLD if k == 1 else hexc('#2C1E44'), DARK if k == 1 else PANEL_LN, 6)
        draw_text(c, lab, x, y + 2, 44 if k == 1 else 32, fam=FG, fill=DARK if k == 1 else None, grad=None if k == 1 else bone_grad, ow=0 if k == 1 else 4, oc=DARK)
    s.write_to_png(path)


def reference_vote(path):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(s)
    c.set_source_rgba(*hexc('#08050C')); c.paint()
    stone_wall(c, -20, H, random.Random(3))
    c.set_source_rgba(0, 0, 0, 0.55); c.paint()
    draw_text(c, "¡VOTAD LA ARENA!", W / 2, 90, 84, fam=FG, grad=bone_grad, ow=8, oc=DARK, shadow=(0, 10, hexc('#5C1018')))
    draw_text(c, "0:07", W / 2, 162, 44, fill=GOLD, ow=4, oc=DARK)
    sc = 0.5; xs = [W / 2 - 3 * 300, W / 2 - 300, W / 2 + 300, W / 2 + 3 * 300]
    xs = [W / 2 + (k - 1.5) * 360 for k in range(4)]
    votes = {0: [0], 1: [], 2: [1, 3], 3: [2]}
    glow = cairo.ImageSurface.create_from_png(os.path.join(UI, 'carta_brillo.png'))
    for k, aid in enumerate(AR.ORDER):
        im = cairo.ImageSurface.create_from_png(os.path.join(REF, f'carta_{aid}_con_texto.png'))
        cx, cy = xs[k], 590 - (30 if k == 2 else 0)
        s_ = sc * (1.12 if k == 2 else 1.0)
        if k == 2:
            c.save(); c.translate(cx, cy); c.scale(s_, s_); c.translate(-(CARD_W + 120) / 2, -(CARD_H + 120) / 2); c.set_source_surface(glow, 0, 0); c.paint(); c.restore()
        c.save(); c.translate(cx, cy); c.scale(s_, s_); c.translate(-CARD_W / 2, -CARD_H / 2); c.set_source_surface(im, 0, 0)
        c.paint_with_alpha(1.0 if k == 2 else 0.6); c.restore()
        por = votes[k]
        for j, pid in enumerate(por):
            rx = cx - (len(por) - 1) * 30 + j * 60; ry = cy + 290
            ret = cairo.ImageSurface.create_from_png(f'out/godot_ui/assets/ui/retrato_{["mago","trol","gnomo","nigro"][pid]}_{["coral","azul","lima","hueso"][pid]}.png')
            c.save(); c.translate(rx - 28, ry - 28); c.scale(0.5, 0.5); c.set_source_surface(ret, 0, 0); c.paint(); c.restore()
    draw_text(c, "Si hay empate, ruleta entre las empatadas: la carta que se ilumina, gana", W / 2, 1040, 30, fam=FB, bold=True, fill=DIM)
    s.write_to_png(path)


def main():
    dungeon_background(os.path.join(UI, 'lobby_mazmorra.png'))
    for aid in AR.ORDER:
        card(aid, os.path.join(UI, f'carta_{aid}.png'))
        card(aid, os.path.join(REF, f'carta_{aid}_con_texto.png'), with_text=True)
    card_glow(os.path.join(UI, 'carta_brillo.png'))
    emotes2(os.path.join(UI, 'emotes2.png'))
    meta = {"lobby_mazmorra": {"file": "lobby_mazmorra.png", "size": [1920, 1080], "pedestals_x": list(SLOTS), "pedestal_y": GY},
            "cartas": {"file": "carta_<arena>.png", "size": [CARD_W, CARD_H],
                       "zones": {"name": [46, 40, 548, 66], "art": [52, 126, 536, 418], "premise": [46, 572, 548, 250], "traps": [0, 838, 640, 80]},
                       "premisas": PREMISAS,
                       "note": "Carta sin texto: el nombre va en la placa de arriba (New Rocker) y la premisa en el pergamino (Baloo 2, cursiva o negrita, #3A2A20)."},
            "carta_brillo": {"file": "carta_brillo.png", "size": [CARD_W + 120, CARD_H + 120], "note": "Encima de la carta (centrado) cuando gana o cuando pasa la ruleta por ella."},
            "emotes2": {"file": "emotes2.png", "frame_w": 128, "frame_h": 128, "frames": len(EMOTES2), "order": EMOTES2}}
    with open(os.path.join(UI, 'fase11b.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    reference_lobby(os.path.join(REF, 'lobby_mazmorra_referencia.png'))
    reference_vote(os.path.join(REF, 'votacion_referencia.png'))
    print('ok', OUT)


if __name__ == '__main__':
    main()
