#!/usr/bin/env python3
"""Arte de las fases 11 y 12: fondo del lobby, cofres de equipo (Codicia 2v2) y costuras (Último en Pie).
Uso: python3 export_fase11.py [carpeta_salida]   (por defecto out/godot_f11; copiar su assets/ a la raíz del proyecto)"""
import cairo, json, math, os, random, sys
from gfx import *
from heroes import draw_hero
from world import Doll, fog_layer

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_f11'
UI = os.path.join(OUT, 'assets', 'ui'); IT = os.path.join(OUT, 'assets', 'items'); REF = os.path.join(OUT, 'referencias')
for d in (UI, IT, REF):
    os.makedirs(d, exist_ok=True)
DARK = hexc('#0B0710'); BONE = hexc('#E8DCC4')
SLOTS = (420, 780, 1140, 1500); GY = 760


def lobby_background(path):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(s)
    g = cairo.RadialGradient(W / 2, 520, 60, W / 2, 520, 1250)
    g.add_color_stop_rgba(0, *hexc('#3A1238')); g.add_color_stop_rgba(0.5, *hexc('#1A0C26')); g.add_color_stop_rgba(1, *DARK)
    c.set_source(g); c.paint()
    for side in (-1, 1):                                       # telón
        for k in range(8):
            x0 = (0 if side < 0 else W) + side * (k * 30 - 10)
            c.move_to(x0, 0); c.curve_to(x0 + side * 34, 380, x0 - side * 22, 700, x0 + side * 16, H)
            c.set_source_rgba(*wa(hexc('#5C1018'), 0.55 - k * 0.055)); c.set_line_width(30); c.stroke()
    rng = random.Random(12)
    for _ in range(22):
        draw_coin(c, rng.uniform(150, W - 150), rng.uniform(40, 560), rng.uniform(0, 6), rng.uniform(0, 6), r=rng.uniform(9, 18), alpha=rng.uniform(0.07, 0.16))
    c.rectangle(0, GY + 40, W, H); lg = cairo.LinearGradient(0, GY + 40, 0, H)
    lg.add_color_stop_rgba(0, *hexc('#1A1028')); lg.add_color_stop_rgba(1, *hexc('#07040A')); c.set_source(lg); c.fill()
    c.move_to(0, GY + 40); c.line_to(W, GY + 40); c.set_source_rgba(*wa(hexc('#4A3170'), 0.8)); c.set_line_width(3); c.stroke()
    for i, x in enumerate(SLOTS):
        big = i == 1
        cone = cairo.LinearGradient(0, 0, 0, GY + 110)
        cone.add_color_stop_rgba(0, 1, 0.92, 0.75, 0); cone.add_color_stop_rgba(1, 1, 0.92, 0.75, 0.16 if big else 0.1)
        c.move_to(x - 36, -10); c.line_to(x + 36, -10); c.line_to(x + 190, GY + 112); c.line_to(x - 190, GY + 112); c.close_path(); c.set_source(cone); c.fill()
        rx = 170 if big else 150
        ellipse(c, x, GY + 104, rx, 38); fill_stroke(c, hexc('#2A1E3C'), DARK, 7)
        ellipse(c, x, GY + 98, rx - 18, 29); c.set_dash([12, 9]); c.set_line_width(3); c.set_source_rgba(*STITCH); c.stroke(); c.set_dash([])
    fog_layer(c, 2.0, a=0.9); vignette(c, 0.5)
    s.write_to_png(path)


