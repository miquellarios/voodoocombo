"""Personajes v3: muñecos vudú de fantasía (mago, trol, gnomo, nigromante), diseños originales."""
import cairo, math, random
from gfx import *
from chars import (OUT2, THREAD, BONE, TWINE, weave, blob, bez, stitched, fabric_fill, pin, button_eye, x_eye,
                   closed_eye, socket_eye)

KINDS = ['mago', 'trol', 'gnomo', 'nigro']
HERO_NAME = {'mago': 'BRASA', 'trol': 'COLMILLO', 'gnomo': 'TUERCA', 'nigro': 'CRIPTA'}
HERO_ROLE = {'mago': 'Mago del fuego', 'trol': 'Trol del pantano', 'gnomo': 'Gnomo inventor', 'nigro': 'Nigromante'}
PCOL3 = [hexc('#D8484F'), hexc('#3C7FD0'), hexc('#63A83A'), hexc('#D9D0BE')]


def _p(ctx, pts, close=True):
    ctx.new_path(); ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    if close:
        ctx.close_path()


def outline_fill(ctx, path, fill, ow):
    path(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
    path()
    if isinstance(fill, cairo.Pattern):
        ctx.set_source(fill)
    else:
        ctx.set_source_rgba(*fill)
    ctx.fill()


def glow(ctx, x, y, rad, col, a):
    g = cairo.RadialGradient(x, y, 0, x, y, rad)
    g.add_color_stop_rgba(0, *wa(col, a)); g.add_color_stop_rgba(0.4, *wa(col, a * 0.45)); g.add_color_stop_rgba(1, *wa(col, 0))
    ctx.set_source(g); ctx.arc(x, y, rad, 0, 2 * math.pi); ctx.fill()


# ---------------------------------------------------------------- piezas traseras (antes del cuerpo)
def back_parts(ctx, kind, r, t, col):
    ow = r * 0.13
    if kind == 'mago':   # bastón con orbe de fuego
        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        for (lw, c) in ((r * 0.17, OUT2), (r * 0.09, hexc('#6B4A2E'))):
            ctx.move_to(r * 0.8, r * 0.95); ctx.curve_to(r * 0.86, r * 0.3, r * 0.95, -r * 0.2, r * 1.0, -r * 0.62)
            ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()
        fl = 0.8 + 0.2 * math.sin(t * 13) * math.sin(t * 7.3)
        glow(ctx, r * 1.0, -r * 0.8, r * 0.75, hexc('#FF7A2A'), 0.7 * fl)
        ctx.arc(r * 1.0, -r * 0.8, r * 0.18, 0, 2 * math.pi); fill_stroke(ctx, hexc('#FFB347'), OUT2, ow)
        ctx.arc(r * 0.97, -r * 0.84, r * 0.08, 0, 2 * math.pi); ctx.set_source_rgba(1, 0.95, 0.8, 1); ctx.fill()
        for k in range(3):
            a = t * 3 + k * 2.1; yy = -r * 1.0 - ((t * 0.9 + k * 0.33) % 1) * r * 0.5
            ctx.arc(r * 1.0 + math.sin(a) * r * 0.1, yy, r * 0.04 * (1 - ((t * 0.9 + k * 0.33) % 1)), 0, 2 * math.pi)
            ctx.set_source_rgba(1, 0.6, 0.2, 0.9); ctx.fill()
    elif kind == 'trol':  # orejas largas y rastas
        for s in (-1, 1):
            def ear(s=s):
                _p(ctx, [(s * r * 0.62, -r * 0.7), (s * r * 1.45, -r * 0.98), (s * r * 1.3, -r * 0.82),
                         (s * r * 1.38, -r * 0.7), (s * r * 0.7, -r * 0.3)])
            outline_fill(ctx, ear, col, ow)
            ctx.save(); ear(); ctx.clip(); ctx.set_source(weave(r)); ctx.paint_with_alpha(0.9)
            _p(ctx, [(s * r * 0.72, -r * 0.62), (s * r * 1.25, -r * 0.86), (s * r * 0.78, -r * 0.4)])
            ctx.set_source_rgba(*wa(shade(col, -0.5), 0.6)); ctx.fill(); ctx.restore()
            pts = bez((s * r * 0.8, -r * 0.72), (s * r * 1.05, -r * 0.82), (s * r * 1.3, -r * 0.92), 5)
            stitched(ctx, pts, r * 0.04, r * 0.022, wa(BONE, 0.7), line=False)
        rng = random.Random(4)
        for k in range(6):
            s = -1 if k < 3 else 1; j = k % 3
            x0 = s * r * (0.35 + j * 0.15); y0 = -r * 1.05 + j * r * 0.08
            x1 = s * r * (0.72 + j * 0.12); y1 = r * (0.15 + j * 0.18)
            for (lw, c) in ((r * 0.2, OUT2), (r * 0.12, hexc('#6E2A1E'))):
                ctx.move_to(x0, y0); ctx.curve_to(x0 + s * r * 0.4, y0 + r * 0.2, x1, y1 - r * 0.5, x1, y1)
                ctx.set_line_width(lw); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_source_rgba(*c); ctx.stroke()
            ellipse(ctx, x1, y1 - r * 0.1, r * 0.07, r * 0.1); fill_stroke(ctx, BONE, OUT2, r * 0.035)
    elif kind == 'nigro':  # capucha trasera
        def hood():
            ctx.new_path(); ctx.move_to(0, -r * 1.55)
            ctx.curve_to(r * 0.65, -r * 1.35, r * 1.15, -r * 0.6, r * 1.0, r * 0.3)
            for i in range(9):
                ctx.line_to(r * 1.0 - (i + 1) * r * 0.222, r * 0.3 + (r * 0.1 if i % 2 == 0 else 0))
            ctx.curve_to(-r * 1.15, -r * 0.6, -r * 0.65, -r * 1.35, 0, -r * 1.55); ctx.close_path()
        g = cairo.LinearGradient(0, -r * 1.5, 0, r * 0.3); g.add_color_stop_rgba(0, *hexc('#3A2F4A')); g.add_color_stop_rgba(1, *hexc('#17121F'))
        outline_fill(ctx, hood, g, ow)
        ctx.save(); hood(); ctx.clip(); ctx.set_source(weave(r)); ctx.paint_with_alpha(0.7); ctx.restore()


# ---------------------------------------------------------------- cara y piezas delanteras
def face_front(ctx, kind, r, t, col, look, blink):
    ow = r * 0.13
    ex1, ex2, ey = -r * 0.32, r * 0.3, -r * 0.55
    if kind == 'mago':
        if blink:
            _blink(ctx, r, ex1, ex2, ey)
        else:
            button_eye(ctx, ex1, ey, r * 0.22, r, look)
            button_eye(ctx, ex2, ey, r * 0.2, r, look, col=hexc('#3A1A10'))
            glow(ctx, ex2, ey, r * 0.3, hexc('#FF7A2A'), 0.35 + 0.15 * math.sin(t * 9))
        # barba puntiaguda y bigote
        def beard():
            ctx.new_path(); ctx.move_to(-r * 0.4, -r * 0.18)
            ctx.curve_to(-r * 0.42, r * 0.1, -r * 0.2, r * 0.35, r * 0.02, r * 0.68)
            ctx.curve_to(r * 0.1, r * 0.45, r * 0.42, r * 0.15, r * 0.42, -r * 0.18)
            ctx.curve_to(r * 0.2, -r * 0.05, -r * 0.2, -r * 0.05, -r * 0.4, -r * 0.18); ctx.close_path()
        g = cairo.LinearGradient(0, -r * 0.2, 0, r * 0.68); g.add_color_stop_rgba(0, *hexc('#DCD6CC')); g.add_color_stop_rgba(1, *hexc('#8E867C'))
        outline_fill(ctx, beard, g, ow * 0.8)
        ctx.save(); beard(); ctx.clip()
        for k in range(6):
            x = -r * 0.3 + k * r * 0.12
            ctx.move_to(x, -r * 0.1); ctx.curve_to(x + r * 0.05, r * 0.15, x - r * 0.04, r * 0.35, x * 0.3, r * 0.62)
        ctx.set_source_rgba(*wa(hexc('#6E665C'), 0.75)); ctx.set_line_width(r * 0.022); ctx.stroke(); ctx.restore()
        ctx.arc(r * 0.03, r * 0.5, r * 0.06, 0, 2 * math.pi); fill_stroke(ctx, hexc('#C0392B'), OUT2, ow * 0.5)
        for sgn in (-1, 1):
            def mus(sgn=sgn):
                ctx.new_path(); ctx.move_to(0, -r * 0.24)
                ctx.curve_to(sgn * r * 0.2, -r * 0.3, sgn * r * 0.42, -r * 0.2, sgn * r * 0.45, -r * 0.05)
                ctx.curve_to(sgn * r * 0.38, -r * 0.15, sgn * r * 0.2, -r * 0.14, 0, -r * 0.14); ctx.close_path()
            outline_fill(ctx, mus, hexc('#BDB6AC'), ow * 0.6)
        # sombrero de mago torcido con estrellas
        def hat():
            ctx.new_path(); ctx.move_to(-r * 0.62, -r * 0.98)
            ctx.curve_to(-r * 0.3, -r * 1.5, -r * 0.1, -r * 2.0, r * 0.05, -r * 2.3)
            ctx.curve_to(r * 0.25, -r * 2.38, r * 0.55, -r * 2.2, r * 0.62, -r * 2.05)
            ctx.curve_to(r * 0.35, -r * 2.05, r * 0.25, -r * 1.7, r * 0.6, -r * 0.98); ctx.close_path()
        g = cairo.LinearGradient(-r * 0.6, -r * 2.2, r * 0.6, -r * 1.0); g.add_color_stop_rgba(0, *hexc('#4A2F7A')); g.add_color_stop_rgba(1, *hexc('#21153A'))
        outline_fill(ctx, hat, g, ow)
        ctx.save(); hat(); ctx.clip(); ctx.set_source(weave(r)); ctx.paint_with_alpha(0.6)
        for (sx, sy, ss) in ((-0.15, -1.35, 0.1), (0.2, -1.6, 0.07), (0.05, -1.9, 0.06)):
            star_path(ctx, sx * r, sy * r, ss * r); ctx.set_source_rgba(*GOLD); ctx.fill()
        ctx.restore()
        rrect(ctx, -r * 0.6, -r * 1.1, r * 1.2, r * 0.17, r * 0.06); fill_stroke(ctx, hexc('#8E1F2B'), OUT2, ow)
        ellipse(ctx, 0, -r * 0.98, r * 0.95, r * 0.19)
        ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.stroke_preserve(); ctx.set_source_rgba(*hexc('#2A1B47')); ctx.fill()
        ctx.move_to(-r * 0.85, -r * 0.95); ctx.curve_to(-r * 0.3, -r * 0.82, r * 0.3, -r * 0.82, r * 0.85, -r * 0.95)
        ctx.set_dash([r * 0.06, r * 0.05]); ctx.set_line_width(r * 0.025); ctx.set_source_rgba(*wa(BONE, 0.6)); ctx.stroke(); ctx.set_dash([])
    elif kind == 'trol':
        if blink:
            _blink(ctx, r, ex1, ex2, ey)
        else:
            button_eye(ctx, ex1, ey, r * 0.2, r, look, col=hexc('#2A2018'))
            button_eye(ctx, ex2, ey + r * 0.02, r * 0.24, r, look)
        # nariz larga cosida
        def nose():
            ctx.new_path(); ctx.move_to(-r * 0.05, -r * 0.48)
            ctx.curve_to(r * 0.02, -r * 0.48, r * 0.16, -r * 0.3, r * 0.12, -r * 0.2)
            ctx.curve_to(r * 0.08, -r * 0.1, -r * 0.1, -r * 0.12, -r * 0.1, -r * 0.24); ctx.close_path()
        g = cairo.LinearGradient(0, -r * 0.48, 0, -r * 0.12); g.add_color_stop_rgba(0, *shade(col, -0.05)); g.add_color_stop_rgba(1, *shade(col, -0.4))
        outline_fill(ctx, nose, g, ow * 0.6)
        for nx in (-0.03, 0.06):
            ctx.arc(nx * r, -r * 0.17, r * 0.025, 0, 2 * math.pi); ctx.set_source_rgba(*OUT2); ctx.fill()
        _mouth(ctx, r, y0=-r * 0.02)
        for s in (-1, 1):
            def tusk(s=s):
                ctx.new_path(); ctx.move_to(s * r * 0.2, -r * 0.0)
                ctx.curve_to(s * r * 0.24, -r * 0.18, s * r * 0.36, -r * 0.3, s * r * 0.42, -r * 0.42)
                ctx.curve_to(s * r * 0.4, -r * 0.22, s * r * 0.36, -r * 0.08, s * r * 0.32, r * 0.02); ctx.close_path()
            g = cairo.LinearGradient(0, -r * 0.42, 0, r * 0.02); g.add_color_stop_rgba(0, *hexc('#FFF6E4')); g.add_color_stop_rgba(1, *hexc('#B8A888'))
            outline_fill(ctx, tusk, g, ow * 0.7)
        ctx.new_path()
        for k in range(3):
            ctx.new_sub_path(); ctx.arc(-r * 0.2 + k * r * 0.2, -r * 1.12, r * 0.12, 0, 2 * math.pi)
        ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 1.6); ctx.stroke_preserve(); ctx.set_source_rgba(*hexc('#6E2A1E')); ctx.fill()
        pin(ctx, r * 0.5, -r * 0.85, -0.6, r * 0.45, hexc('#7BE042'), r)
    elif kind == 'gnomo':
        if blink:
            _blink(ctx, r, ex1 + r * 0.04, ex2 - r * 0.04, ey + r * 0.05)
        else:
            button_eye(ctx, ex1 + r * 0.04, ey + r * 0.05, r * 0.14, r, look, col=hexc('#2A1A12'))
            button_eye(ctx, ex2 - r * 0.04, ey + r * 0.05, r * 0.14, r, look, col=hexc('#2A1A12'))
        def beard():
            ctx.new_path()
            for (bx, by, br) in ((-0.42, -0.2, 0.2), (-0.2, -0.08, 0.24), (0.05, -0.05, 0.25), (0.3, -0.12, 0.22),
                                 (0.45, -0.25, 0.16), (-0.3, 0.15, 0.22), (0.0, 0.25, 0.25), (0.28, 0.15, 0.2), (0.0, 0.48, 0.18)):
                ctx.new_sub_path(); ctx.arc(bx * r, by * r, br * r, 0, 2 * math.pi)
        g = cairo.LinearGradient(0, -r * 0.4, 0, r * 0.7); g.add_color_stop_rgba(0, *hexc('#FFFFFF')); g.add_color_stop_rgba(1, *hexc('#B9B4C8'))
        outline_fill(ctx, beard, g, ow * 0.8)
        ctx.arc(r * 0.02, -r * 0.3, r * 0.17, 0, 2 * math.pi)
        g = cairo.RadialGradient(-r * 0.04, -r * 0.36, r * 0.02, r * 0.02, -r * 0.3, r * 0.17)
        g.add_color_stop_rgba(0, *hexc('#FF9AA0')); g.add_color_stop_rgba(1, *hexc('#C2404A'))
        fill_stroke(ctx, g, OUT2, ow * 1.4)
        for s in (-1, 1):
            ctx.new_path()
            for k in range(3):
                ctx.new_sub_path(); ctx.arc(s * r * (0.72 + k * 0.05), -r * (0.95 - k * 0.18), r * 0.13, 0, 2 * math.pi)
            ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 1.4); ctx.stroke_preserve(); ctx.set_source_rgba(*hexc('#ECE8F2')); ctx.fill()
        rrect(ctx, -r * 0.82, -r * 1.02, r * 1.64, r * 0.17, r * 0.07); fill_stroke(ctx, hexc('#4A3020'), OUT2, ow)
        for k, s in enumerate((-1, 1)):
            cx_ = s * r * 0.27
            ctx.arc(cx_, -r * 0.95, r * 0.24, 0, 2 * math.pi); fill_stroke(ctx, hexc('#B98A3A'), OUT2, ow * 1.2)
            ctx.arc(cx_, -r * 0.95, r * 0.17, 0, 2 * math.pi)
            g = cairo.LinearGradient(cx_ - r * 0.17, -r * 1.12, cx_ + r * 0.17, -r * 0.78)
            g.add_color_stop_rgba(0, *hexc('#BFF4FF')); g.add_color_stop_rgba(1, *hexc('#2E7A8A'))
            ctx.set_source(g); ctx.fill()
            ctx.move_to(cx_ - r * 0.1, -r * 1.02); ctx.line_to(cx_ - r * 0.02, -r * 1.1)
            ctx.set_source_rgba(1, 1, 1, 0.8); ctx.set_line_width(r * 0.035); ctx.stroke()
            if k == 1:
                ctx.move_to(cx_ + r * 0.05, -r * 1.1); ctx.line_to(cx_ - r * 0.02, -r * 0.97); ctx.line_to(cx_ + r * 0.08, -r * 0.86)
                ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.025); ctx.stroke()
        gx, gy = r * 0.62, -r * 0.62
        ctx.save(); ctx.translate(gx, gy); ctx.rotate(t * 1.5)
        star_path(ctx, 0, 0, r * 0.16, n=8, inner=0.72, rot=0); fill_stroke(ctx, hexc('#9AA0B5'), OUT2, ow * 0.8)
        ctx.arc(0, 0, r * 0.05, 0, 2 * math.pi); ctx.set_source_rgba(*OUT2); ctx.fill(); ctx.restore()
    elif kind == 'nigro':
        if blink:
            _blink(ctx, r, ex1, ex2, ey)
        else:
            button_eye(ctx, ex1, ey, r * 0.22, r, look, cracked=True)
            socket_eye(ctx, ex2, ey, r * 0.16, r, t, hexc('#B06BFF'))
        _p(ctx, [(-r * 0.07, -r * 0.3), (r * 0.07, -r * 0.3), (0, -r * 0.18)]); ctx.set_source_rgba(*hexc('#2A1E30')); ctx.fill()
        ctx.move_to(-r * 0.36, -r * 0.08); ctx.line_to(r * 0.36, -r * 0.08); ctx.set_source_rgba(*THREAD); ctx.set_line_width(r * 0.05); ctx.stroke()
        for k in range(7):
            x = -r * 0.3 + k * r * 0.1
            ctx.move_to(x, -r * 0.16); ctx.line_to(x, r * 0.0)
        ctx.set_line_width(r * 0.035); ctx.stroke()
        ctx.save(); ctx.new_path(); ctx.arc(0, -r * 0.42, r * 0.84, 0, 2 * math.pi); ctx.clip()
        ctx.new_path(); ctx.arc(0, -r * 0.42, r * 0.92, math.radians(185), math.radians(355))
        ctx.set_line_width(r * 0.42); ctx.set_source_rgba(*hexc('#241C30')); ctx.stroke()
        ctx.restore()
        ctx.new_path(); ctx.arc(0, -r * 0.42, r * 0.71, math.radians(190), math.radians(350))
        ctx.set_line_width(r * 0.05); ctx.set_source_rgba(*OUT2); ctx.stroke()
        for k in range(3):
            a = t * 1.8 + k * 2.09
            x, y = math.cos(a) * r * 1.25, -r * 0.4 + math.sin(a) * r * 0.45
            glow(ctx, x, y, r * 0.3, hexc('#B06BFF'), 0.75)
            ctx.arc(x, y, r * 0.06, 0, 2 * math.pi); ctx.set_source_rgba(1, 0.9, 1, 0.95); ctx.fill()


