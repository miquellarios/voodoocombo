#!/usr/bin/env python3
"""Arte de la fase 10: ranura del hechizo nueva, emotes, marcos de retrato, podio, fondo de resultados y niebla de la zona.
Uso: python3 export_fase10.py [carpeta_salida]   (por defecto out/godot_f10; copiar su assets/ a la raíz del proyecto)"""
import cairo, json, math, os, random, sys
from gfx import *
from heroes import draw_hero, KINDS, PCOL3
from world import Doll, fog_layer

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_f10'
UI = os.path.join(OUT, 'assets', 'ui'); REF = os.path.join(OUT, 'referencias')
for d in (UI, REF):
    os.makedirs(d, exist_ok=True)
BONE = hexc('#E8DCC4'); BLOOD = hexc('#5C1018'); DARK = hexc('#0B0710')


def canvas(w, h):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h); return s, cairo.Context(s)


# ================================================================ ranura del hechizo
def spell_slot():
    s, c = canvas(192, 192); cx = cy = 96
    g = cairo.RadialGradient(cx, cy, 30, cx, cy, 92); g.add_color_stop_rgba(0, 0, 0, 0, 0.5); g.add_color_stop_rgba(1, 0, 0, 0, 0)
    c.set_source(g); c.arc(cx, cy, 92, 0, 2 * math.pi); c.fill()
    c.arc(cx, cy, 80, 0, 2 * math.pi)                          # aro de metal viejo
    g = cairo.LinearGradient(0, 16, 0, 176); g.add_color_stop_rgba(0, *hexc('#FFE7A0')); g.add_color_stop_rgba(0.5, *hexc('#C9971C')); g.add_color_stop_rgba(1, *hexc('#6B4210'))
    c.set_source(g); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(6); c.stroke()
    for k in range(8):                                         # remaches
        a = k * math.pi / 4 + math.pi / 8
        c.arc(cx + math.cos(a) * 72, cy + math.sin(a) * 72, 4, 0, 2 * math.pi); fill_stroke(c, hexc('#FFF2C4'), DARK, 2)
    c.arc(cx, cy, 63, 0, 2 * math.pi)                          # hueco oscuro
    g = cairo.RadialGradient(cx, cy - 14, 6, cx, cy, 64); g.add_color_stop_rgba(0, *hexc('#3A2758')); g.add_color_stop_rgba(1, *hexc('#120A1C'))
    c.set_source(g); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(5); c.stroke()
    c.arc(cx, cy, 54, 0, 2 * math.pi); c.set_dash([8, 6]); c.set_line_width(2.5); c.set_source_rgba(*STITCH); c.stroke(); c.set_dash([])
    s.write_to_png(os.path.join(UI, 'hechizo_ranura.png'))

    s, c = canvas(192, 192)                                    # brillo cuando hay hechizo listo
    for k in range(10):
        c.arc(96, 96, 82 + k * 1.2, 0, 2 * math.pi); c.set_source_rgba(1, 0.82, 0.25, 0.09 - k * 0.008); c.set_line_width(4); c.stroke()
    c.arc(96, 96, 81, 0, 2 * math.pi); c.set_source_rgba(1, 0.92, 0.55, 0.9); c.set_line_width(3); c.stroke()
    s.write_to_png(os.path.join(UI, 'hechizo_brillo.png'))

    for name, label, round_ in (('tecla_e', 'E', False), ('tecla_b', 'B', True)):
        s, c = canvas(72, 72)
        if round_:
            c.arc(36, 38, 28, 0, 2 * math.pi); fill_stroke(c, hexc('#B8322A'), DARK, 5)
            c.arc(36, 33, 24, math.pi * 1.1, math.pi * 1.9); c.set_source_rgba(1, 1, 1, 0.35); c.set_line_width(3); c.stroke()
        else:
            rrect(c, 8, 12, 56, 54, 12); c.set_source_rgba(*hexc('#8A7E6A')); c.fill()          # lateral de la tecla
            rrect(c, 8, 6, 56, 52, 12); fill_stroke(c, BONE, DARK, 5)
        draw_text(c, label, 36, 33 if not round_ else 39, 34, fill=WHITE if round_ else DARK)
        s.write_to_png(os.path.join(UI, name + '.png'))


