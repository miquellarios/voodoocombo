"""Muñecos vudú por piezas: cada personaje es una combinación de piezas sueltas (cabeza, ojos, cara, espalda, mano,
ropa) que se pueden mezclar entre personajes. Diseños originales.

Uso: python3 modular.py  ->  out/modular/personajes_nuevos.png y out/modular/mezclas.png"""
import cairo, math, os, random
from gfx import *
from chars import OUT2, THREAD, BONE, TWINE, weave, blob, bez, stitched, fabric_fill, pin, button_eye, x_eye, socket_eye

PCOL = {'coral': hexc('#D8484F'), 'azul': hexc('#3C7FD0'), 'lima': hexc('#63A83A'), 'hueso': hexc('#D9D0BE')}
FROSTC = hexc('#7FE7FF'); SOUL = hexc('#B06BFF'); EMBER = hexc('#FF6A2B')


def P(ctx, pts, close=True):
    ctx.new_path(); ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    if close:
        ctx.close_path()


def of(ctx, path, fill, ow):
    """Contorno grueso oscuro + relleno (color o patrón)."""
    path(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
    path()
    ctx.set_source(fill) if isinstance(fill, cairo.Pattern) else ctx.set_source_rgba(*fill)
    ctx.fill()


def vgrad(y0, y1, c0, c1):
    g = cairo.LinearGradient(0, y0, 0, y1); g.add_color_stop_rgba(0, *c0); g.add_color_stop_rgba(1, *c1); return g


def glow(ctx, x, y, rad, col, a):
    g = cairo.RadialGradient(x, y, 0, x, y, rad)
    g.add_color_stop_rgba(0, *wa(col, a)); g.add_color_stop_rgba(0.45, *wa(col, a * 0.4)); g.add_color_stop_rgba(1, *wa(col, 0))
    ctx.set_source(g); ctx.arc(x, y, rad, 0, 2 * math.pi); ctx.fill()


# =============================================================== ESPALDA (detrás de todo)
def back_none(ctx, r, t): pass


def back_capa_vampiro(ctx, r, t):
    def cape():
        ctx.new_path(); ctx.move_to(-r * 0.55, -r * 0.1)
        ctx.curve_to(-r * 1.0, r * 0.3, -r * 0.95, r * 0.9, -r * 0.8, r * 1.05)
        ctx.line_to(-r * 0.4, r * 0.9); ctx.line_to(0, r * 1.05); ctx.line_to(r * 0.4, r * 0.9); ctx.line_to(r * 0.8, r * 1.05)
        ctx.curve_to(r * 0.95, r * 0.9, r * 1.0, r * 0.3, r * 0.55, -r * 0.1); ctx.close_path()
    of(ctx, cape, vgrad(-r * 0.1, r, hexc('#3A0F1E'), hexc('#1A0710')), r * 0.12)


def back_capucha(ctx, r, t):
    def hood():
        ctx.new_path(); ctx.move_to(0, -r * 1.55)
        ctx.curve_to(r * 0.65, -r * 1.35, r * 1.15, -r * 0.6, r * 1.0, r * 0.3)
        for i in range(9):
            ctx.line_to(r * 1.0 - (i + 1) * r * 0.222, r * 0.3 + (r * 0.1 if i % 2 == 0 else 0))
        ctx.curve_to(-r * 1.15, -r * 0.6, -r * 0.65, -r * 1.35, 0, -r * 1.55); ctx.close_path()
    of(ctx, hood, vgrad(-r * 1.5, r * 0.3, hexc('#3A2F4A'), hexc('#17121F')), r * 0.12)
    ctx.save(); hood(); ctx.clip(); ctx.set_source(weave(r)); ctx.paint_with_alpha(0.6); ctx.restore()


def back_cola(ctx, r, t):
    w = math.sin(t * 3) * r * 0.1
    for (lw, c) in ((r * 0.16, OUT2), (r * 0.08, hexc('#8E1F2B'))):
        ctx.move_to(-r * 0.4, r * 0.75); ctx.curve_to(-r * 1.1, r * 0.9, -r * 1.2, r * 0.2 + w, -r * 0.95, -r * 0.05 + w)
        ctx.set_line_width(lw); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_source_rgba(*c); ctx.stroke()
    P(ctx, [(-r * 0.95, -r * 0.3 + w), (-r * 0.75, -r * 0.0 + w), (-r * 1.12, r * 0.05 + w)])
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.08); ctx.stroke_preserve(); ctx.set_source_rgba(*hexc('#C0392B')); ctx.fill()


def back_orejas_trol(ctx, r, t, col=None):
    col = col or hexc('#3C7FD0')
    for s in (-1, 1):
        def ear(s=s):
            P(ctx, [(s * r * 0.62, -r * 0.7), (s * r * 1.45, -r * 0.98), (s * r * 1.3, -r * 0.82), (s * r * 1.38, -r * 0.7), (s * r * 0.7, -r * 0.3)])
        of(ctx, ear, shade(col, -0.1), r * 0.12)


def back_alas_murcielago(ctx, r, t):
    f = math.sin(t * 6) * 0.15
    for s in (-1, 1):
        def wing(s=s):
            ctx.new_path(); ctx.move_to(s * r * 0.4, r * 0.1)
            ctx.curve_to(s * r * 0.9, -r * (0.7 + f), s * r * 1.4, -r * (0.6 + f), s * r * 1.55, -r * (0.2 + f))
            ctx.curve_to(s * r * 1.35, -r * 0.05, s * r * 1.3, r * 0.1, s * r * 1.15, r * 0.25)
            ctx.curve_to(s * r * 1.0, r * 0.1, s * r * 0.9, r * 0.2, s * r * 0.75, r * 0.4)
            ctx.curve_to(s * r * 0.65, r * 0.25, s * r * 0.55, r * 0.35, s * r * 0.4, r * 0.4); ctx.close_path()
        of(ctx, wing, vgrad(-r * 0.7, r * 0.4, hexc('#4A2F6A'), hexc('#21153A')), r * 0.1)


def collar_vampiro(ctx, r):
    for s in (-1, 1):          # cuello alto, delante del cuerpo y detrás de la cabeza
        def col_(s=s):
            P(ctx, [(s * r * 0.2, r * 0.05), (s * r * 1.05, -r * 0.85), (s * r * 0.95, -r * 0.15), (s * r * 0.55, r * 0.2)])
        of(ctx, col_, vgrad(-r * 0.8, r * 0.2, hexc('#C0392B'), hexc('#5A0F1E')), r * 0.1)