def _blink(ctx, r, ex1, ex2, ey):
    for ex in (ex1, ex2):
        ctx.move_to(ex - r * 0.15, ey); ctx.line_to(ex + r * 0.15, ey)
    ctx.set_line_width(r * 0.07); ctx.set_source_rgba(*THREAD); ctx.stroke()


def _mouth(ctx, r, y0=None):
    y0 = -r * 0.2 if y0 is None else y0
    mpts = bez((-r * 0.36, y0), (0, y0 + r * 0.2), (r * 0.38, y0 - r * 0.03), 9)
    ctx.new_path(); ctx.move_to(*mpts[0])
    for p in mpts[1:]:
        ctx.line_to(*p)
    ctx.set_line_width(r * 0.065); ctx.set_source_rgba(*THREAD); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    stitched(ctx, mpts, r * 0.065, r * 0.032, wa(BONE, 0.85), line=False)


# ---------------------------------------------------------------- cuerpo
def hero_body(ctx, kind, pid, col, r, t, look, blink, lift):
    ow = r * 0.14
    back_parts(ctx, kind, r, t, col)
    legs = [(-0.3, 0.84 - lift[0]), (0.3, 0.84 - lift[1])]
    arms = [(-0.66, 0.36, 0.55), (0.66, 0.36, -0.55)]

    def leg(i):
        def f():
            ctx.new_path(); ellipse(ctx, legs[i][0] * r, legs[i][1] * r, r * 0.2, r * 0.19)
        return f

    def arm(i):
        def f():
            ctx.new_path(); ctx.save(); ctx.translate(arms[i][0] * r, arms[i][1] * r); ctx.rotate(arms[i][2])
            ellipse(ctx, 0, 0, r * 0.17, r * 0.29); ctx.restore()
        return f

    def body():
        ctx.new_path(); blob(ctx, 0, r * 0.4, r * 0.62, r * 0.5, 10 + pid, 0.04)

    def head():
        ctx.new_path(); blob(ctx, 0, -r * 0.42, r * 0.84, r * 0.75, 20 + pid, 0.05)
    for f in (leg(0), leg(1), arm(0), arm(1), body, head):
        f(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
    dark = shade(col, -0.32)
    for i in (0, 1):
        fabric_fill(ctx, leg(i), dark, r * 0.3, cx=legs[i][0] * r, cy=legs[i][1] * r)
        fabric_fill(ctx, arm(i), shade(col, -0.15), r * 0.35, cx=arms[i][0] * r, cy=arms[i][1] * r)
    robe = {'mago': hexc('#5A1E28'), 'nigro': hexc('#2A2236')}.get(kind)
    fabric_fill(ctx, body, robe or col, r * 0.7, cx=0, cy=r * 0.4)
    ctx.save(); body(); ctx.clip()
    if kind == 'mago':
        ctx.rectangle(-r, r * 0.5, 2 * r, r * 0.11); ctx.set_source_rgba(*hexc('#2A1408')); ctx.fill()
        rrect(ctx, -r * 0.1, r * 0.47, r * 0.2, r * 0.17, r * 0.03); fill_stroke(ctx, GOLD, OUT2, r * 0.03)
    if kind == 'nigro':
        for k in range(4):
            ctx.move_to(-r * 0.4 + k * r * 0.27, r * 0.0); ctx.line_to(-r * 0.45 + k * r * 0.27, r * 0.9)
        ctx.set_source_rgba(*wa(hexc('#120E18'), 0.7)); ctx.set_line_width(r * 0.03); ctx.stroke()
    ctx.save(); ctx.translate(-r * 0.36, r * 0.66); ctx.rotate(-0.25)
    rrect(ctx, -r * 0.14, -r * 0.12, r * 0.28, r * 0.24, r * 0.04)
    pc = {'mago': hexc('#3A2A50'), 'trol': hexc('#5A4632'), 'gnomo': hexc('#7A5C2E'), 'nigro': hexc('#4A3B52')}[kind]
    ctx.set_source_rgba(*pc); ctx.fill_preserve(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.035); ctx.stroke()
    rrect(ctx, -r * 0.1, -r * 0.08, r * 0.2, r * 0.16, r * 0.03); ctx.set_dash([r * 0.045, r * 0.03]); ctx.set_line_width(r * 0.022)
    ctx.set_source_rgba(*BONE); ctx.stroke(); ctx.set_dash([])
    ctx.restore(); ctx.restore()
    k = r * 0.12; cy_ = r * 0.56
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for (lw, c) in ((r * 0.12, OUT2), (r * 0.065, BONE)):
        ctx.move_to(-k + r * 0.06, cy_ - k); ctx.line_to(k + r * 0.06, cy_ + k)
        ctx.move_to(-k + r * 0.06, cy_ + k); ctx.line_to(k + r * 0.06, cy_ - k)
        ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()
    # collar: cordel o collar de colmillos
    if kind == 'trol':
        ctx.new_path(); ctx.arc(0, -r * 0.2, r * 0.42, math.radians(25), math.radians(155))
        ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.06); ctx.stroke()
        for kk in range(5):
            a = math.radians(40 + kk * 25); x, y = math.cos(a) * r * 0.42, -r * 0.2 + math.sin(a) * r * 0.42
            ctx.save(); ctx.translate(x, y); ctx.rotate(a - math.pi / 2)
            _p(ctx, [(-r * 0.045, 0), (r * 0.045, 0), (0, r * 0.15)]); fill_stroke(ctx, BONE, OUT2, r * 0.03); ctx.restore()
    elif kind != 'nigro':
        ctx.save(); ctx.translate(0, -r * 0.02)
        rrect(ctx, -r * 0.34, -r * 0.08, r * 0.68, r * 0.16, r * 0.06); fill_stroke(ctx, TWINE, OUT2, ow * 1.3)
        for i in range(6):
            x = -r * 0.3 + i * r * 0.12
            ctx.move_to(x, -r * 0.07); ctx.line_to(x + r * 0.07, r * 0.07)
        ctx.set_source_rgba(*hexc('#5C4428')); ctx.set_line_width(r * 0.025); ctx.stroke()
        ctx.restore()
    fabric_fill(ctx, head, col, r * 0.85, cx=0, cy=-r * 0.42)
    pts = bez((-r * 0.05, -r * 1.14), (r * 0.62, -r * 1.0), (r * 0.8, -r * 0.4), 9)
    stitched(ctx, pts, r * 0.05, r * 0.03, wa(THREAD, 0.85))
    face_front(ctx, kind, r, t, col, look, blink)