# ================================================================ emotes
EMOTES = ['risa', 'enfado', 'llanto', 'corazon', 'gg', 'calavera', 'pulgar', 'fuego']


def bubble(c):
    c.new_path(); rrect(c, 8, 6, 112, 92, 30)
    c.move_to(50, 96); c.line_to(64, 120); c.line_to(76, 96); c.close_path()
    c.set_source_rgba(*DARK); c.set_line_width(9); c.stroke_preserve(); c.set_source_rgba(*BONE); c.fill()
    rrect(c, 16, 14, 96, 76, 24); c.set_dash([7, 5]); c.set_line_width(2.2); c.set_source_rgba(*wa(hexc('#A8977A'), 0.9)); c.stroke(); c.set_dash([])


def face(c, col):
    c.arc(64, 52, 30, 0, 2 * math.pi); fill_stroke(c, col, DARK, 5)


def emote(c, kind):
    bubble(c)
    c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_line_join(cairo.LINE_JOIN_ROUND)
    if kind == 'risa':
        face(c, hexc('#FFD23F'))
        for ex in (52, 76):
            c.move_to(ex - 7, 48); c.curve_to(ex - 4, 40, ex + 4, 40, ex + 7, 48)
        c.set_source_rgba(*DARK); c.set_line_width(4); c.stroke()
        c.move_to(48, 58); c.curve_to(52, 76, 76, 76, 80, 58); c.close_path(); fill_stroke(c, hexc('#5C1018'), DARK, 3)
        for (x, y) in ((30, 34), (98, 34)):
            c.arc(x, y, 5, 0, 2 * math.pi); c.set_source_rgba(*FROST); c.fill()
    elif kind == 'enfado':
        face(c, hexc('#D8484F'))
        c.move_to(44, 40); c.line_to(58, 47); c.move_to(84, 40); c.line_to(70, 47); c.set_source_rgba(*DARK); c.set_line_width(5); c.stroke()
        for ex in (53, 75):
            c.arc(ex, 52, 4, 0, 2 * math.pi); c.set_source_rgba(*DARK); c.fill()
        c.move_to(50, 68); c.line_to(78, 68); c.set_line_width(4); c.stroke()
        for x in range(53, 78, 6):
            c.move_to(x, 64); c.line_to(x + 2, 72)
        c.set_line_width(2.2); c.stroke()
        for k in range(3):
            c.move_to(92 + k * 5, 18 + k * 2); c.line_to(100 + k * 5, 26 + k * 2)
        c.set_source_rgba(*hexc('#D8484F')); c.set_line_width(4); c.stroke()
    elif kind == 'llanto':
        face(c, hexc('#3C7FD0'))
        for ex in (53, 75):
            c.move_to(ex - 6, 50); c.curve_to(ex - 3, 56, ex + 3, 56, ex + 6, 50)
        c.set_source_rgba(*DARK); c.set_line_width(4); c.stroke()
        c.move_to(52, 72); c.curve_to(58, 63, 70, 63, 76, 72); c.stroke()
        for ex in (47, 81):
            c.move_to(ex, 56); c.curve_to(ex - 6, 66, ex - 4, 74, ex, 74); c.curve_to(ex + 4, 74, ex + 6, 66, ex, 56)
            fill_stroke(c, FROST, DARK, 2.5)
    elif kind == 'corazon':
        c.move_to(64, 82); c.curve_to(26, 58, 34, 22, 64, 38); c.curve_to(94, 22, 102, 58, 64, 82); c.close_path()
        fill_stroke(c, hexc('#D8484F'), DARK, 5)
        c.move_to(64, 40); c.line_to(64, 78); c.set_dash([5, 4]); c.set_source_rgba(*BONE); c.set_line_width(2.5); c.stroke(); c.set_dash([])
        c.arc(50, 44, 5, 0, 2 * math.pi); c.set_source_rgba(1, 1, 1, 0.6); c.fill()
    elif kind == 'gg':
        draw_text(c, "GG", 64, 54, 56, fam=FG, grad=oldgold_grad, ow=6, oc=DARK)
    elif kind == 'calavera':
        c.arc(64, 46, 26, math.pi * 0.85, math.pi * 2.15); c.line_to(80, 72); c.line_to(48, 72); c.close_path()
        fill_stroke(c, BONE, DARK, 5)
        for ex in (54, 74):
            c.arc(ex, 50, 7, 0, 2 * math.pi); c.set_source_rgba(*DARK); c.fill()
        c.move_to(64, 58); c.line_to(60, 65); c.line_to(68, 65); c.close_path(); c.fill()
        for x in (56, 64, 72):
            c.move_to(x, 68); c.line_to(x, 75)
        c.set_line_width(3); c.stroke()
    elif kind == 'pulgar':
        rrect(c, 40, 46, 40, 34, 9); fill_stroke(c, hexc('#E8C9A0'), DARK, 4.5)
        rrect(c, 54, 18, 16, 36, 8); fill_stroke(c, hexc('#E8C9A0'), DARK, 4.5)
        for y in (56, 65, 73):
            c.move_to(42, y); c.line_to(56, y)
        c.set_source_rgba(*DARK); c.set_line_width(2.5); c.stroke()
        rrect(c, 80, 46, 14, 34, 4); fill_stroke(c, hexc('#5A3D7A'), DARK, 4)
    elif kind == 'fuego':
        c.move_to(64, 86); c.curve_to(30, 80, 34, 48, 52, 30); c.curve_to(54, 44, 60, 46, 62, 40)
        c.curve_to(66, 26, 72, 20, 74, 14); c.curve_to(96, 36, 100, 78, 64, 86); c.close_path()
        g = cairo.LinearGradient(0, 14, 0, 86); g.add_color_stop_rgba(0, *hexc('#FFD23F')); g.add_color_stop_rgba(1, *hexc('#D8484F'))
        c.set_source(g); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(5); c.stroke()
        c.move_to(64, 82); c.curve_to(50, 78, 52, 62, 62, 54); c.curve_to(64, 64, 72, 62, 70, 54); c.curve_to(80, 66, 76, 80, 64, 82)
        c.set_source_rgba(*hexc('#FFF6C2')); c.fill()