BACK = {'nada': back_none, 'capa': back_capa_vampiro, 'capucha': back_capucha, 'cola': back_cola,
        'orejas_trol': back_orejas_trol, 'alas': back_alas_murcielago}

# =============================================================== MANO (objeto que lleva, a la derecha)
def hand_none(ctx, r, t): pass


def _stick(ctx, r, x0, y0, x1, y1, col=hexc('#6B4A2E')):
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for (lw, c) in ((r * 0.17, OUT2), (r * 0.09, col)):
        ctx.move_to(x0, y0); ctx.line_to(x1, y1); ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()


def hand_baston_fuego(ctx, r, t):
    _stick(ctx, r, r * 0.8, r * 0.95, r * 1.0, -r * 0.62)
    glow(ctx, r * 1.0, -r * 0.8, r * 0.7, hexc('#FF7A2A'), 0.7)
    ctx.arc(r * 1.0, -r * 0.8, r * 0.18, 0, 2 * math.pi); fill_stroke(ctx, hexc('#FFB347'), OUT2, r * 0.12)


def hand_varita_hielo(ctx, r, t):
    _stick(ctx, r, r * 0.75, r * 0.7, r * 1.05, -r * 0.35, hexc('#9FD8E8'))
    glow(ctx, r * 1.08, -r * 0.5, r * 0.55, FROSTC, 0.7)
    star_path(ctx, r * 1.08, -r * 0.5, r * 0.22, n=6, inner=0.4, rot=0); fill_stroke(ctx, hexc('#DFFAFF'), OUT2, r * 0.07)


def hand_saco(ctx, r, t):
    x, y = r * 0.95, r * 0.45
    def sack():
        ctx.new_path(); ctx.move_to(x - r * 0.12, y - r * 0.35)
        ctx.curve_to(x - r * 0.5, y - r * 0.2, x - r * 0.45, y + r * 0.45, x, y + r * 0.45)
        ctx.curve_to(x + r * 0.45, y + r * 0.45, x + r * 0.5, y - r * 0.2, x + r * 0.12, y - r * 0.35); ctx.close_path()
    of(ctx, sack, vgrad(y - r * 0.35, y + r * 0.45, hexc('#B08A5A'), hexc('#6E5032')), r * 0.11)
    ctx.save(); sack(); ctx.clip(); ctx.set_source(weave(r)); ctx.paint_with_alpha(0.5); ctx.restore()
    draw_text(ctx, "$", x, y + r * 0.08, r * 0.38, fam="Oswald", fill=GOLD, ow=r * 0.06, oc=OUT2, bold=True)
    for k in range(3):
        draw_coin(ctx, x - r * 0.15 + k * r * 0.15, y - r * 0.42 - (k % 2) * r * 0.08, 0, k, r=r * 0.1)


def hand_espada(ctx, r, t):
    ctx.save(); ctx.translate(r * 0.95, r * 0.45); ctx.rotate(0.45)
    def blade():
        P(ctx, [(-r * 0.08, -r * 0.15), (-r * 0.07, -r * 1.35), (0, -r * 1.55), (r * 0.07, -r * 1.35), (r * 0.08, -r * 0.15)])
    of(ctx, blade, vgrad(-r * 1.5, 0, hexc('#C9C2B8'), hexc('#7A6E62')), r * 0.08)
    for k in range(3):   # óxido
        ctx.arc(r * 0.02, -r * (0.5 + k * 0.3), r * 0.04, 0, 6.28); ctx.set_source_rgba(*hexc('#A0522D')); ctx.fill()
    rrect(ctx, -r * 0.3, -r * 0.2, r * 0.6, r * 0.12, r * 0.04); fill_stroke(ctx, hexc('#8A6A45'), OUT2, r * 0.07)
    rrect(ctx, -r * 0.06, -r * 0.08, r * 0.12, r * 0.38, r * 0.04); fill_stroke(ctx, hexc('#4A3020'), OUT2, r * 0.07)
    ctx.restore()


def hand_guadana(ctx, r, t):
    _stick(ctx, r, r * 0.7, r * 1.0, r * 0.95, -r * 1.0, hexc('#3A2A20'))
    def blade():
        ctx.new_path(); ctx.move_to(r * 0.95, -r * 1.0)
        ctx.curve_to(r * 0.6, -r * 1.35, r * 0.0, -r * 1.3, -r * 0.25, -r * 0.95)
        ctx.curve_to(r * 0.15, -r * 1.12, r * 0.6, -r * 1.12, r * 0.92, -r * 0.82); ctx.close_path()
    of(ctx, blade, vgrad(-r * 1.3, -r * 0.8, hexc('#E0D8F0'), hexc('#7A70A0')), r * 0.07)


def hand_llave(ctx, r, t):
    ctx.save(); ctx.translate(r * 0.9, r * 0.2); ctx.rotate(0.5)
    rrect(ctx, -r * 0.07, -r * 0.1, r * 0.14, r * 0.75, r * 0.05); fill_stroke(ctx, hexc('#9AA0B5'), OUT2, r * 0.08)
    ctx.arc(0, -r * 0.2, r * 0.2, 0, 6.28); fill_stroke(ctx, hexc('#9AA0B5'), OUT2, r * 0.08)
    ctx.rectangle(-r * 0.06, -r * 0.45, r * 0.12, r * 0.2); ctx.set_source_rgba(0, 0, 0, 0); ctx.set_operator(cairo.OPERATOR_CLEAR); ctx.fill()
    ctx.set_operator(cairo.OPERATOR_OVER); ctx.restore()


def hand_farol(ctx, r, t):
    x, y = r * 0.95, r * 0.35
    ctx.move_to(x, y - r * 0.55); ctx.line_to(x, y - r * 0.32); ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.06); ctx.stroke()
    glow(ctx, x, y, r * 0.6, hexc('#9BFF7A'), 0.6)
    rrect(ctx, x - r * 0.18, y - r * 0.32, r * 0.36, r * 0.5, r * 0.06); fill_stroke(ctx, wa(hexc('#B8FF9A'), 0.85), OUT2, r * 0.08)
    ctx.arc(x, y - r * 0.05, r * 0.08, 0, 6.28); ctx.set_source_rgba(1, 1, 0.85, 1); ctx.fill()