def draw_hero(ctx, d, t, st, crown=False, crown_drop=1.0, alpha=1.0):
    kind = getattr(d, 'kind', KINDS[d.pid])
    r = d.r * (0.9 if kind == 'gnomo' else 1.0); x, y = d.x, d.y
    sp = math.hypot(d.vx, d.vy); moving = sp > 25
    blink_inv = st < d.invuln_until and int(t * 16) % 2 == 0
    a_all = alpha * (0.35 if blink_inv else 1.0)
    pop = e_out_back(prog(st, d.spawn_t, d.spawn_t + 0.3)) if d.spawn_t > -5 else 1.0
    if pop <= 0.01:
        return
    if a_all < 1:
        ctx.push_group()
    ellipse(ctx, x, y + d.r * 1.02, d.r * 0.95 * pop, d.r * 0.3 * pop); ctx.set_source_rgba(0, 0, 0, 0.5); ctx.fill()
    if d.marker:
        shape_path(ctx, d.shape, x, y + d.r * 1.55, d.r * 0.2 * pop); fill_stroke(ctx, d.col, OUT2, d.r * 0.16)
    if st < d.sheep_until:
        draw_sheep(ctx, x, y, d.r * 1.05, t, d.col, d.face)
    else:
        if st < d.ring_until:
            g = cairo.RadialGradient(x, y - r * 0.2, r * 0.4, x, y - r * 0.2, r * 2.0)
            g.add_color_stop_rgba(0, *wa(GOLD, 0.55 + 0.2 * math.sin(t * 10))); g.add_color_stop_rgba(1, *wa(GOLD, 0))
            ctx.set_source(g); ctx.arc(x, y - r * 0.2, r * 2.0, 0, 2 * math.pi); ctx.fill()
        ctx.save()
        bob = -abs(math.sin(d.walk * 0.11)) * r * 0.16 if moving else math.sin(t * 4.4 + d.pid * 1.3) * r * 0.025
        ctx.translate(x, y + bob + (d.r - r) * 0.9); ctx.scale(pop, pop)
        stv = clamp(sp / 1300.0, 0, 0.24)
        if stv > 0.01:
            ang = math.atan2(d.vy, d.vx); ctx.rotate(ang); ctx.scale(1 + stv, 1 - stv * 0.55); ctx.rotate(-ang)
        if abs(d.squash) > 0.001:
            ctx.translate(0, r * 0.9); ctx.scale(1 + d.squash, 1 - d.squash); ctx.translate(0, -r * 0.9)
        ctx.rotate((math.sin(d.walk * 0.11) * 0.09 if moving else 0) + d.tilt)
        ctx.scale(1, 1 + 0.025 * math.sin(t * 4.2 + d.pid))
        if d.face < 0:
            ctx.scale(-1, 1)
        lift = math.sin(d.walk * 0.11) if moving else 0
        blink = ((t + d.blink_off) % 3.3) < 0.11
        look = (d.look[0] * d.face, d.look[1])
        hero_body(ctx, kind, d.pid, d.col, r, t, look, blink, (max(0, lift) * 0.18, max(0, -lift) * 0.18))
        if st < d.flash_until:
            ctx.new_path(); blob(ctx, 0, -r * 0.42, r * 0.84, r * 0.75, 20 + d.pid, 0.05)
            blob(ctx, 0, r * 0.4, r * 0.62, r * 0.5, 10 + d.pid, 0.04)
            ctx.set_source_rgba(1, 1, 1, 0.8); ctx.fill()
        if crown:
            if d.face < 0:
                ctx.scale(-1, 1)
            off = -r * 1.6 * (1 - e_out_bounce(crown_drop))
            extra = {'mago': r * 1.35, 'trol': r * 0.3, 'gnomo': r * 0.35, 'nigro': r * 0.55}[kind]
            draw_crown(ctx, 0, -r * 1.28 - extra + off, r * 0.9)
        ctx.restore()
        if st < d.frozen_until:
            draw_ice(ctx, x, y, d.r, t)
        if st < d.stun_until:
            for k2 in range(3):
                a = t * 7 + k2 * 2.09
                star_path(ctx, x + math.cos(a) * r * 0.75, y - r * 1.5 + math.sin(a) * r * 0.22, r * 0.2)
                fill_stroke(ctx, GOLD, OUT2, 2.5)
    if a_all < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(a_all)