def emotes():
    s, c = canvas(128 * len(EMOTES), 128)
    for i, k in enumerate(EMOTES):
        c.save(); c.translate(i * 128, 0); emote(c, k); c.restore()
    s.write_to_png(os.path.join(UI, 'emotes.png'))
    return {"file": "emotes.png", "frame_w": 128, "frame_h": 128, "frames": len(EMOTES), "order": EMOTES,
            "note": "Bocadillo con el pico abajo en el centro (64, 120): colocar ese punto encima de la cabeza. Dibujar a 64×64."}


# ================================================================ marcos de retrato (cosméticos)
FRAMES = [('madera', '#8E5A33', '#5A3418'), ('hueso', '#E8DCC4', '#8A7E6A'), ('plata', '#E4E8F2', '#7A8094'),
          ('oro', '#FFE7A0', '#8A5A12'), ('almas', '#D9B8FF', '#5A2E8A')]


def frames():
    for name, a, b in FRAMES:
        s, c = canvas(128, 128)
        if name == 'almas':
            for k in range(14):
                ang = k * 2 * math.pi / 14
                c.move_to(64 + math.cos(ang) * 54, 64 + math.sin(ang) * 54)
                c.line_to(64 + math.cos(ang + 0.12) * 66, 64 + math.sin(ang + 0.12) * 66); c.line_to(64 + math.cos(ang + 0.24) * 54, 64 + math.sin(ang + 0.24) * 54)
            c.close_path(); c.set_source_rgba(*wa(hexc('#B06BFF'), 0.85)); c.fill()
        c.arc(64, 64, 58, 0, 2 * math.pi); c.arc_negative(64, 64, 50, 2 * math.pi, 0)
        g = cairo.LinearGradient(0, 6, 0, 122); g.add_color_stop_rgba(0, *hexc(a)); g.add_color_stop_rgba(1, *hexc(b))
        c.set_source(g); c.fill()
        c.arc(64, 64, 58, 0, 2 * math.pi); c.set_source_rgba(*DARK); c.set_line_width(4); c.stroke()
        c.arc(64, 64, 50, 0, 2 * math.pi); c.stroke()
        if name == 'madera':
            for k in range(6):
                ang = k * math.pi / 3 + 0.3; c.arc(64 + math.cos(ang) * 54, 64 + math.sin(ang) * 54, 2, 0, 2 * math.pi); c.set_source_rgba(*hexc('#3A2312')); c.fill()
        elif name == 'hueso':
            for ang in (math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75):
                x, y = 64 + math.cos(ang) * 56, 64 + math.sin(ang) * 56
                for dd in (-5, 5):
                    c.arc(x + dd * math.cos(ang + 1.57), y + dd * math.sin(ang + 1.57), 5, 0, 2 * math.pi)
                    fill_stroke(c, hexc(a), DARK, 2)
        elif name in ('plata', 'oro'):
            for k in range(4):
                ang = k * math.pi / 2 - math.pi / 2
                star_path(c, 64 + math.cos(ang) * 54, 64 + math.sin(ang) * 54, 9, n=4, inner=0.4, rot=0); fill_stroke(c, hexc(a), DARK, 2.5)
            if name == 'oro':
                draw_crown(c, 64, 8, 34)
        s.write_to_png(os.path.join(UI, f'marco_{name}.png'))
    return {"file": "marco_<id>.png", "ids": [f[0] for f in FRAMES], "size": [128, 128],
            "note": "Va encima del retrato (retrato 112 px centrado). En el marcador: retrato a 44 px y marco a 50 px."}