def team_chest(path, col):
    """Cofre de equipo: 2 frames (normal y al guardar doblones). Frame 160×160 en el mundo, exportado al doble."""
    S = 2; fw = 160
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, fw * 2 * S, fw * S)
    for f in range(2):
        c = cairo.Context(s); c.scale(S, S); c.rectangle(f * fw, 0, fw, fw); c.clip(); c.translate(f * fw + fw / 2, fw / 2 + 10)
        g = cairo.RadialGradient(0, 0, 8, 0, 0, 74); g.add_color_stop_rgba(0, *wa(col, 0.55 if f else 0.3)); g.add_color_stop_rgba(1, *wa(col, 0))
        c.set_source(g); c.arc(0, 0, 74, 0, 2 * math.pi); c.fill()
        ellipse(c, 0, 22, 56, 18); c.set_source_rgba(*wa(col, 0.35)); c.fill_preserve(); c.set_source_rgba(*col); c.set_dash([8, 6]); c.set_line_width(3); c.stroke(); c.set_dash([])
        c.move_to(-34, -46); c.line_to(-34, 6); c.set_source_rgba(*DARK); c.set_line_width(5); c.stroke()      # estandarte
        c.move_to(-34, -46); c.line_to(-4, -40); c.line_to(-34, -26); c.close_path(); fill_stroke(c, col, DARK, 3)
        rrect(c, -26, -4, 52, 30, 6); fill_stroke(c, hexc('#8E5A33'), DARK, 5)
        rrect(c, -28, -18, 56, 18, 8); fill_stroke(c, hexc('#A8703F'), DARK, 5)
        for bx in (-14, 14):
            c.rectangle(bx - 3, -17, 6, 42); c.set_source_rgba(*col); c.fill()
        rrect(c, -6, 0, 12, 10, 2); fill_stroke(c, GOLD, DARK, 3)
        for k in range(5 if f else 3):
            draw_coin(c, -18 + k * 9, -22 - (k % 2) * 4, 0, k, r=6)
    s.write_to_png(path)


def stitches(path):
    """Costura (vida) entera y rota, 2 frames de 64×64."""
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 128, 64); c = cairo.Context(s)
    for f in range(2):
        c.save(); c.translate(f * 64 + 32, 32)
        c.arc(0, 0, 26, 0, 2 * math.pi); fill_stroke(c, hexc('#241838'), DARK, 4)
        c.set_line_cap(cairo.LINE_CAP_ROUND)
        if f == 0:
            for (a, b, x, y) in ((-12, -12, 12, 12), (12, -12, -12, 12)):
                c.move_to(a, b); c.line_to(x, y)
            c.set_source_rgba(*DARK); c.set_line_width(9); c.stroke_preserve(); c.set_source_rgba(*hexc('#D8484F')); c.set_line_width(5); c.stroke()
        else:
            for (a, b, x, y) in ((-12, -12, -3, -3), (3, 3, 12, 12), (12, -12, 5, -5), (-5, 5, -12, 12)):
                c.move_to(a, b); c.line_to(x, y)
            c.set_source_rgba(*wa(hexc('#6E6680'), 0.9)); c.set_line_width(4); c.stroke()
        c.restore()
    s.write_to_png(path)