def hand_tridente(ctx, r, t):
    _stick(ctx, r, r * 0.75, r * 1.0, r * 0.95, -r * 0.8, hexc('#3A1A1A'))
    ctx.save(); ctx.translate(r * 0.96, -r * 0.85)
    for dx in (-0.2, 0, 0.2):
        P(ctx, [(dx * r - r * 0.05, 0), (dx * r, -r * (0.42 if dx == 0 else 0.32)), (dx * r + r * 0.05, 0)])
        fill_stroke(ctx, hexc('#C0392B'), OUT2, r * 0.05)
    rrect(ctx, -r * 0.26, -r * 0.02, r * 0.52, r * 0.1, r * 0.04); fill_stroke(ctx, hexc('#C0392B'), OUT2, r * 0.05)
    ctx.restore()


def hand_baston_seta(ctx, r, t):
    _stick(ctx, r, r * 0.8, r * 0.95, r * 0.95, -r * 0.55, hexc('#5A4632'))
    def cap():
        ctx.new_path(); ctx.arc(r * 0.95, -r * 0.55, r * 0.32, math.pi, 2 * math.pi); ctx.close_path()
    of(ctx, cap, vgrad(-r * 0.9, -r * 0.55, hexc('#7AE0C0'), hexc('#2E8A6E')), r * 0.08)
    glow(ctx, r * 0.95, -r * 0.65, r * 0.5, hexc('#7AE0C0'), 0.35)


HAND = {'nada': hand_none, 'baston_fuego': hand_baston_fuego, 'varita_hielo': hand_varita_hielo, 'saco': hand_saco,
        'espada': hand_espada, 'guadana': hand_guadana, 'llave': hand_llave, 'farol': hand_farol,
        'tridente': hand_tridente, 'baston_seta': hand_baston_seta}

# =============================================================== OJOS
EX1, EX2, EY = -0.32, 0.30, -0.55


def eyes_boton(ctx, r, t):
    button_eye(ctx, EX1 * r, EY * r, r * 0.22, r, (0.3, 0)); button_eye(ctx, EX2 * r, EY * r, r * 0.2, r, (0.3, 0), col=hexc('#3A1A10'))


def eyes_alma(ctx, r, t):
    button_eye(ctx, EX1 * r, EY * r, r * 0.22, r, (0.3, 0), cracked=True); socket_eye(ctx, EX2 * r, EY * r, r * 0.16, r, t, SOUL)


def eyes_parche(ctx, r, t):
    button_eye(ctx, EX2 * r, EY * r, r * 0.21, r, (0.3, 0))
    ctx.move_to(-r * 0.78, -r * 0.85); ctx.line_to(r * 0.7, -r * 0.4)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.06); ctx.stroke()
    ellipse(ctx, EX1 * r, EY * r, r * 0.24, r * 0.2); fill_stroke(ctx, hexc('#15101C'), OUT2, r * 0.06)
    star_path(ctx, EX1 * r, EY * r, r * 0.09, n=5, inner=0.45); ctx.set_source_rgba(*BONE); ctx.fill()


def eyes_hielo(ctx, r, t):
    for (x, s) in ((EX1, 0.21), (EX2, 0.19)):
        glow(ctx, x * r, EY * r, r * 0.32, FROSTC, 0.5)
        ctx.arc(x * r, EY * r, s * r, 0, 6.28); fill_stroke(ctx, hexc('#DFFAFF'), OUT2, r * 0.07)
        star_path(ctx, x * r, EY * r, s * r * 0.6, n=6, inner=0.35, rot=0); ctx.set_source_rgba(*hexc('#2E9AB8')); ctx.fill()


def eyes_gafas(ctx, r, t):
    rrect(ctx, -r * 0.82, -r * 0.66, r * 1.64, r * 0.17, r * 0.07); fill_stroke(ctx, hexc('#4A3020'), OUT2, r * 0.1)
    for s in (-1, 1):
        cx = s * r * 0.28
        ctx.arc(cx, -r * 0.58, r * 0.24, 0, 6.28); fill_stroke(ctx, hexc('#B98A3A'), OUT2, r * 0.12)
        ctx.arc(cx, -r * 0.58, r * 0.17, 0, 6.28); ctx.set_source(vgrad(-r * 0.75, -r * 0.4, hexc('#BFF4FF'), hexc('#2E7A8A'))); ctx.fill()


def eyes_fuego(ctx, r, t):
    for x in (EX1, EX2):
        glow(ctx, x * r, EY * r, r * 0.35, EMBER, 0.7)
        P(ctx, [(x * r - r * 0.16, EY * r - r * 0.05), (x * r + r * 0.16, EY * r - r * 0.1), (x * r + r * 0.1, EY * r + r * 0.08), (x * r - r * 0.12, EY * r + r * 0.07)])
        fill_stroke(ctx, hexc('#FFD27A'), OUT2, r * 0.06)


def eyes_monoculo(ctx, r, t):
    button_eye(ctx, EX1 * r, EY * r, r * 0.18, r, (0.3, 0))
    button_eye(ctx, EX2 * r, EY * r, r * 0.17, r, (0.3, 0), col=hexc('#5A0F1E'))
    ctx.arc(EX2 * r, EY * r, r * 0.26, 0, 6.28); ctx.set_source_rgba(*GOLD); ctx.set_line_width(r * 0.06); ctx.stroke()
    ctx.move_to(EX2 * r + r * 0.24, EY * r + r * 0.1); ctx.curve_to(r * 0.7, -r * 0.2, r * 0.6, r * 0.1, r * 0.55, r * 0.2)
    ctx.set_line_width(r * 0.02); ctx.stroke()


def eyes_cruz(ctx, r, t):
    x_eye(ctx, EX1 * r, EY * r, r * 0.17, r); x_eye(ctx, EX2 * r, EY * r, r * 0.17, r)


def eyes_antifaz(ctx, r, t):
    def mask():
        ctx.new_path(); ctx.move_to(-r * 0.75, -r * 0.62)
        ctx.curve_to(-r * 0.4, -r * 0.82, r * 0.4, -r * 0.82, r * 0.72, -r * 0.62)
        ctx.curve_to(r * 0.6, -r * 0.4, r * 0.2, -r * 0.38, 0, -r * 0.48)
        ctx.curve_to(-r * 0.2, -r * 0.38, -r * 0.6, -r * 0.4, -r * 0.75, -r * 0.62); ctx.close_path()
    of(ctx, mask, hexc('#1E1430'), r * 0.07)
    for x in (EX1, EX2):
        ellipse(ctx, x * r, EY * r - r * 0.04, r * 0.1, r * 0.07); ctx.set_source_rgba(1, 0.95, 0.8, 1); ctx.fill()