# ================================================================ podio y fondo de resultados
def results_background(path, with_heroes=False):
    s, c = canvas(W, H)
    g = cairo.RadialGradient(W / 2, 560, 80, W / 2, 560, 1150)
    g.add_color_stop_rgba(0, *hexc('#4A1022')); g.add_color_stop_rgba(1, *DARK); c.set_source(g); c.paint()
    for side in (-1, 1):                                       # telón
        for k in range(7):
            x0 = (0 if side < 0 else W) + side * (k * 34 - 10)
            c.move_to(x0, 0); c.curve_to(x0 + side * 30, 400, x0 - side * 20, 700, x0 + side * 14, H)
            c.set_source_rgba(*wa(hexc('#5C1018'), 0.55 - k * 0.06)); c.set_line_width(30); c.stroke()
    for bx in (960, 630, 1290):
        sg = cairo.LinearGradient(bx, 0, bx, 900); sg.add_color_stop_rgba(0, 1, 1, 1, 0); sg.add_color_stop_rgba(1, 1, 1, 1, 0.06 if bx == 960 else 0.035)
        c.move_to(bx - 60, 0); c.line_to(bx + 60, 0); c.line_to(bx + 220, 980); c.line_to(bx - 220, 980); c.close_path(); c.set_source(sg); c.fill()
    c.rectangle(0, 980, W, 100); c.set_source_rgba(*hexc('#120A1C')); c.fill()
    rng = random.Random(4)
    for _ in range(26):
        draw_coin(c, rng.uniform(0, W), rng.uniform(30, 700), rng.uniform(0, 6), rng.uniform(0, 6), r=rng.uniform(10, 20), alpha=rng.uniform(0.08, 0.18))
    fog_layer(c, 1.5, a=0.9); vignette(c, 0.5)
    s.write_to_png(path)


PODIUM = [(960, 300, 300, GOLD, '1'), (630, 300, 210, hexc('#D9D4E8'), '2'), (1290, 300, 150, hexc('#E39A5B'), '3')]