def reference_lobby(path):
    lobby_background(path)
    s = cairo.ImageSurface.create_from_png(path); c = cairo.Context(s)
    names = ['Joel', 'Miquel', 'Bot Costura', None]; ready = [True, False, True, None]
    for i, x in enumerate(SLOTS):
        if names[i] is None:
            c.save(); c.translate(x, GY); c.scale(1, 1)
            ellipse(c, 0, -60, 70, 110); c.set_source_rgba(1, 1, 1, 0.06); c.fill(); c.restore()
            draw_text(c, "+", x, GY - 70, 120, fill=wa(DIM, 0.6))
            draw_text(c, "INVITAR", x, GY + 175, 34, fam=FG, grad=bone_grad, ow=4, oc=DARK)
            draw_text(c, "Código: VUDU7", x, GY + 215, 24, fam=FB, bold=True, fill=DIM)
            continue
        pid = [1, 0, 2][i]
        d = Doll(pid); d.r = 118 if i == 1 else 100; d.x, d.y = x, GY; d.look = (0.0, 0.3); d.marker = False; d.blink_off = 1.0 + i
        d.face = 1 if x < W / 2 else -1
        draw_hero(c, d, 0.5, 0.5, crown=(i == 0))
        rrect(c, x - 150, GY + 148, 300, 58, 22); fill_stroke(c, wa(PANEL, 0.95), PL[pid]['col'], 5)
        draw_text(c, names[i], x - 128, GY + 177, 28, fam=FB, bold=True, fill=WHITE, align='l')
        ok = ready[i]
        rrect(c, x + 40, GY + 160, 96, 34, 14); c.set_source_rgba(*(hexc('#3E8E3A') if ok else hexc('#4A3170'))); c.fill()
        draw_text(c, "LISTO" if ok else "...", x + 88, GY + 178, 22, fill=WHITE)
        if i == 0:
            draw_text(c, "ANFITRIÓN", x, GY - 330, 22, fam=FB, bold=True, fill=GOLD)
    em = cairo.ImageSurface.create_from_png('out/godot_f10/assets/ui/emotes.png')
    c.save(); c.translate(SLOTS[2] + 30, GY - 360); c.rectangle(0, 0, 128, 128); c.clip(); c.set_source_surface(em, -4 * 128, 0); c.paint(); c.restore()
    rrect(c, 40, 34, 470, 120, 26); fill_stroke(c, wa(PANEL, 0.95), PANEL_LN, 6)                       # código de sala
    draw_text(c, "CÓDIGO DE SALA", 70, 66, 24, fam=FB, bold=True, fill=DIM, align='l')
    draw_text(c, "VUDU7", 70, 118, 64, fill=GOLD, ow=5, oc=DARK, align='l')
    rrect(c, 360, 92, 128, 46, 14); fill_stroke(c, hexc('#3A2758'), GOLD, 3); draw_text(c, "COPIAR", 424, 116, 24, fam=FB, bold=True, fill=WHITE)
    rrect(c, W - 610, 34, 570, 120, 26); fill_stroke(c, wa(PANEL, 0.95), PANEL_LN, 6)                   # modo y arena
    draw_text(c, "MODO", W - 580, 66, 24, fam=FB, bold=True, fill=DIM, align='l')
    draw_text(c, "‹ VOODOOCOMBO ›", W - 580, 112, 40, fam=FG, grad=oldgold_grad, ow=4, oc=DARK, align='l')
    draw_text(c, "ARENA: ALEATORIA ›", W - 70, 66, 24, fam=FB, bold=True, fill=DIM, align='r')
    for k, (lab, w_) in enumerate((("TAQUILLA", 300), ("¡LISTO!", 420), ("SALIR", 240))):
        x = [300, W / 2, W - 260][k]; y = 1000
        rrect(c, x - w_ / 2, y - 40, w_, 80, 24)
        fill_stroke(c, GOLD if k == 1 else hexc('#2C1E44'), DARK if k == 1 else PANEL_LN, 6)
        draw_text(c, lab, x, y + 2, 44 if k == 1 else 34, fam=FG, fill=DARK if k == 1 else None, grad=None if k == 1 else bone_grad, ow=0 if k == 1 else 4, oc=DARK)
    draw_text(c, "1-4 emotes", W / 2, 1062, 20, fam=FB, bold=True, fill=wa(DIM, 0.8))
    s.write_to_png(path)


def main():
    lobby_background(os.path.join(UI, 'lobby_fondo.png'))
    team_chest(os.path.join(IT, 'cofre_equipo_coral.png'), PL[0]['col'])
    team_chest(os.path.join(IT, 'cofre_equipo_azul.png'), PL[1]['col'])
    stitches(os.path.join(UI, 'costuras.png'))
    meta = {"lobby_fondo": {"file": "ui/lobby_fondo.png", "size": [1920, 1080],
                            "pedestals_x": list(SLOTS), "pedestal_y": GY, "note": "Peanas en x = 420, 780, 1140, 1500 (en 1920×1080). Tu personaje va en la segunda, más grande."},
            "cofre_equipo": {"file": "items/cofre_equipo_<coral|azul>.png", "frame_w": 320, "frame_h": 320, "frames": 2, "scale": 0.5,
                             "note": "Frame 0 normal, frame 1 al guardar doblones. El centro de la base está 10 px por debajo del centro del frame."},
            "costuras": {"file": "ui/costuras.png", "frame_w": 64, "frame_h": 64, "frames": 2, "note": "Vida de Último en Pie: 0 entera, 1 rota. Dibujar a 24-32 px."}}
    with open(os.path.join(OUT, 'fase11.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    reference_lobby(os.path.join(REF, 'lobby_referencia.png'))
    print('ok', OUT)


if __name__ == '__main__':
    main()