EYES = {'boton': eyes_boton, 'alma': eyes_alma, 'parche': eyes_parche, 'hielo': eyes_hielo, 'gafas': eyes_gafas,
        'fuego': eyes_fuego, 'monoculo': eyes_monoculo, 'cruz': eyes_cruz, 'antifaz': eyes_antifaz}

# =============================================================== CARA (boca, barba, colmillos…)
def face_boca_cosida(ctx, r, t):
    pts = bez((-r * 0.32, -r * 0.2), (0, -r * 0.02), (r * 0.34, -r * 0.22), 9)
    ctx.new_path(); ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    ctx.set_line_width(r * 0.065); ctx.set_source_rgba(*THREAD); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    stitched(ctx, pts, r * 0.065, r * 0.032, wa(BONE, 0.85), line=False)


def face_barba_mago(ctx, r, t):
    def beard():
        ctx.new_path(); ctx.move_to(-r * 0.4, -r * 0.18)
        ctx.curve_to(-r * 0.42, r * 0.1, -r * 0.2, r * 0.35, r * 0.02, r * 0.68)
        ctx.curve_to(r * 0.1, r * 0.45, r * 0.42, r * 0.15, r * 0.42, -r * 0.18)
        ctx.curve_to(r * 0.2, -r * 0.05, -r * 0.2, -r * 0.05, -r * 0.4, -r * 0.18); ctx.close_path()
    of(ctx, beard, vgrad(-r * 0.2, r * 0.68, hexc('#DCD6CC'), hexc('#8E867C')), r * 0.1)
    for sg in (-1, 1):
        def mus(sg=sg):
            ctx.new_path(); ctx.move_to(0, -r * 0.24)
            ctx.curve_to(sg * r * 0.2, -r * 0.3, sg * r * 0.42, -r * 0.2, sg * r * 0.45, -r * 0.05)
            ctx.curve_to(sg * r * 0.38, -r * 0.15, sg * r * 0.2, -r * 0.14, 0, -r * 0.14); ctx.close_path()
        of(ctx, mus, hexc('#BDB6AC'), r * 0.08)


def face_colmillos(ctx, r, t):
    face_boca_cosida(ctx, r, t)
    for s in (-1, 1):
        def tusk(s=s):
            ctx.new_path(); ctx.move_to(s * r * 0.2, -r * 0.08)
            ctx.curve_to(s * r * 0.24, -r * 0.24, s * r * 0.36, -r * 0.34, s * r * 0.42, -r * 0.44)
            ctx.curve_to(s * r * 0.4, -r * 0.26, s * r * 0.36, -r * 0.14, s * r * 0.32, -r * 0.06); ctx.close_path()
        of(ctx, tusk, vgrad(-r * 0.44, 0, hexc('#FFF6E4'), hexc('#B8A888')), r * 0.08)


def face_bigote(ctx, r, t):
    face_boca_cosida(ctx, r, t)
    for sg in (-1, 1):
        def mus(sg=sg):
            ctx.new_path(); ctx.move_to(0, -r * 0.3)
            ctx.curve_to(sg * r * 0.25, -r * 0.38, sg * r * 0.5, -r * 0.3, sg * r * 0.58, -r * 0.42)
            ctx.curve_to(sg * r * 0.55, -r * 0.18, sg * r * 0.25, -r * 0.18, 0, -r * 0.22); ctx.close_path()
        of(ctx, mus, hexc('#2A1A12'), r * 0.07)


def face_bufanda(ctx, r, t):
    face_boca_cosida(ctx, r, t)
    def scarf():
        rrect(ctx, -r * 0.62, -r * 0.08, r * 1.24, r * 0.26, r * 0.12)
    of(ctx, scarf, vgrad(-r * 0.1, r * 0.2, hexc('#9FD8E8'), hexc('#3E8AAA')), r * 0.08)
    def tail():
        P(ctx, [(r * 0.3, r * 0.1), (r * 0.55, r * 0.75), (r * 0.3, r * 0.8), (r * 0.15, r * 0.15)])
    of(ctx, tail, vgrad(0, r * 0.8, hexc('#9FD8E8'), hexc('#3E8AAA')), r * 0.07)
    for k in range(4):
        ctx.move_to(r * (0.27 + k * 0.06), r * 0.78); ctx.line_to(r * (0.27 + k * 0.06), r * 0.9)
    ctx.set_source_rgba(*hexc('#3E8AAA')); ctx.set_line_width(r * 0.04); ctx.stroke()


def face_colmillitos(ctx, r, t):
    ctx.move_to(-r * 0.3, -r * 0.2); ctx.curve_to(-r * 0.1, -r * 0.1, r * 0.1, -r * 0.1, r * 0.3, -r * 0.2)
    ctx.set_source_rgba(*THREAD); ctx.set_line_width(r * 0.06); ctx.stroke()
    for s in (-1, 1):
        P(ctx, [(s * r * 0.16, -r * 0.15), (s * r * 0.11, -r * 0.0), (s * r * 0.06, -r * 0.14)]); fill_stroke(ctx, hexc('#FFFFFF'), OUT2, r * 0.03)


def face_mascara_hueso(ctx, r, t):
    def mask():
        ctx.new_path(); ctx.move_to(-r * 0.34, -r * 0.26)
        ctx.curve_to(-r * 0.34, r * 0.02, -r * 0.15, r * 0.1, 0, r * 0.1)
        ctx.curve_to(r * 0.15, r * 0.1, r * 0.34, r * 0.02, r * 0.34, -r * 0.26); ctx.close_path()
    of(ctx, mask, vgrad(-r * 0.3, r * 0.1, hexc('#F2E8D4'), hexc('#B8A888')), r * 0.06)
    for k in range(4):
        x = -r * 0.18 + k * r * 0.12
        ctx.move_to(x, -r * 0.1); ctx.line_to(x, r * 0.04)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.03); ctx.stroke()


def face_barba_gnomo(ctx, r, t):
    def beard():
        ctx.new_path()
        for (bx, by, br) in ((-0.42, -0.2, 0.2), (-0.2, -0.08, 0.24), (0.05, -0.05, 0.25), (0.3, -0.12, 0.22),
                             (0.45, -0.25, 0.16), (-0.3, 0.15, 0.22), (0.0, 0.25, 0.25), (0.28, 0.15, 0.2), (0.0, 0.48, 0.18)):
            ctx.new_sub_path(); ctx.arc(bx * r, by * r, br * r, 0, 2 * math.pi)
    of(ctx, beard, vgrad(-r * 0.4, r * 0.7, hexc('#FFFFFF'), hexc('#B9B4C8')), r * 0.09)
    ctx.arc(r * 0.02, -r * 0.3, r * 0.17, 0, 6.28); fill_stroke(ctx, hexc('#E06070'), OUT2, r * 0.1)


