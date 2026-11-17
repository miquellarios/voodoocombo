#!/usr/bin/env python3
"""Votación en 4 esquinas (referencia + marco del cuadrante) y medallas de la fase 12 (dopamina).
Uso: python3 export_fase12.py [carpeta_salida]"""
import cairo, json, math, os, random, sys
from gfx import *
import arenas as AR

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_f12'
UI = os.path.join(OUT, 'assets', 'ui'); REF = os.path.join(OUT, 'referencias')
for d in (UI, REF):
    os.makedirs(d, exist_ok=True)
DARK = hexc('#0B0710')
QW, QH, GAP = 930, 510, 20
QUADS = [(GAP, GAP), (W - GAP - QW, GAP), (W - GAP - QW, H - GAP - QH), (GAP, H - GAP - QH)]   # sentido horario
PREMISAS = {
    'cienaga': "Aquí se hundió el tesoro de un rey avaro. El barro todavía tiene hambre.",
    'cripta': "Los muertos guardan sus doblones. No despiertes al guardián.",
    'taller': "Un gnomo dejó sus máquinas encendidas. Lo que no explota, sale por la cinta.",
    'biblioteca': "Libros que muerden y un rayo que nunca duerme. Silencio, por favor.",
}


def quad_frame(path, lit=False):
    """Marco del cuadrante (9-slice, margen 40). lit = encendido por la ruleta o ganador."""
    w, h = 240, 160; s = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h); c = cairo.Context(s)
    if lit:
        for k in range(10, 0, -1):
            rrect(c, 12 - k, 12 - k, w - 24 + 2 * k, h - 24 + 2 * k, 26 + k); c.set_source_rgba(1, 0.82, 0.25, 0.06); c.set_line_width(4); c.stroke()
    rrect(c, 12, 12, w - 24, h - 24, 24)
    g = cairo.LinearGradient(0, 12, 0, h - 12)
    if lit:
        g.add_color_stop_rgba(0, *hexc('#FFF2C4')); g.add_color_stop_rgba(0.5, *hexc('#FFD23F')); g.add_color_stop_rgba(1, *hexc('#C9971C'))
    else:
        g.add_color_stop_rgba(0, *hexc('#8A7A5A')); g.add_color_stop_rgba(0.5, *hexc('#5A4A32')); g.add_color_stop_rgba(1, *hexc('#3A2A20'))
    c.set_source(g); c.set_line_width(12); c.stroke()
    rrect(c, 22, 22, w - 44, h - 44, 18); c.set_source_rgba(*DARK); c.set_line_width(3); c.stroke()
    for (x, y) in ((18, 18), (w - 18, 18), (18, h - 18), (w - 18, h - 18)):
        star_path(c, x, y, 14 if lit else 11, n=4, inner=0.35, rot=0); fill_stroke(c, GOLD if lit else hexc('#A8977A'), DARK, 2.5)
    s.write_to_png(path)