def podium_blocks(c, ox=0.0, oy=0.0):
    for (bx, bw, bh, col, n) in PODIUM:
        x, top = bx - bw / 2 + ox, 980 - bh + oy
        rrect(c, x, top, bw, bh + 30, 18); fill_stroke(c, hexc('#2C1B45'), DARK, 8)
        rrect(c, x + 10, top + 10, bw - 20, bh + 10, 12); c.set_dash([12, 9]); c.set_line_width(3); c.set_source_rgba(*STITCH); c.stroke(); c.set_dash([])
        draw_text(c, n + "º", bx + ox, top + 58, 88, fill=col, ow=7, oc=DARK)


def podium():
    s, c = canvas(1080, 400)
    podium_blocks(c, ox=-420, oy=-620)
    s.write_to_png(os.path.join(UI, 'podio.png'))
    return {"file": "podio.png", "size": [1080, 400],
            "tops": {"1": [540, 60], "2": [210, 150], "3": [870, 210]},
            "note": "Tres bloques; 'tops' es el centro de la parte de arriba de cada bloque en la imagen (donde se pone el personaje). "
                    "En 1280×720 se dibuja a escala 2/3 (720×267) con la base en y = 680."}


# ================================================================ niebla de la zona (se repite sin costuras)
def zone_fog():
    N = 256; s, c = canvas(N, N)
    c.set_source_rgba(*wa(hexc('#2A1440'), 0.78)); c.paint()
    rng = random.Random(9)
    for _ in range(60):
        x, y, r = rng.uniform(0, N), rng.uniform(0, N), rng.uniform(18, 60)
        col = hexc('#6B3FA0') if rng.random() < 0.5 else hexc('#1E3A2A')
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                g = cairo.RadialGradient(x + dx, y + dy, 0, x + dx, y + dy, r)
                g.add_color_stop_rgba(0, *wa(col, 0.35)); g.add_color_stop_rgba(1, *wa(col, 0))
                c.set_source(g); c.arc(x + dx, y + dy, r, 0, 2 * math.pi); c.fill()
    for _ in range(40):
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        for dx in (-N, 0, N):
            for dy in (-N, 0, N):
                c.arc(x + dx, y + dy, rng.uniform(1, 2.2), 0, 2 * math.pi); c.set_source_rgba(0.85, 0.7, 1, 0.35); c.fill()
    s.write_to_png(os.path.join(UI, 'zona_niebla.png'))
    return {"file": "zona_niebla.png", "size": [256, 256],
            "note": "Se repite sin costuras (texture_repeat). Rellena lo que queda fuera de la zona segura y se desplaza despacio (≈12 px/s)."}