FACE = {'boca': face_boca_cosida, 'barba_mago': face_barba_mago, 'colmillos': face_colmillos, 'bigote': face_bigote,
        'bufanda': face_bufanda, 'colmillitos': face_colmillitos, 'mascara_hueso': face_mascara_hueso,
        'barba_gnomo': face_barba_gnomo}

# =============================================================== CABEZA (sombreros…)
def head_none(ctx, r, t): pass


def head_mago(ctx, r, t, c0=hexc('#4A2F7A'), c1=hexc('#21153A'), band=hexc('#8E1F2B'), brim=hexc('#2A1B47'), stars=True):
    def hat():
        ctx.new_path(); ctx.move_to(-r * 0.62, -r * 0.98)
        ctx.curve_to(-r * 0.3, -r * 1.5, -r * 0.1, -r * 2.0, r * 0.05, -r * 2.3)
        ctx.curve_to(r * 0.25, -r * 2.38, r * 0.55, -r * 2.2, r * 0.62, -r * 2.05)
        ctx.curve_to(r * 0.35, -r * 2.05, r * 0.25, -r * 1.7, r * 0.6, -r * 0.98); ctx.close_path()
    of(ctx, hat, vgrad(-r * 2.2, -r * 1.0, c0, c1), r * 0.12)
    if stars:
        for (sx, sy, ss) in ((-0.15, -1.35, 0.1), (0.2, -1.6, 0.07), (0.05, -1.9, 0.06)):
            star_path(ctx, sx * r, sy * r, ss * r); ctx.set_source_rgba(*GOLD); ctx.fill()
    rrect(ctx, -r * 0.6, -r * 1.1, r * 1.2, r * 0.17, r * 0.06); fill_stroke(ctx, band, OUT2, r * 0.12)
    ellipse(ctx, 0, -r * 0.98, r * 0.95, r * 0.19)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.24); ctx.stroke_preserve(); ctx.set_source_rgba(*brim); ctx.fill()


def head_bruja(ctx, r, t):
    head_mago(ctx, r, t, c0=hexc('#BFEAF5'), c1=hexc('#3E8AAA'), band=hexc('#1E5A7A'), brim=hexc('#2E6A8A'), stars=False)
    for k in range(3):
        star_path(ctx, -r * 0.2 + k * r * 0.2, -r * (1.3 + k * 0.25), r * 0.08, n=6, inner=0.4, rot=0); ctx.set_source_rgba(1, 1, 1, 0.9); ctx.fill()


def head_tricornio(ctx, r, t):
    def hat():
        ctx.new_path(); ctx.move_to(-r * 1.05, -r * 1.0)
        ctx.curve_to(-r * 0.7, -r * 1.25, -r * 0.5, -r * 1.65, 0, -r * 1.6)
        ctx.curve_to(r * 0.5, -r * 1.65, r * 0.7, -r * 1.25, r * 1.05, -r * 1.0)
        ctx.curve_to(r * 0.5, -r * 1.15, -r * 0.5, -r * 1.15, -r * 1.05, -r * 1.0); ctx.close_path()
    of(ctx, hat, vgrad(-r * 1.6, -r * 1.0, hexc('#2A2030'), hexc('#120C18')), r * 0.12)
    ctx.move_to(-r * 0.9, -r * 1.05); ctx.curve_to(-r * 0.5, -r * 1.2, r * 0.5, -r * 1.2, r * 0.9, -r * 1.05)
    ctx.set_source_rgba(*GOLD); ctx.set_line_width(r * 0.05); ctx.stroke()
    # calavera
    ctx.arc(0, -r * 1.36, r * 0.13, 0, 6.28); fill_stroke(ctx, BONE, OUT2, r * 0.04)
    for s in (-1, 1):
        ctx.arc(s * r * 0.05, -r * 1.37, r * 0.03, 0, 6.28); ctx.set_source_rgba(*OUT2); ctx.fill()


def head_yelmo(ctx, r, t):
    def helm():
        ctx.new_path(); ctx.arc(0, -r * 0.62, r * 0.88, math.pi * 1.0, math.pi * 2.0)
        ctx.line_to(r * 0.88, -r * 0.35); ctx.line_to(-r * 0.88, -r * 0.35); ctx.close_path()
    of(ctx, helm, vgrad(-r * 1.5, -r * 0.35, hexc('#B8B0A4'), hexc('#5E564C')), r * 0.12)
    ctx.rectangle(-r * 0.7, -r * 0.66, r * 1.4, r * 0.14); ctx.set_source_rgba(*OUT2); ctx.fill()     # visera
    for k in range(5):
        ctx.arc(-r * 0.6 + k * r * 0.3, -r * 0.45, r * 0.035, 0, 6.28); ctx.set_source_rgba(*hexc('#E8DCC4')); ctx.fill()
    for k in range(4):
        ctx.arc(-r * 0.5 + k * r * 0.35, -r * 1.05 + (k % 2) * r * 0.2, r * 0.07, 0, 6.28); ctx.set_source_rgba(*wa(hexc('#A0522D'), 0.8)); ctx.fill()
    def plume():
        ctx.new_path(); ctx.move_to(0, -r * 1.48)
        ctx.curve_to(r * 0.3, -r * 2.1, -r * 0.6, -r * 2.2, -r * 0.9, -r * 1.7)
        ctx.curve_to(-r * 0.5, -r * 1.85, -r * 0.2, -r * 1.7, 0, -r * 1.48); ctx.close_path()
    of(ctx, plume, vgrad(-r * 2.1, -r * 1.5, hexc('#FF6A2B'), hexc('#8E1F2B')), r * 0.08)


def head_seta(ctx, r, t):
    def cap():
        ctx.new_path(); ctx.move_to(-r * 1.15, -r * 0.95)
        ctx.curve_to(-r * 1.1, -r * 1.85, r * 1.1, -r * 1.85, r * 1.15, -r * 0.95)
        ctx.curve_to(r * 0.5, -r * 1.1, -r * 0.5, -r * 1.1, -r * 1.15, -r * 0.95); ctx.close_path()
    of(ctx, cap, vgrad(-r * 1.8, -r * 0.95, hexc('#E0505A'), hexc('#8E1F2B')), r * 0.12)
    for (x, y, s) in ((-0.55, -1.25, 0.16), (0.1, -1.5, 0.2), (0.6, -1.2, 0.13), (-0.15, -1.15, 0.1)):
        ellipse(ctx, x * r, y * r, s * r, s * r * 0.8); ctx.set_source_rgba(*hexc('#FFF6E4')); ctx.fill()