def reference_vote(path, lit=2):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(s)
    c.set_source_rgba(*hexc('#08050C')); c.paint()
    icons = cairo.ImageSurface.create_from_png('out/godot_carga/assets/ui/trampas_iconos.png')
    traps = {'cienaga': [0, 1], 'cripta': [2, 3], 'taller': [4, 5, 6], 'biblioteca': [7, 8]}
    votes = {0: [0], 1: [], 2: [1, 3], 3: [2]}
    for k, aid in enumerate(AR.ORDER):
        x, y = QUADS[k]; on = k == lit
        mini = cairo.ImageSurface.create_from_png(f'out/godot_carga/assets/ui/arena_{aid}_mini.png')
        c.save(); rrect(c, x, y, QW, QH, 24); c.clip()
        c.translate(x, y); c.scale(QW / 960, QH / 540); c.set_source_surface(mini, 0, 0); c.paint()
        c.restore()
        c.save(); rrect(c, x, y, QW, QH, 24); c.clip()
        g = cairo.LinearGradient(0, y + QH * 0.45, 0, y + QH); g.add_color_stop_rgba(0, 0, 0, 0, 0); g.add_color_stop_rgba(1, 0, 0, 0, 0.92)
        c.set_source(g); c.paint()
        if not on:
            c.set_source_rgba(0.03, 0.01, 0.05, 0.45); c.paint()
        c.restore()
        fr = cairo.ImageSurface.create_from_png(os.path.join(UI, 'cuadrante_brillo.png' if on else 'cuadrante_marco.png'))
        from export_ui import draw_nine
        draw_nine(c, fr, x - 12, y - 12, QW + 24, QH + 24, 40)
        A = AR.ARENAS[aid]
        right = k in (1, 2)
        tx = x + QW - 40 if right else x + 40; al = 'r' if right else 'l'
        draw_text(c, A['name'].upper(), tx, y + QH - 130, 54 if on else 46, fam=FG, grad=oldgold_grad if on else bone_grad, ow=6, oc=DARK, align=al,
                  shadow=(0, 6, hexc('#5C1018')))
        c.select_font_face(FB, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD); c.set_font_size(26)
        words = PREMISAS[aid].split(); lines, cur = [], ""
        for wd in words:
            if c.text_extents(cur + " " + wd).x_advance > 640 and cur:
                lines.append(cur); cur = wd
            else:
                cur = (cur + " " + wd).strip()
        lines.append(cur)
        for j, ln in enumerate(lines):
            draw_text(c, ln, tx, y + QH - 78 + j * 34, 26, fam=FB, bold=True, fill=hexc('#E8DCC4'), align=al)
        n = len(traps[aid])
        for j, ti in enumerate(traps[aid]):
            ix = (x + 30 + j * 70) if right else (x + QW - 30 - (n - j) * 70)
            c.save(); c.translate(ix, y + 28); c.scale(64 / 128, 64 / 128); c.rectangle(0, 0, 128, 128); c.clip()
            c.set_source_surface(icons, -ti * 128, 0); c.paint(); c.restore()
        for j, pid in enumerate(votes[k]):
            px_ = (x + QW - 100 - j * 74) if right else (x + 30 + j * 74)
            ret = cairo.ImageSurface.create_from_png(f'out/godot_ui/assets/ui/retrato_{["mago","trol","gnomo","nigro"][pid]}_{["coral","azul","lima","hueso"][pid]}.png')
            c.save(); c.translate(px_, y + 26); c.scale(0.62, 0.62); c.set_source_surface(ret, 0, 0); c.paint(); c.restore()
    cx, cy = W / 2, H / 2                                       # medallón central
    for k in range(4):                                          # flechas de la ruleta (sentido horario)
        a = -math.pi * 3 / 4 + k * math.pi / 2
        c.save(); c.translate(cx + math.cos(a) * 150, cy + math.sin(a) * 150); c.rotate(a + math.pi / 2)
        c.move_to(-14, 8); c.line_to(0, -12); c.line_to(14, 8); c.close_path(); fill_stroke(c, GOLD if k == lit else hexc('#5A4A32'), DARK, 3); c.restore()
    c.arc(cx, cy, 128, 0, 2 * math.pi); fill_stroke(c, hexc('#160E22'), DARK, 8)
    c.arc(cx, cy, 120, 0, 2 * math.pi); g = cairo.LinearGradient(0, cy - 120, 0, cy + 120)
    g.add_color_stop_rgba(0, *hexc('#FFE7A0')); g.add_color_stop_rgba(1, *hexc('#8A5A12')); c.set_source(g); c.set_line_width(10); c.stroke()
    c.arc(cx, cy, 100, 0, 2 * math.pi); c.set_dash([10, 8]); c.set_source_rgba(*STITCH); c.set_line_width(3); c.stroke(); c.set_dash([])
    draw_text(c, "¡VOTAD!", cx, cy - 38, 40, fam=FG, grad=bone_grad, ow=4, oc=DARK)
    draw_text(c, "7", cx, cy + 28, 96, fill=GOLD, ow=6, oc=DARK)
    s.write_to_png(path)


# ---------------------------------------------------------------- medallas en partida
MEDALS = [('primera_sangre', '#D8484F', 'drop'), ('venganza', '#B06BFF', 'swords'), ('remontada', '#63A83A', 'arrow'),
          ('robo_maestro', '#FFD23F', 'bag'), ('racha', '#FF9F1C', 'flame'), ('por_los_pelos', '#7FE7FF', 'feather'),
          ('intocable', '#E8DCC4', 'shield'), ('rey_combo', '#FF4FD8', 'crown')]