# ================================================================ referencias
def reference_results(path):
    results_background(path)
    s = cairo.ImageSurface.create_from_png(path); c = cairo.Context(s)
    podium_blocks(c)
    order = [0, 2, 1, 3]; scores = [128, 96, 71, 40]; names = ['Miquel', 'Mordisquitos', 'Costura', 'Pantano']
    pos = [(960, 680 - 100 * 0.98), (630, 770 - 100 * 0.98), (1290, 830 - 100 * 0.98), (1560, 900)]
    for rank, pid in enumerate(order):
        d = Doll(pid); d.r = 100 if rank < 3 else 70; d.x, d.y = pos[rank]; d.look = (0.0, 0.35); d.marker = False; d.blink_off = 2.0
        if rank == 0:
            d.y -= 26; d.squash = -0.08
        if rank == 3:
            d.tilt = 0.25
        draw_hero(c, d, 0.4, 0.4, crown=(rank == 0))
        ny = 972 if rank < 3 else 990
        nx = pos[rank][0]
        rrect(c, nx - 125, ny - 26, 250, 52, 20); fill_stroke(c, wa(PANEL, 0.95), PL[pid]['col'], 4)
        draw_text(c, names[rank], nx - 105, ny + 1, 24, fam=FB, bold=True, fill=WHITE, align='l')
        draw_coin(c, nx + 62, ny, 0, 0, r=11); draw_text(c, str(scores[rank]), nx + 80, ny + 2, 26, fill=GOLD, align='l')
    draw_text(c, "¡GANA MIQUEL!", W / 2, 110, 110, fam=FG, fill=shade(PL[0]['col'], 0.15), ow=10, oc=DARK, shadow=(0, 12, DARK))
    em = cairo.ImageSurface.create_from_png(os.path.join(UI, 'emotes.png'))
    for (pid_rank, k) in ((0, 4), (1, 1), (3, 2)):
        x, y = pos[pid_rank]; top = y - (330 if pid_rank == 0 else 250 if pid_rank < 3 else 190)
        c.save(); c.translate(x + 40, top - 70); c.rectangle(0, 0, 128, 128); c.clip(); c.set_source_surface(em, -k * 128, 0); c.paint(); c.restore()
    draw_text(c, "EMOTES", 80, 1048, 24, fam=FB, bold=True, fill=DIM, align='l')
    for k in range(4):
        x = 230 + k * 120; y = 1055
        c.save(); c.translate(x - 26, y - 40); c.scale(0.42, 0.42); c.rectangle(0, 0, 128, 128); c.clip()
        c.set_source_surface(em, -[0, 4, 3, 6][k] * 128, 0); c.paint(); c.restore()
        draw_text(c, str(k + 1), x + 38, y - 10, 24, fill=DIM, ow=3, oc=DARK)
    draw_text(c, "MENÚ PRINCIPAL", 1690, 1040, 30, fam=FG, grad=oldgold_grad, ow=4, oc=DARK)
    s.write_to_png(path)