def head_calabaza(ctx, r, t):
    glow(ctx, 0, -r * 0.5, r * 1.1, EMBER, 0.25)
    def pump():
        ctx.new_path()
        for (x, rx) in ((-0.45, 0.48), (0.45, 0.48), (0, 0.55)):
            ctx.new_sub_path(); ellipse(ctx, x * r, -r * 0.55, rx * r, r * 0.72)
    of(ctx, pump, vgrad(-r * 1.3, r * 0.2, hexc('#FF9A3A'), hexc('#C2501A')), r * 0.12)
    for x in (-0.25, 0.25):
        ctx.move_to(x * r, -r * 1.2); ctx.curve_to(x * r * 1.4, -r * 0.6, x * r * 1.4, -r * 0.4, x * r, r * 0.1)
    ctx.set_source_rgba(*wa(hexc('#8A3A10'), 0.7)); ctx.set_line_width(r * 0.04); ctx.stroke()
    rrect(ctx, -r * 0.08, -r * 1.48, r * 0.16, r * 0.25, r * 0.04); fill_stroke(ctx, hexc('#4A7A2A'), OUT2, r * 0.06)
    for x in (-0.3, 0.3):    # ojos tallados
        P(ctx, [(x * r - r * 0.15, -r * 0.55), (x * r, -r * 0.8), (x * r + r * 0.15, -r * 0.55)])
        ctx.set_source_rgba(*hexc('#FFE27A')); ctx.fill()
    P(ctx, [(-r * 0.45, -r * 0.25), (-r * 0.25, -r * 0.1), (-r * 0.1, -r * 0.22), (r * 0.05, -r * 0.08), (r * 0.2, -r * 0.22),
            (r * 0.45, -r * 0.25), (r * 0.25, r * 0.05), (-r * 0.25, r * 0.05)])
    ctx.set_source_rgba(*hexc('#FFE27A')); ctx.fill()


def head_orejas_rata(ctx, r, t):
    for s in (-1, 1):
        ctx.arc(s * r * 0.6, -r * 1.05, r * 0.36, 0, 6.28); fill_stroke(ctx, hexc('#8C8296'), OUT2, r * 0.12)
        ctx.arc(s * r * 0.6, -r * 1.05, r * 0.22, 0, 6.28); ctx.set_source_rgba(*hexc('#E8A0B0')); ctx.fill()


def head_cuernos(ctx, r, t):
    for s in (-1, 1):
        def horn(s=s):
            ctx.new_path(); ctx.move_to(s * r * 0.35, -r * 1.05)
            ctx.curve_to(s * r * 0.4, -r * 1.5, s * r * 0.8, -r * 1.7, s * r * 1.0, -r * 1.6)
            ctx.curve_to(s * r * 0.75, -r * 1.45, s * r * 0.65, -r * 1.2, s * r * 0.65, -r * 0.95); ctx.close_path()
        of(ctx, horn, vgrad(-r * 1.6, -r * 0.95, hexc('#F2E8D4'), hexc('#8A7A5A')), r * 0.1)


def head_pelo_vampiro(ctx, r, t):
    def hair():
        ctx.new_path(); ctx.move_to(-r * 0.84, -r * 0.55)
        ctx.curve_to(-r * 0.9, -r * 1.3, r * 0.9, -r * 1.3, r * 0.84, -r * 0.55)
        ctx.curve_to(r * 0.6, -r * 0.95, r * 0.2, -r * 0.95, 0, -r * 0.7)
        ctx.curve_to(-r * 0.2, -r * 0.95, -r * 0.6, -r * 0.95, -r * 0.84, -r * 0.55); ctx.close_path()
    of(ctx, hair, vgrad(-r * 1.2, -r * 0.55, hexc('#2A2030'), hexc('#0E0A14')), r * 0.1)


def head_capucha_frente(ctx, r, t):
    ctx.save(); ctx.new_path(); ctx.arc(0, -r * 0.42, r * 0.84, 0, 2 * math.pi); ctx.clip()
    ctx.new_path(); ctx.arc(0, -r * 0.42, r * 0.92, math.radians(185), math.radians(355))
    ctx.set_line_width(r * 0.42); ctx.set_source_rgba(*hexc('#241C30')); ctx.stroke(); ctx.restore()


def head_gorro_gnomo(ctx, r, t):
    def cap():
        ctx.new_path(); ctx.move_to(-r * 0.8, -r * 0.95)
        ctx.curve_to(-r * 0.6, -r * 1.8, r * 0.3, -r * 2.4, r * 0.9, -r * 2.0)
        ctx.curve_to(r * 0.5, -r * 1.7, r * 0.75, -r * 1.3, r * 0.8, -r * 0.95); ctx.close_path()
    of(ctx, cap, vgrad(-r * 2.2, -r * 0.95, hexc('#E0505A'), hexc('#8E1F2B')), r * 0.12)
    rrect(ctx, -r * 0.85, -r * 1.05, r * 1.7, r * 0.18, r * 0.08); fill_stroke(ctx, hexc('#FFF6E4'), OUT2, r * 0.1)


HEAD = {'nada': head_none, 'mago': head_mago, 'bruja': head_bruja, 'tricornio': head_tricornio, 'yelmo': head_yelmo,
        'seta': head_seta, 'calabaza': head_calabaza, 'orejas_rata': head_orejas_rata, 'cuernos': head_cuernos,
        'pelo_vampiro': head_pelo_vampiro, 'capucha': head_capucha_frente, 'gorro_gnomo': head_gorro_gnomo}

# =============================================================== ROPA (torso)
ROBE = {'nada': None, 'tunica_roja': hexc('#5A1E28'), 'tunica_negra': hexc('#2A2236'), 'chaleco_pirata': hexc('#3A2A20'),
        'armadura': hexc('#7A7268'), 'tunica_hielo': hexc('#2E6A8A'), 'harapos': hexc('#6E5A3A'), 'traje': hexc('#1E1420')}