def medal(c, col, kind):
    c.save(); c.translate(64, 64)
    for k in range(12):                                         # rayos
        a = k * math.pi / 6
        c.move_to(math.cos(a) * 40, math.sin(a) * 40); c.line_to(math.cos(a + 0.13) * 58, math.sin(a + 0.13) * 58); c.line_to(math.cos(a + 0.26) * 40, math.sin(a + 0.26) * 40)
    c.close_path(); c.set_source_rgba(*wa(hexc(col), 0.85)); c.fill()
    c.arc(0, 0, 44, 0, 2 * math.pi); g = cairo.LinearGradient(0, -44, 0, 44); g.add_color_stop_rgba(0, *hexc('#FFE7A0')); g.add_color_stop_rgba(1, *hexc('#8A5A12'))
    c.set_source(g); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(5); c.stroke()
    c.arc(0, 0, 34, 0, 2 * math.pi); c.set_source_rgba(*shade(hexc(col), -0.35)); c.fill_preserve(); c.set_source_rgba(*DARK); c.set_line_width(3); c.stroke()
    c.set_line_cap(cairo.LINE_CAP_ROUND); c.set_line_join(cairo.LINE_JOIN_ROUND)
    W_ = (1, 1, 1, 0.95)
    if kind == 'drop':
        c.move_to(0, -20); c.curve_to(14, 0, 14, 16, 0, 18); c.curve_to(-14, 16, -14, 0, 0, -20); fill_stroke(c, hexc('#FF5A5F'), DARK, 3)
    elif kind == 'swords':
        for s_ in (-1, 1):
            c.move_to(-16 * s_, 16); c.line_to(16 * s_, -16)
        c.set_source_rgba(*DARK); c.set_line_width(8); c.stroke_preserve() if False else None
        for s_ in (-1, 1):
            c.move_to(-16 * s_, 16); c.line_to(16 * s_, -16)
        c.set_source_rgba(*W_); c.set_line_width(5); c.stroke()
    elif kind == 'arrow':
        c.move_to(-14, 14); c.line_to(10, -10); c.move_to(-4, -12); c.line_to(12, -12); c.line_to(12, 4)
        c.set_source_rgba(*W_); c.set_line_width(6); c.stroke()
    elif kind == 'bag':
        c.arc(0, 6, 15, 0, 2 * math.pi); fill_stroke(c, hexc('#A8703F'), DARK, 3)
        c.move_to(-7, -9); c.line_to(0, -18); c.line_to(7, -9); fill_stroke(c, hexc('#A8703F'), DARK, 3)
        draw_text(c, "$", 0, 7, 20, fill=GOLD, ow=2, oc=DARK)
    elif kind == 'flame':
        c.move_to(0, 20); c.curve_to(-18, 14, -14, -4, -4, -20); c.curve_to(-2, -8, 4, -6, 6, -12); c.curve_to(16, -2, 18, 16, 0, 20); fill_stroke(c, hexc('#FFD23F'), DARK, 3)
    elif kind == 'feather':
        c.move_to(-14, 16); c.curve_to(-10, -6, 6, -18, 16, -18); c.curve_to(14, -4, 2, 10, -14, 16); fill_stroke(c, hexc('#BFF4FF'), DARK, 3)
    elif kind == 'shield':
        c.move_to(0, -20); c.line_to(16, -12); c.curve_to(16, 6, 8, 16, 0, 20); c.curve_to(-8, 16, -16, 6, -16, -12); c.close_path(); fill_stroke(c, hexc('#E8DCC4'), DARK, 3)
    elif kind == 'crown':
        draw_crown(c, 0, 0, 34)
    c.restore()


def medals(path):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 128 * len(MEDALS), 128); c = cairo.Context(s)
    for i, (_, col, kind) in enumerate(MEDALS):
        c.save(); c.translate(i * 128, 0); medal(c, col, kind); c.restore()
    s.write_to_png(path)


def main():
    quad_frame(os.path.join(UI, 'cuadrante_marco.png')); quad_frame(os.path.join(UI, 'cuadrante_brillo.png'), lit=True)
    medals(os.path.join(UI, 'medallas.png'))
    meta = {"cuadrante_marco": {"file": "cuadrante_marco.png", "size": [240, 160], "margin": 40, "note": "Marco 9-slice de cada mapa en la votación."},
            "cuadrante_brillo": {"file": "cuadrante_brillo.png", "size": [240, 160], "margin": 40, "note": "Marco encendido: ruleta y ganador."},
            "votacion": {"quads_1920": [[x, y, QW, QH] for (x, y) in QUADS], "order": AR.ORDER, "note": "Sentido horario: arriba-izq, arriba-der, abajo-der, abajo-izq. En 1280×720 multiplicar por 2/3."},
            "medallas": {"file": "medallas.png", "frame_w": 128, "frame_h": 128, "frames": len(MEDALS), "order": [m[0] for m in MEDALS]}}
    with open(os.path.join(UI, 'fase12.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    reference_vote(os.path.join(REF, 'votacion_esquinas_referencia.png'))
    print('ok', OUT)


if __name__ == '__main__':
    main()