def reference_hud(path):
    import world as WD
    w = WD.World(); w.set_arena('cienaga'); w.st = 5.0; w.t = 5.0; w.crown_on = True
    rng = random.Random(5)
    for _ in range(26):
        x, y = rng.uniform(260, 940), rng.uniform(130, 470)
        if WD.free_spot(x, y, 22):
            w.coins.append(WD.Coin(x, y, -9.0, rng=rng))
    for d, (x, y), sc in zip(w.d, ((470, 400), (760, 230), (640, 470), (330, 190)), (42, 17, 31, 9)):
        d.visible = True; d.place(x, y); d.r = 27.0; d.score = sc; d.spawn_t = -9.0
    w.leader = 0
    w.text(560, 420, "+6", col=PINK, size=40, life=9); w.texts[-1]['born'] = 4.85
    for d, nm in zip(w.d, ("MIQUEL", "MORDISQUITOS", "COSTURA", "PANTANO")):
        d.name = nm
    s, c = canvas(W, H)
    cam = WD.Cam(600, 300, 1.42)
    WD.render_world(c, w, cam, 5.0, 0)
    fog = cairo.ImageSurface.create_from_png(os.path.join(UI, 'zona_niebla.png'))
    zx0, zy0 = cam.to_screen(200, 80); zx1, zy1 = cam.to_screen(1000, 520)
    c.save(); c.rectangle(0, 0, W, H); c.rectangle(zx0, zy0, zx1 - zx0, zy1 - zy0); c.set_fill_rule(cairo.FILL_RULE_EVEN_ODD); c.clip()
    pat = cairo.SurfacePattern(fog); pat.set_extend(cairo.EXTEND_REPEAT); m = cairo.Matrix(); m.scale(0.7, 0.7); pat.set_matrix(m)
    c.set_source(pat); c.paint(); c.restore()
    rrect(c, zx0, zy0, zx1 - zx0, zy1 - zy0, 10); c.set_dash([18, 12]); c.set_line_width(6); c.set_source_rgba(*hexc('#B06BFF')); c.stroke(); c.set_dash([])
    draw_text(c, "¡LA NIEBLA SE CIERRA!", W / 2, 205, 54, fam=FG, grad=bone_grad, ow=6, oc=DARK, shadow=(0, 6, hexc('#5A2E8A')))
    for d, nm in zip(w.d, ("Miquel", "Mordisquitos", "Costura", "Pantano")):    # nombres sobre la cabeza
        sx, sy = cam.to_screen(d.x, d.y - d.r * 2.9)
        me = d.pid == 0
        draw_text(c, nm, sx, sy - (34 if me else 0), 34 if me else 26, fam=FB, bold=True, fill=d.col if me else WHITE, ow=5, oc=DARK)
        if me:
            draw_text(c, "TÚ", sx, sy + 4, 26, fill=WHITE, ow=4, oc=DARK)
            c.move_to(sx - 12, sy + 22); c.line_to(sx + 12, sy + 22); c.line_to(sx, sy + 36); c.close_path(); fill_stroke(c, d.col, DARK, 3)
            fx, fy = cam.to_screen(d.x, d.y + d.r * 1.05)
            ellipse(c, fx, fy, 52, 16); c.set_source_rgba(*wa(d.col, 0.9)); c.set_line_width(5); c.stroke()
    WD.draw_hud(c, w, 5.0, 38)
    slot = cairo.ImageSurface.create_from_png(os.path.join(UI, 'hechizo_ranura.png'))   # ranura nueva sobre la antigua
    c.save(); c.rectangle(0, 860, 260, 220); c.set_source_rgba(*DARK); c.restore()
    sx, sy = 118, 958
    c.save(); c.arc(sx, sy, 90, 0, 2 * math.pi); c.clip()
    g = cairo.RadialGradient(sx, sy, 10, sx, sy, 90); g.add_color_stop_rgba(0, 0.1, 0.06, 0.15, 1); g.add_color_stop_rgba(1, 0.1, 0.06, 0.15, 0.0); c.set_source(g); c.paint(); c.restore()
    glow = cairo.ImageSurface.create_from_png(os.path.join(UI, 'hechizo_brillo.png'))
    c.set_source_surface(glow, sx - 96, sy - 96); c.paint()
    c.set_source_surface(slot, sx - 96, sy - 96); c.paint()
    draw_icon(c, 'frost', sx, sy, 36)
    c.arc(sx, sy, 87, -math.pi / 2, -math.pi / 2 + 2 * math.pi * 0.62); c.set_source_rgba(*FROST); c.set_line_width(7); c.set_line_cap(cairo.LINE_CAP_ROUND); c.stroke()
    key = cairo.ImageSurface.create_from_png(os.path.join(UI, 'tecla_e.png')); c.set_source_surface(key, sx + 44, sy + 30); c.paint()
    draw_text(c, "NOVA DE ESCARCHA", sx + 120, sy - 14, 30, fam=FG, grad=bone_grad, ow=4, oc=DARK, align='l')
    draw_text(c, "Pulsa E para lanzarla", sx + 120, sy + 22, 24, fam=FB, bold=True, fill=DIM, align='l')
    s.write_to_png(path)


def main():
    spell_slot()
    meta = {"hechizo_ranura": {"file": "hechizo_ranura.png", "size": [192, 192], "note": "Ranura del hechizo. Dibujar a 96×96. Hueco interior de radio 63 (en la imagen) para el icono."},
            "hechizo_brillo": {"file": "hechizo_brillo.png", "size": [192, 192], "note": "Encima de la ranura cuando hay hechizo listo, latiendo (modulate.a 0,5-1)."},
            "tecla_e": {"file": "tecla_e.png", "size": [72, 72]}, "tecla_b": {"file": "tecla_b.png", "size": [72, 72], "note": "Si se juega con mando."},
            "emotes": emotes(), "marcos": frames(), "podio": podium(), "zona_niebla": zone_fog()}
    results_background(os.path.join(UI, 'resultados_fondo.png'))
    meta['resultados_fondo'] = {"file": "resultados_fondo.png", "size": [1920, 1080], "note": "Fondo limpio de la pantalla de resultados (telón y focos)."}
    with open(os.path.join(UI, 'fase10.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    reference_results(os.path.join(REF, 'resultados_referencia.png'))
    reference_hud(os.path.join(REF, 'hud_v2_referencia.png'))
    print('ok', OUT)


if __name__ == '__main__':
    main()