# =============================================================== muñeco completo
def draw_doll(ctx, cfg, r, t=0.0, pid=1):
    col = PCOL[cfg.get('color', 'coral')]
    ow = r * 0.14
    BACK[cfg.get('espalda', 'nada')](ctx, r, t)
    if cfg.get('cabeza') == 'capucha':
        back_capucha(ctx, r, t)
    HAND[cfg.get('mano', 'nada')](ctx, r, t)
    legs = [(-0.3, 0.84), (0.3, 0.84)]; arms = [(-0.66, 0.36, 0.55), (0.66, 0.36, -0.55)]

    def leg(i):
        def f(): ctx.new_path(); ellipse(ctx, legs[i][0] * r, legs[i][1] * r, r * 0.2, r * 0.19)
        return f

    def arm(i):
        def f():
            ctx.new_path(); ctx.save(); ctx.translate(arms[i][0] * r, arms[i][1] * r); ctx.rotate(arms[i][2])
            ellipse(ctx, 0, 0, r * 0.17, r * 0.29); ctx.restore()
        return f

    def body(): ctx.new_path(); blob(ctx, 0, r * 0.4, r * 0.62, r * 0.5, 10 + pid, 0.04)

    def head():
        ctx.new_path()
        if cfg.get('cabeza') == 'calabaza':
            ellipse(ctx, 0, -r * 0.42, r * 0.5, r * 0.5)
        else:
            blob(ctx, 0, -r * 0.42, r * 0.84, r * 0.75, 20 + pid, 0.05)
    for f in (leg(0), leg(1), arm(0), arm(1), body, head):
        f(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
    for i in (0, 1):
        fabric_fill(ctx, leg(i), shade(col, -0.32), r * 0.3, cx=legs[i][0] * r, cy=legs[i][1] * r)
        fabric_fill(ctx, arm(i), shade(col, -0.15), r * 0.35, cx=arms[i][0] * r, cy=arms[i][1] * r)
    robe = ROBE.get(cfg.get('ropa', 'nada'))
    fabric_fill(ctx, body, robe or col, r * 0.7, cx=0, cy=r * 0.4)
    ctx.save(); body(); ctx.clip()
    if cfg.get('ropa') == 'armadura':
        for k in range(3):
            ctx.move_to(-r, r * (0.1 + k * 0.25)); ctx.line_to(r, r * (0.1 + k * 0.25))
        ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.04); ctx.stroke()
    if cfg.get('ropa') == 'chaleco_pirata':
        ctx.rectangle(-r * 0.15, -r, r * 0.3, 2 * r); ctx.set_source_rgba(*hexc('#E8DCC4')); ctx.fill()
        ctx.rectangle(-r, r * 0.55, 2 * r, r * 0.1); ctx.set_source_rgba(*hexc('#8E1F2B')); ctx.fill()
    ctx.restore()
    k = r * 0.12; cy_ = r * 0.56            # la X cosida del pecho, seña de todos los muñecos
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for (lw, c) in ((r * 0.12, OUT2), (r * 0.065, BONE)):
        ctx.move_to(-k + r * 0.06, cy_ - k); ctx.line_to(k + r * 0.06, cy_ + k)
        ctx.move_to(-k + r * 0.06, cy_ + k); ctx.line_to(k + r * 0.06, cy_ - k)
        ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()
    if cfg.get('espalda') == 'capa':
        collar_vampiro(ctx, r)
    if cfg.get('cabeza') != 'calabaza':
        fabric_fill(ctx, head, col, r * 0.85, cx=0, cy=-r * 0.42)
        pts = bez((-r * 0.05, -r * 1.14), (r * 0.62, -r * 1.0), (r * 0.8, -r * 0.4), 9)
        stitched(ctx, pts, r * 0.05, r * 0.03, wa(THREAD, 0.85))
        if cfg.get('cabeza') == 'capucha':
            head_capucha_frente(ctx, r, t)
        EYES[cfg.get('ojos', 'boton')](ctx, r, t)
        FACE[cfg.get('cara', 'boca')](ctx, r, t)
        if cfg.get('cabeza') not in ('capucha',):
            HEAD[cfg.get('cabeza', 'nada')](ctx, r, t)
    else:
        HEAD['calabaza'](ctx, r, t)


# =============================================================== personajes
NUEVOS = [
    ('ESCARCHA', 'Bruja del hielo', {'color': 'azul', 'cabeza': 'bruja', 'ojos': 'hielo', 'cara': 'bufanda', 'mano': 'varita_hielo', 'ropa': 'tunica_hielo'}),
    ('GARFIO', 'Pirata de trapo', {'color': 'coral', 'cabeza': 'tricornio', 'ojos': 'parche', 'cara': 'bigote', 'mano': 'saco', 'ropa': 'chaleco_pirata'}),
    ('CALABAZO', 'Espantapájaros', {'color': 'hueso', 'cabeza': 'calabaza', 'mano': 'farol', 'ropa': 'harapos'}),
    ('RATERO', 'Rata ladrona', {'color': 'hueso', 'cabeza': 'orejas_rata', 'ojos': 'antifaz', 'cara': 'colmillitos', 'mano': 'saco', 'espalda': 'cola'}),
    ('HERRUMBRE', 'Caballero oxidado', {'color': 'lima', 'cabeza': 'yelmo', 'ojos': 'boton', 'cara': 'boca', 'mano': 'espada', 'ropa': 'armadura'}),
    ('MOHO', 'Chamana de las setas', {'color': 'lima', 'cabeza': 'seta', 'ojos': 'boton', 'cara': 'mascara_hueso', 'mano': 'baston_seta', 'ropa': 'harapos'}),
    ('CONDE HILO', 'Vampiro de trapo', {'color': 'hueso', 'cabeza': 'pelo_vampiro', 'ojos': 'monoculo', 'cara': 'colmillitos', 'espalda': 'capa', 'ropa': 'traje'}),
    ('TIZÓN', 'Diablillo', {'color': 'coral', 'cabeza': 'cuernos', 'ojos': 'fuego', 'cara': 'colmillitos', 'mano': 'tridente', 'espalda': 'cola'}),
]
ACTUALES = [
    ('BRASA', 'Mago del fuego', {'color': 'coral', 'cabeza': 'mago', 'ojos': 'boton', 'cara': 'barba_mago', 'mano': 'baston_fuego', 'ropa': 'tunica_roja'}),
    ('COLMILLO', 'Trol del pantano', {'color': 'azul', 'espalda': 'orejas_trol', 'ojos': 'boton', 'cara': 'colmillos'}),
    ('TUERCA', 'Gnomo inventor', {'color': 'lima', 'cabeza': 'gorro_gnomo', 'ojos': 'gafas', 'cara': 'barba_gnomo', 'mano': 'llave'}),
    ('CRIPTA', 'Nigromante', {'color': 'hueso', 'cabeza': 'capucha', 'ojos': 'alma', 'cara': 'boca', 'mano': 'guadana', 'ropa': 'tunica_negra'}),
]
BG = hexc('#120B1A'); MUTED = hexc('#B8A9D1'); BONEW = hexc('#EFE7DA')


def card(c, x, y, w, h, name, role, cfg, num=None, r=92, t=0.3):
    rrect(c, x, y, w, h, 18); c.set_source_rgba(*hexc('#1E1430')); c.fill_preserve()
    c.set_source_rgba(*hexc('#3A2A52')); c.set_line_width(2); c.stroke()
    if num is not None:
        c.arc(x + 30, y + 30, 18, 0, 6.28); c.set_source_rgba(*EMBER); c.fill()
        draw_text(c, str(num), x + 30, y + 30, 22, fam="Oswald", fill=hexc('#0B0710'), ow=0, bold=True)
    ellipse(c, x + w / 2, y + h * 0.68, r * 0.95, r * 0.28); c.set_source_rgba(0, 0, 0, 0.4); c.fill()
    c.save(); c.translate(x + w / 2, y + h * 0.68 - r * 0.95); draw_doll(c, cfg, r, t); c.restore()
    draw_text(c, name, x + w / 2, y + h - 62, 30, fam="Cinzel", fill=EMBER, ow=0, bold=True)
    draw_text(c, role, x + w / 2, y + h - 28, 22, fam="Oswald", fill=BONEW, ow=0)


def sheet_nuevos(path):
    W_, H_ = 1920, 1180
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W_, H_); c = cairo.Context(s)
    c.set_source_rgba(*BG); c.paint()
    draw_text(c, "PERSONAJES NUEVOS", W_ / 2, 60, 52, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    draw_text(c, "Elige los que quieras. Todos están hechos por piezas: luego cualquier pieza se puede poner en cualquier muñeco.",
              W_ / 2, 112, 24, fam="Oswald", fill=MUTED, ow=0)
    cw, ch = 440, 500
    for i, (n, rl, cfg) in enumerate(NUEVOS):
        col, row = i % 4, i // 4
        card(c, 40 + col * (cw + 20), 150 + row * (ch + 20), cw, ch, n, rl, cfg, num=i + 1)
    s.write_to_png(path)


def sheet_mezclas(path):
    W_, H_ = 1920, 1180
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W_, H_); c = cairo.Context(s)
    c.set_source_rgba(*BG); c.paint()
    draw_text(c, "COSMÉTICOS SUELTOS: MEZCLA PIEZAS DE CUALQUIER PERSONAJE", W_ / 2, 60, 40, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    draw_text(c, "Cabeza · Ojos · Cara · Mano · Espalda · Ropa  —  el color de tela es siempre el del jugador",
              W_ / 2, 108, 24, fam="Oswald", fill=MUTED, ow=0)
    mixes = [
        ('Sombrero de Brasa + gafas de Tuerca + saco de Garfio', {'color': 'azul', 'cabeza': 'mago', 'ojos': 'gafas', 'cara': 'boca', 'mano': 'saco'}),
        ('Cuernos de Tizón + capa de Conde Hilo + guadaña de Cripta', {'color': 'lima', 'cabeza': 'cuernos', 'ojos': 'alma', 'cara': 'colmillitos', 'mano': 'guadana', 'espalda': 'capa'}),
        ('Tricornio de Garfio + barba de Gnomo + varita de Escarcha', {'color': 'hueso', 'cabeza': 'tricornio', 'ojos': 'boton', 'cara': 'barba_gnomo', 'mano': 'varita_hielo'}),
        ('Seta de Moho + antifaz de Ratero + espada de Herrumbre', {'color': 'coral', 'cabeza': 'seta', 'ojos': 'antifaz', 'cara': 'boca', 'mano': 'espada', 'espalda': 'cola'}),
    ]
    cw, ch = 440, 470
    for i, (lbl, cfg) in enumerate(mixes):
        x = 40 + i * (cw + 20)
        rrect(c, x, 140, cw, ch, 18); c.set_source_rgba(*hexc('#1E1430')); c.fill()
        ellipse(c, x + cw / 2, 140 + ch * 0.66, 66, 20); c.set_source_rgba(0, 0, 0, 0.4); c.fill()
        c.save(); c.translate(x + cw / 2, 140 + ch * 0.66 - 66); draw_doll(c, cfg, 70, 0.4); c.restore()
        words = lbl.split(' + ')
        for k, wd in enumerate(words):
            draw_text(c, ('+ ' if k else '') + wd, x + cw / 2, 140 + ch - 110 + k * 32, 22, fam="Oswald", fill=BONEW if k == 0 else MUTED, ow=0)
    # catálogo de piezas
    y0 = 650
    rows = [('CABEZA', 'cabeza', ['mago', 'bruja', 'tricornio', 'yelmo', 'seta', 'orejas_rata', 'cuernos', 'gorro_gnomo', 'pelo_vampiro', 'capucha']),
            ('OJOS', 'ojos', ['boton', 'alma', 'parche', 'hielo', 'gafas', 'fuego', 'monoculo', 'cruz', 'antifaz']),
            ('MANO', 'mano', ['baston_fuego', 'varita_hielo', 'saco', 'espada', 'guadana', 'llave', 'farol', 'tridente', 'baston_seta'])]
    for ri, (title, slot, items) in enumerate(rows):
        yy = y0 + ri * 175
        draw_text(c, title, 120, yy + 70, 28, fam="Cinzel", fill=EMBER, ow=0, bold=True)
        for k, it in enumerate(items):
            x = 230 + k * 165
            rrect(c, x, yy, 150, 160, 12); c.set_source_rgba(*hexc('#1E1430')); c.fill()
            cfg = {'color': 'hueso', 'ojos': 'boton', 'cara': 'boca'}; cfg[slot] = it
            sc = 0.75 if slot == 'mano' else 1.0
            c.save(); c.translate(x + 75 - (12 if slot == 'mano' else 0), yy + (90 if slot != 'cabeza' else 105)); c.scale(sc, sc)
            draw_doll(c, cfg, 34, 0.3); c.restore()
    s.write_to_png(path)


if __name__ == '__main__':
    out = 'out/modular'; os.makedirs(out, exist_ok=True)
    sheet_nuevos(os.path.join(out, 'personajes_nuevos.png'))
    sheet_mezclas(os.path.join(out, 'mezclas.png'))
    print('ok')
