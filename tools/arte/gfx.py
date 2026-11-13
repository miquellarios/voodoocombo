"""Dibujo con Cairo para el tráiler de VoodooCombo: colores, texto, muñecos, doblones, iconos, HUD."""
import cairo, math, colorsys

W, H, FPS = 1920, 1080, 30
DT = 1.0 / FPS
FD, FB, FG = "Lilita One", "Baloo 2", "New Rocker"


# ---------------------------------------------------------------- colores
def hexc(h, a=1.0):
    h = h.lstrip('#')
    return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)


def shade(c, f):
    r, g, b, a = c
    if f >= 0:
        return (r + (1 - r) * f, g + (1 - g) * f, b + (1 - b) * f, a)
    return (r * (1 + f), g * (1 + f), b * (1 + f), a)


def wa(c, a):
    return (c[0], c[1], c[2], a)


BG = hexc('#160E22'); OUTL = hexc('#160E22'); DEEP = hexc('#0B0713')
GOLD = hexc('#FFD23F'); GOLD_HI = hexc('#FFF6C2'); GOLD_DK = hexc('#C9971C'); GOLD_SH = hexc('#7A4A0C')
WHITE = (1, 1, 1, 1); DIM = hexc('#B8A9D1'); FROST = hexc('#7FE7FF')
ORANGE = hexc('#FF9F1C'); PINK = hexc('#FF4FD8'); PURPLE = hexc('#8A5CC7')
PANEL = hexc('#241838'); PANEL_LN = hexc('#3D2B5C'); STITCH = hexc('#4A3170'); VIOLET_SH = hexc('#5A2E8A')
PL = [
    dict(name='BRASA', col=hexc('#D8484F'), shape='circle', hat=None),
    dict(name='COLMILLO', col=hexc('#3C7FD0'), shape='tri', hat='tophat'),
    dict(name='TUERCA', col=hexc('#63A83A'), shape='square', hat='sprout'),
    dict(name='CRIPTA', col=hexc('#D9D0BE'), shape='diamond', hat='horns'),
]
TIER_COL = [GOLD_HI, ORANGE, PINK, None]
ITEMS = ['magnet', 'boots', 'cloak', 'pin', 'frost', 'sheep', 'ring']


# ---------------------------------------------------------------- easing
def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def lerp(a, b, u):
    return a + (b - a) * u


def prog(t, a, b):
    if b <= a:
        return 1.0 if t >= b else 0.0
    return clamp((t - a) / (b - a))


def e_out_cubic(u):
    u = clamp(u); return 1 - (1 - u) ** 3


def e_in_cubic(u):
    u = clamp(u); return u ** 3


def e_in_out(u):
    u = clamp(u); return u * u * (3 - 2 * u)


def e_out_back(u, s=1.9):
    u = clamp(u) - 1
    return u * u * ((s + 1) * u + s) + 1


def e_out_bounce(u):
    u = clamp(u); n, d = 7.5625, 2.75
    if u < 1 / d:
        return n * u * u
    if u < 2 / d:
        u -= 1.5 / d; return n * u * u + 0.75
    if u < 2.5 / d:
        u -= 2.25 / d; return n * u * u + 0.9375
    u -= 2.625 / d; return n * u * u + 0.984375


# ---------------------------------------------------------------- primitivas
def ellipse(ctx, x, y, rx, ry):
    ctx.save(); ctx.translate(x, y); ctx.scale(max(rx, 0.01), max(ry, 0.01))
    ctx.new_sub_path(); ctx.arc(0, 0, 1, 0, 2 * math.pi); ctx.restore()


def rrect(ctx, x, y, w, h, r):
    r = max(0.1, min(r, w / 2, h / 2)); ctx.new_sub_path()
    ctx.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    ctx.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    ctx.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    ctx.arc(x + r, y + r, r, math.pi, 1.5 * math.pi)
    ctx.close_path()


def fill_stroke(ctx, fill, stroke=None, lw=0.0):
    if stroke is not None and lw > 0:
        ctx.set_source_rgba(*stroke); ctx.set_line_width(lw); ctx.set_line_join(cairo.LINE_JOIN_ROUND)
        ctx.stroke_preserve()
    if isinstance(fill, cairo.Pattern):
        ctx.set_source(fill)
    else:
        ctx.set_source_rgba(*fill)
    ctx.fill()


def shape_path(ctx, kind, x, y, r):
    ctx.new_sub_path()
    if kind == 'circle':
        ctx.arc(x, y, r, 0, 2 * math.pi)
    elif kind == 'tri':
        ctx.move_to(x, y - r * 1.1); ctx.line_to(x + r * 1.05, y + r * 0.75); ctx.line_to(x - r * 1.05, y + r * 0.75); ctx.close_path()
    elif kind == 'square':
        ctx.rectangle(x - r * 0.85, y - r * 0.85, r * 1.7, r * 1.7)
    else:
        ctx.move_to(x, y - r * 1.15); ctx.line_to(x + r, y); ctx.line_to(x, y + r * 1.15); ctx.line_to(x - r, y); ctx.close_path()


def star_path(ctx, x, y, r, n=5, inner=0.45, rot=-math.pi / 2):
    ctx.new_sub_path()
    for i in range(n * 2):
        rr = r if i % 2 == 0 else r * inner
        a = rot + i * math.pi / n
        (ctx.move_to if i == 0 else ctx.line_to)(x + math.cos(a) * rr, y + math.sin(a) * rr)
    ctx.close_path()


# ---------------------------------------------------------------- texto
def gold_grad(x, y, w, h):
    g = cairo.LinearGradient(0, y, 0, y + h)
    g.add_color_stop_rgba(0, *GOLD_HI); g.add_color_stop_rgba(0.45, *GOLD); g.add_color_stop_rgba(1, *GOLD_DK)
    return g


def bone_grad(x, y, w, h):
    g = cairo.LinearGradient(0, y, 0, y + h)
    for i, c in enumerate(('#F4ECDA', '#D8CBB0', '#A8977A')):
        g.add_color_stop_rgba(i / 2, *hexc(c))
    return g


def oldgold_grad(x, y, w, h):
    g = cairo.LinearGradient(0, y, 0, y + h)
    for i, c in enumerate(('#FFE7A0', '#E0A92E', '#8A5A12')):
        g.add_color_stop_rgba(i / 2, *hexc(c))
    return g


def _tex(size):
    from chars import weave
    return weave(size * 0.3)


def rainbow_grad(t):
    def f(x, y, w, h):
        g = cairo.LinearGradient(x, y, x + w, y)
        for k in range(7):
            r, gg, b = colorsys.hsv_to_rgb((k / 6 * 0.85 + t * 0.6) % 1.0, 0.72, 1.0)
            g.add_color_stop_rgb(k / 6, r, gg, b)
        return g
    return f


def text_size(ctx, s, size, fam=FD, bold=False):
    ctx.select_font_face(fam, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(size)
    e = ctx.text_extents(s)
    return e.x_advance, e.height


def draw_text(ctx, s, x, y, size, fam=FD, fill=WHITE, ow=0.0, oc=OUTL, align='c', sc=1.0, rot=0.0,
              alpha=1.0, shadow=None, bold=False, grad=None, stitch=None):
    if alpha <= 0.003 or sc <= 0.003 or not s:
        return
    ctx.save()
    if alpha < 1:
        ctx.push_group()
    ctx.select_font_face(fam, cairo.FONT_SLANT_NORMAL, cairo.FONT_WEIGHT_BOLD if bold else cairo.FONT_WEIGHT_NORMAL)
    ctx.set_font_size(size)
    xb, yb, tw, th, xa, ya = ctx.text_extents(s)
    ctx.translate(x, y); ctx.rotate(rot); ctx.scale(sc, sc)
    ox = {'c': -xa / 2, 'l': 0, 'r': -xa}[align]
    oy = -(yb + th / 2)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    if shadow:
        sdx, sdy, scol = shadow
        ctx.move_to(ox + sdx, oy + sdy); ctx.text_path(s)
        ctx.set_source_rgba(*scol)
        if ow > 0:
            ctx.set_line_width(ow * 2); ctx.stroke_preserve()
        ctx.fill()
    ctx.move_to(ox, oy); ctx.text_path(s)
    if ow > 0:
        ctx.set_source_rgba(*oc); ctx.set_line_width(ow * 2); ctx.stroke_preserve()
    if grad is not None:
        ctx.set_source(grad(ox, oy + yb, xa, th))
    else:
        ctx.set_source_rgba(*fill)
    ctx.fill()
    if stitch is not None:
        pat, a_tex = stitch
        ctx.new_path(); ctx.move_to(ox, oy); ctx.text_path(s)
        ctx.save(); ctx.clip()
        ctx.set_source(pat); ctx.paint_with_alpha(a_tex)
        g = cairo.LinearGradient(0, oy + yb, 0, oy + yb + th)
        g.add_color_stop_rgba(0, 1, 1, 1, 0.0); g.add_color_stop_rgba(0.5, 1, 1, 1, 0.0); g.add_color_stop_rgba(1, 0, 0, 0, 0.35)
        ctx.set_source(g); ctx.paint()
        ctx.restore(); ctx.new_path()
    if alpha < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(alpha)
    ctx.restore()


# ---------------------------------------------------------------- piezas del mundo
def draw_coin(ctx, x, y, t, phase, r=9.5, height=0.0, alpha=1.0):
    if alpha < 1:
        ctx.push_group()
    sh = clamp(1 - height / 300)
    ellipse(ctx, x, y + r * 0.95, r * 0.85 * sh, r * 0.3 * sh); ctx.set_source_rgba(0, 0, 0, 0.35 * sh); ctx.fill()
    cy = y - height
    c = math.cos(t * 4.2 + phase)
    s = abs(c) * 0.82 + 0.18
    ellipse(ctx, x, cy, r * s, r); fill_stroke(ctx, GOLD_DK, OUTL, r * 0.3)
    ellipse(ctx, x, cy, r * s * 0.76, r * 0.76); ctx.set_source_rgba(*GOLD); ctx.fill()
    ellipse(ctx, x - r * s * 0.22, cy - r * 0.28, r * s * 0.22, r * 0.28); ctx.set_source_rgba(*wa(GOLD_HI, 0.85)); ctx.fill()
    if c > 0.9:
        star_path(ctx, x + r * 0.55, cy - r * 0.7, r * 0.55 * (c - 0.9) * 10, n=4, inner=0.25, rot=0)
        ctx.set_source_rgba(1, 1, 1, 0.9); ctx.fill()
    if alpha < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(alpha)


def draw_chest(ctx, x, y, t, open_u=0.0, sc=1.0, alpha=1.0):
    if alpha <= 0 or sc <= 0:
        return
    ctx.save()
    if alpha < 1:
        ctx.push_group()
    bob = math.sin(t * 3.2) * 2.5 * (1 - open_u)
    ctx.translate(x, y + bob); ctx.scale(sc, sc)
    g = cairo.RadialGradient(0, 0, 4, 0, 0, 46)
    g.add_color_stop_rgba(0, *wa(GOLD, 0.45 + 0.15 * math.sin(t * 5))); g.add_color_stop_rgba(1, *wa(GOLD, 0))
    ctx.set_source(g); ctx.arc(0, 0, 46, 0, 2 * math.pi); ctx.fill()
    ellipse(ctx, 0, 22 - bob, 20, 6); ctx.set_source_rgba(0, 0, 0, 0.35); ctx.fill()
    rrect(ctx, -20, -6, 40, 25, 5); fill_stroke(ctx, hexc('#8E5A33'), OUTL, 6)
    for bx in (-11, 11):
        ctx.rectangle(bx - 2.5, -6, 5, 25); ctx.set_source_rgba(*GOLD); ctx.fill()
    rrect(ctx, -5, 1, 10, 9, 2); fill_stroke(ctx, GOLD, OUTL, 3)
    ctx.save(); ctx.translate(-20, -6); ctx.rotate(-1.9 * e_out_back(open_u)); ctx.translate(20, 6)
    rrect(ctx, -21, -20, 42, 15, 7); fill_stroke(ctx, hexc('#A8703F'), OUTL, 6)
    ctx.rectangle(-13.5, -19, 5, 13); ctx.rectangle(8.5, -19, 5, 13); ctx.set_source_rgba(*GOLD); ctx.fill()
    ctx.restore()
    if open_u > 0.3:
        g2 = cairo.LinearGradient(0, -6, 0, -60)
        g2.add_color_stop_rgba(0, *wa(GOLD_HI, 0.8 * open_u)); g2.add_color_stop_rgba(1, *wa(GOLD, 0))
        ctx.move_to(-16, -6); ctx.line_to(16, -6); ctx.line_to(30, -70); ctx.line_to(-30, -70); ctx.close_path()
        ctx.set_source(g2); ctx.fill()
    if alpha < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(alpha)
    ctx.restore()


def draw_crown(ctx, x, y, w):
    h = w * 0.55
    ctx.new_path()
    ctx.move_to(x - w / 2, y + h * 0.5); ctx.line_to(x - w / 2, y - h * 0.25); ctx.line_to(x - w * 0.25, y + h * 0.05)
    ctx.line_to(x, y - h * 0.5); ctx.line_to(x + w * 0.25, y + h * 0.05); ctx.line_to(x + w / 2, y - h * 0.25)
    ctx.line_to(x + w / 2, y + h * 0.5); ctx.close_path()
    fill_stroke(ctx, GOLD, OUTL, w * 0.13)
    for (gx, col) in ((-w * 0.25, PINK), (0, FROST), (w * 0.25, PINK)):
        ctx.arc(x + gx, y + h * 0.27, w * 0.07, 0, 2 * math.pi); ctx.set_source_rgba(*col); ctx.fill()


def draw_hat(ctx, kind, r):
    ow = r * 0.17
    if kind == 'tophat':
        ellipse(ctx, 0, -r * 1.03, r * 0.6, r * 0.14); fill_stroke(ctx, hexc('#1E1A2B'), OUTL, ow * 1.4)
        ctx.rectangle(-r * 0.36, -r * 1.62, r * 0.72, r * 0.6); fill_stroke(ctx, hexc('#1E1A2B'), OUTL, ow * 1.4)
        ctx.rectangle(-r * 0.36, -r * 1.16, r * 0.72, r * 0.12); ctx.set_source_rgba(*hexc('#FF5A5F')); ctx.fill()
    elif kind == 'sprout':
        ctx.move_to(0, -r * 1.1); ctx.line_to(r * 0.04, -r * 1.45); ctx.set_line_width(r * 0.09)
        ctx.set_source_rgba(*hexc('#2F6B2A')); ctx.stroke()
        for s in (-1, 1):
            ctx.save(); ctx.translate(r * 0.04 + s * r * 0.18, -r * 1.48); ctx.rotate(s * 0.6)
            ellipse(ctx, 0, 0, r * 0.2, r * 0.1); fill_stroke(ctx, hexc('#5FBF4A'), OUTL, ow); ctx.restore()
    elif kind == 'horns':
        for s in (-1, 1):
            ctx.new_path(); ctx.move_to(s * r * 0.38, -r * 0.98)
            ctx.curve_to(s * r * 0.8, -r * 1.2, s * r * 0.75, -r * 1.5, s * r * 0.62, -r * 1.62)
            ctx.curve_to(s * r * 0.55, -r * 1.35, s * r * 0.4, -r * 1.2, s * r * 0.16, -r * 1.08)
            ctx.close_path(); fill_stroke(ctx, hexc('#5A3D7A'), OUTL, ow * 1.4)


def draw_sheep(ctx, x, y, r, t, col, face=1):
    wob = math.sin(t * 9) * r * 0.04
    ellipse(ctx, x, y + r * 0.98, r * 0.95, r * 0.3); ctx.set_source_rgba(0, 0, 0, 0.35); ctx.fill()
    for lx in (-0.45, -0.15, 0.2, 0.5):
        ctx.rectangle(x + lx * r - r * 0.07, y + r * 0.35, r * 0.14, r * 0.55)
        fill_stroke(ctx, hexc('#2A2238'), OUTL, r * 0.08)
    pts = [(math.cos(k * 2 * math.pi / 7) * r * 0.55, math.sin(k * 2 * math.pi / 7) * r * 0.42 - r * 0.05) for k in range(7)]
    ctx.new_path()
    for (px, py) in pts + [(0, -r * 0.05)]:
        ctx.new_sub_path(); ctx.arc(x + px, y + py + wob, r * 0.42, 0, 2 * math.pi)
    ctx.set_source_rgba(*OUTL); ctx.set_line_width(r * 0.24); ctx.stroke_preserve()
    ctx.set_source_rgba(*hexc('#F7F3FF')); ctx.fill()
    hx = x + face * r * 0.72
    ellipse(ctx, hx, y - r * 0.08 + wob, r * 0.32, r * 0.27); fill_stroke(ctx, hexc('#2A2238'), OUTL, r * 0.1)
    for ex in (-0.12, 0.12):
        ctx.arc(hx + ex * r, y - r * 0.14 + wob, r * 0.055, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 1); ctx.fill()
    ctx.arc(x - face * r * 0.1, y + r * 0.4 + wob, r * 0.12, 0, 2 * math.pi); fill_stroke(ctx, col, OUTL, r * 0.08)


def draw_ice(ctx, x, y, r, t):
    rrect(ctx, x - r * 1.1, y - r * 1.35, r * 2.2, r * 2.45, r * 0.32)
    ctx.set_source_rgba(*wa(FROST, 0.32)); ctx.fill_preserve()
    ctx.set_source_rgba(*wa(FROST, 0.95)); ctx.set_line_width(3); ctx.stroke()
    ctx.set_source_rgba(1, 1, 1, 0.6); ctx.set_line_width(2.5)
    ctx.move_to(x - r * 0.8, y - r * 0.6); ctx.line_to(x - r * 0.3, y - r * 1.1)
    ctx.move_to(x - r * 0.75, y - r * 0.2); ctx.line_to(x + r * 0.05, y - r * 1.0); ctx.stroke()
    for (sx, sy, a) in ((-1.2, -1.2, -0.6), (1.15, -0.9, 0.5), (1.0, 0.9, 2.4), (-1.1, 0.8, 3.6)):
        ctx.save(); ctx.translate(x + sx * r, y + sy * r); ctx.rotate(a)
        ctx.move_to(0, -r * 0.3); ctx.line_to(r * 0.12, 0); ctx.line_to(-r * 0.12, 0); ctx.close_path()
        fill_stroke(ctx, FROST, OUTL, 2); ctx.restore()


def draw_doll(ctx, d, t, st, crown=False, crown_drop=1.0, alpha=1.0):
    """d: objeto con x, y, vx, vy, r, col, shape, hat, walk, squash, tilt, look, face, pid, flags de estado."""
    r = d.r
    x, y = d.x, d.y
    sp = math.hypot(d.vx, d.vy)
    moving = sp > 25
    blink_inv = st < d.invuln_until and int(t * 16) % 2 == 0
    a_all = alpha * (0.35 if blink_inv else 1.0)
    pop = e_out_back(prog(st, d.spawn_t, d.spawn_t + 0.3)) if d.spawn_t > -5 else 1.0
    if pop <= 0.01:
        return
    if a_all < 1:
        ctx.push_group()
    # sombra y marcador del jugador
    ellipse(ctx, x, y + r * 0.98, r * 0.9 * pop, r * 0.3 * pop); ctx.set_source_rgba(0, 0, 0, 0.38); ctx.fill()
    if d.marker:
        shape_path(ctx, d.shape, x, y + r * 1.5, r * 0.2 * pop); fill_stroke(ctx, d.col, OUTL, r * 0.16)
    if st < d.sheep_until:
        draw_sheep(ctx, x, y, r * 1.05, t, d.col, d.face)
    else:
        if st < d.ring_until:
            g = cairo.RadialGradient(x, y - r * 0.2, r * 0.4, x, y - r * 0.2, r * 2.0)
            g.add_color_stop_rgba(0, *wa(GOLD, 0.55 + 0.2 * math.sin(t * 10))); g.add_color_stop_rgba(1, *wa(GOLD, 0))
            ctx.set_source(g); ctx.arc(x, y - r * 0.2, r * 2.0, 0, 2 * math.pi); ctx.fill()
            for k in range(4):
                a = t * 3 + k * math.pi / 2
                star_path(ctx, x + math.cos(a) * r * 1.4, y - r * 0.2 + math.sin(a) * r * 0.9, r * 0.16, 4, 0.3, 0)
                ctx.set_source_rgba(*GOLD_HI); ctx.fill()
        ctx.save()
        bob = -abs(math.sin(d.walk * 0.11)) * r * 0.16 if moving else math.sin(t * 4.4 + d.pid * 1.3) * r * 0.025
        ctx.translate(x, y + bob); ctx.scale(pop, pop)
        stv = clamp(sp / 1300.0, 0, 0.24)
        if stv > 0.01:
            ang = math.atan2(d.vy, d.vx); ctx.rotate(ang); ctx.scale(1 + stv, 1 - stv * 0.55); ctx.rotate(-ang)
        if abs(d.squash) > 0.001:
            ctx.translate(0, r * 0.9); ctx.scale(1 + d.squash, 1 - d.squash); ctx.translate(0, -r * 0.9)
        sway = math.sin(d.walk * 0.11) * 0.09 if moving else 0
        ctx.rotate(sway + d.tilt)
        ctx.scale(1, 1 + 0.025 * math.sin(t * 4.2 + d.pid))
        col = d.col; ow = r * 0.17
        lift = math.sin(d.walk * 0.11) if moving else 0
        for i, sx in enumerate((-1, 1)):
            fl = max(0, lift if i == 0 else -lift) * r * 0.2
            ellipse(ctx, sx * r * 0.36, r * 0.8 - fl, r * 0.27, r * 0.18); fill_stroke(ctx, shade(col, -0.35), OUTL, ow * 2)

        def bp():
            ctx.new_path(); ellipse(ctx, 0, r * 0.36, r * 0.74, r * 0.56)
            ctx.new_sub_path(); ctx.arc(0, -r * 0.34, r * 0.8, 0, 2 * math.pi)
        bp(); ctx.set_source_rgba(*OUTL); ctx.set_line_width(ow * 2); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
        g = cairo.LinearGradient(0, -r * 1.15, 0, r * 0.95)
        g.add_color_stop_rgba(0, *shade(col, 0.18)); g.add_color_stop_rgba(0.55, *col); g.add_color_stop_rgba(1, *shade(col, -0.28))
        bp(); ctx.set_source(g); ctx.fill()
        if st < d.flash_until:
            bp(); ctx.set_source_rgba(1, 1, 1, 0.85); ctx.fill()
        ctx.save(); ctx.translate(-r * 0.34, -r * 0.78); ctx.rotate(-0.55); ellipse(ctx, 0, 0, r * 0.24, r * 0.11); ctx.restore()
        ctx.set_source_rgba(1, 1, 1, 0.38); ctx.fill()
        k = r * 0.15
        ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_line_width(r * 0.085); ctx.set_source_rgba(*wa(shade(col, -0.6), 0.9))
        ctx.move_to(-k, r * 0.42 - k); ctx.line_to(k, r * 0.42 + k); ctx.move_to(-k, r * 0.42 + k); ctx.line_to(k, r * 0.42 - k); ctx.stroke()
        blink = ((t + d.blink_off) % 3.3) < 0.11
        lx, ly = d.look
        for sx in (-1, 1):
            ex, ey = sx * r * 0.31 + d.face * r * 0.04, -r * 0.4
            if blink:
                ctx.move_to(ex - r * 0.17, ey); ctx.line_to(ex + r * 0.17, ey); ctx.set_line_width(r * 0.08)
                ctx.set_source_rgba(*OUTL); ctx.stroke(); continue
            ctx.new_path(); ctx.arc(ex, ey, r * 0.22, 0, 2 * math.pi); fill_stroke(ctx, hexc('#1E1430'), OUTL, r * 0.07)
            ctx.arc(ex, ey, r * 0.15, 0, 2 * math.pi); ctx.set_source_rgba(*hexc('#3B2C52')); ctx.set_line_width(r * 0.035); ctx.stroke()
            hx, hy = ex + lx * r * 0.06, ey + ly * r * 0.06
            ctx.set_source_rgba(*hexc('#EDE6FA'))
            for (ax, ay) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                ctx.arc(hx + ax * r * 0.055, hy + ay * r * 0.055, r * 0.036, 0, 2 * math.pi); ctx.fill()
        ctx.new_path(); ctx.move_to(-r * 0.2, -r * 0.05)
        for i in range(1, 6):
            ctx.line_to(-r * 0.2 + i * r * 0.08, -r * 0.05 + (r * 0.05 if i % 2 else 0))
        ctx.set_line_width(r * 0.055); ctx.set_source_rgba(*OUTL); ctx.stroke()
        draw_hat(ctx, d.hat, r)
        if crown:
            off = -r * 1.6 * (1 - e_out_bounce(crown_drop))
            draw_crown(ctx, 0, -r * 1.2 + off - (r * 0.5 if d.hat == 'tophat' else 0), r * 0.95)
        ctx.restore()
        if st < d.frozen_until:
            draw_ice(ctx, x, y, r, t)
        if st < d.stun_until:
            for k2 in range(3):
                a = t * 7 + k2 * 2.09
                star_path(ctx, x + math.cos(a) * r * 0.75, y - r * 1.35 + math.sin(a) * r * 0.22, r * 0.2)
                fill_stroke(ctx, GOLD, OUTL, 2.5)
    if a_all < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(a_all)


# ---------------------------------------------------------------- iconos de hechizo (caja de radio 40)
def draw_icon(ctx, kind, x, y, s):
    ctx.save(); ctx.translate(x, y); ctx.scale(s / 40.0, s / 40.0)
    ctx.set_line_join(cairo.LINE_JOIN_ROUND)
    if kind == 'magnet':
        ctx.new_path(); ctx.move_to(-20, -22); ctx.line_to(-20, 2); ctx.arc_negative(0, 2, 20, math.pi, 0); ctx.line_to(20, -22)
        ctx.set_line_cap(cairo.LINE_CAP_BUTT)
        ctx.set_source_rgba(*OUTL); ctx.set_line_width(26); ctx.stroke_preserve()
        ctx.set_source_rgba(*hexc('#FF4D5E')); ctx.set_line_width(18); ctx.stroke()
        for sx in (-20, 20):
            ctx.rectangle(sx - 9, -22, 18, 11); ctx.set_source_rgba(*hexc('#D9DCE6')); ctx.fill()
    elif kind == 'boots':
        ctx.new_path()
        for i, (px, py) in enumerate([(-16, -26), (6, -26), (6, 4), (26, 9), (28, 24), (-16, 24)]):
            (ctx.move_to if i == 0 else ctx.line_to)(px, py)
        ctx.close_path(); fill_stroke(ctx, hexc('#9A6236'), OUTL, 7)
        ctx.rectangle(-17, 16, 46, 8); ctx.set_source_rgba(*hexc('#4B2E1C')); ctx.fill()
        ctx.rectangle(-17, -27, 24, 8); ctx.set_source_rgba(*hexc('#C88A55')); ctx.fill()
    elif kind == 'cloak':
        ctx.new_path()
        for i, (px, py) in enumerate([(0, -30), (14, -18), (28, 26), (-28, 26), (-14, -18)]):
            (ctx.move_to if i == 0 else ctx.line_to)(px, py)
        ctx.close_path(); fill_stroke(ctx, hexc('#3FAF6A'), OUTL, 7)
        ellipse(ctx, 0, -12, 9, 11); ctx.set_source_rgba(*hexc('#1C4D30')); ctx.fill()
        ctx.arc(0, 2, 4, 0, 2 * math.pi); ctx.set_source_rgba(*GOLD); ctx.fill()
    elif kind == 'pin':
        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        ctx.move_to(-24, 24); ctx.line_to(14, -14); ctx.set_source_rgba(*OUTL); ctx.set_line_width(12); ctx.stroke()
        ctx.move_to(-24, 24); ctx.line_to(14, -14); ctx.set_source_rgba(*hexc('#D9DCE6')); ctx.set_line_width(5); ctx.stroke()
        ctx.arc(18, -18, 12, 0, 2 * math.pi); fill_stroke(ctx, hexc('#FF5A5F'), OUTL, 6)
    elif kind == 'frost':
        ctx.set_line_cap(cairo.LINE_CAP_ROUND)
        for pass_ in (0, 1):
            for k in range(3):
                a = k * math.pi / 3
                ca, sa = math.cos(a), math.sin(a)
                ctx.move_to(-28 * ca, -28 * sa); ctx.line_to(28 * ca, 28 * sa)
                for sgn in (-1, 1):
                    bx, by = 18 * ca * sgn, 18 * sa * sgn
                    for d2 in (-1, 1):
                        b2 = a + d2 * 0.7 + (math.pi if sgn < 0 else 0)
                        ctx.move_to(bx, by); ctx.line_to(bx + 9 * math.cos(b2), by + 9 * math.sin(b2))
            ctx.set_source_rgba(*(OUTL if pass_ == 0 else FROST)); ctx.set_line_width(11 if pass_ == 0 else 5); ctx.stroke()
    elif kind == 'sheep':
        ctx.new_path()
        for k in range(6):
            a = k * math.pi / 3
            ctx.new_sub_path(); ctx.arc(math.cos(a) * 13, math.sin(a) * 10, 11, 0, 2 * math.pi)
        ctx.new_sub_path(); ctx.arc(0, 0, 12, 0, 2 * math.pi)
        ctx.set_source_rgba(*OUTL); ctx.set_line_width(7); ctx.stroke_preserve(); ctx.set_source_rgba(1, 1, 1, 1); ctx.fill()
        ellipse(ctx, 22, 2, 9, 8); fill_stroke(ctx, hexc('#2A2238'), OUTL, 4)
    elif kind == 'ring':
        ctx.arc(0, 6, 19, 0, 2 * math.pi); ctx.set_source_rgba(*OUTL); ctx.set_line_width(15); ctx.stroke()
        ctx.arc(0, 6, 19, 0, 2 * math.pi); ctx.set_source_rgba(*GOLD); ctx.set_line_width(8); ctx.stroke()
        ctx.new_path(); ctx.move_to(0, -30); ctx.line_to(11, -17); ctx.line_to(0, -6); ctx.line_to(-11, -17); ctx.close_path()
        fill_stroke(ctx, FROST, OUTL, 6)
    ctx.restore()


def draw_pin_big(ctx, cx, cy, length, ang, head=26):
    ctx.save(); ctx.translate(cx, cy); ctx.rotate(ang)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.move_to(-length / 2, 0); ctx.line_to(length / 2, 0); ctx.set_source_rgba(*OUTL); ctx.set_line_width(head * 0.62); ctx.stroke()
    g = cairo.LinearGradient(0, -6, 0, 6); g.add_color_stop_rgba(0, *hexc('#EEF0F7')); g.add_color_stop_rgba(1, *hexc('#8F95AB'))
    ctx.move_to(-length / 2, 0); ctx.line_to(length / 2, 0); ctx.set_source(g); ctx.set_line_width(head * 0.33); ctx.stroke()
    ctx.arc(length / 2 + head * 0.55, 0, head, 0, 2 * math.pi)
    hg = cairo.RadialGradient(length / 2 + head * 0.25, -head * 0.4, 3, length / 2 + head * 0.55, 0, head)
    hg.add_color_stop_rgba(0, *hexc('#FFB3B5')); hg.add_color_stop_rgba(1, *hexc('#FF5A5F'))
    fill_stroke(ctx, hg, OUTL, head * 0.36)
    ctx.restore()


# ---------------------------------------------------------------- logo
def draw_logo(ctx, cx, cy, t, t0, sc=1.0, alpha=1.0, shake=(0, 0)):
    if alpha <= 0:
        return
    ctx.save()
    if alpha < 1:
        ctx.push_group()
    ctx.translate(cx + shake[0], cy + shake[1]); ctx.scale(sc, sc)
    s1, size1 = "VOODOO", 190
    ctx.select_font_face(FG); ctx.set_font_size(size1)
    adv = [ctx.text_extents(ch).x_advance for ch in s1]
    x = -sum(adv) / 2
    for i, ch in enumerate(s1):
        ti = t0 + i * 0.07; u = prog(t, ti, ti + 0.4)
        if u > 0:
            draw_text(ctx, ch, x + adv[i] / 2, -105 - 420 * (1 - e_out_bounce(u)), size1, fam=FG, ow=10, oc=hexc('#0B0710'),
                      shadow=(0, 12, hexc('#5C1018')), alpha=min(1, u * 4), grad=bone_grad, stitch=(_tex(size1), 0.55))
        x += adv[i]
    tc = t0 + 0.75; u2 = prog(t, tc, tc + 0.28)
    if u2 > 0:
        draw_text(ctx, "COMBO", 0, 95, 250, fam=FG, grad=oldgold_grad, ow=11, oc=hexc('#0B0710'), shadow=(0, 14, hexc('#3A1A06')),
                  sc=lerp(2.4, 1.0, e_out_back(u2)), alpha=min(1, u2 * 3), stitch=(_tex(250), 0.5))
    tp = t0 + 1.25; u3 = prog(t, tp, tp + 0.18)
    if u3 > 0:
        ctx.select_font_face(FG); ctx.set_font_size(250)
        w2 = ctx.text_extents("COMBO").x_advance; wo = ctx.text_extents("O").x_advance
        ox, oy = w2 / 2 - wo / 2, 95
        o = (1 - e_out_cubic(u3)) * 360
        draw_pin_big(ctx, ox + o, oy - o, 300, -math.pi / 4)
    if alpha < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(alpha)
    ctx.restore()


# ---------------------------------------------------------------- pantalla
def vignette(ctx, strength=0.5):
    g = cairo.RadialGradient(W / 2, H / 2, H * 0.35, W / 2, H / 2, H * 0.98)
    g.add_color_stop_rgba(0, 0, 0, 0, 0); g.add_color_stop_rgba(1, 0, 0, 0, strength)
    ctx.set_source(g); ctx.paint()


def flash(ctx, a, col=WHITE):
    if a > 0.003:
        ctx.set_source_rgba(*wa(col, a)); ctx.paint()


def frenzy_border(ctx, t, a=1.0):
    pulse = 0.5 + 0.5 * math.sin(t * 9)
    for i in range(5):
        rrect(ctx, 6 + i * 7, 6 + i * 7, W - 12 - i * 14, H - 12 - i * 14, 34)
        ctx.set_line_width(12 - i * 2); ctx.set_source_rgba(*wa(GOLD, a * (0.9 - i * 0.17) * (0.55 + 0.45 * pulse))); ctx.stroke()


def rays(ctx, x, y, t, a=1.0, n=16, col=GOLD):
    for i in range(n):
        ang = i * 2 * math.pi / n + t * 0.7
        ctx.move_to(x, y)
        ctx.line_to(x + math.cos(ang - 0.08) * 1600, y + math.sin(ang - 0.08) * 1600)
        ctx.line_to(x + math.cos(ang + 0.08) * 1600, y + math.sin(ang + 0.08) * 1600)
        ctx.close_path()
    g = cairo.RadialGradient(x, y, 20, x, y, 1100)
    g.add_color_stop_rgba(0, *wa(col, 0.45 * a)); g.add_color_stop_rgba(1, *wa(col, 0))
    ctx.set_source(g); ctx.fill()


def kword(ctx, s, t, t0, t1, x=1830, y=975, size=150, shcol=GOLD_SH, align='r'):
    if t < t0 or t > t1:
        return
    u = prog(t, t0, t0 + 0.22); sc = lerp(1.9, 1.0, e_out_back(u)); a = clamp(u * 4)
    e = prog(t, t1 - 0.2, t1); a *= 1 - e
    draw_text(ctx, s, x + e_in_cubic(e) * 140, y, size, fam=FG, ow=10, oc=hexc('#0B0710'), shadow=(10, 10, shcol), align=align, sc=sc, rot=-0.045, alpha=a,
              grad=bone_grad)


def label(ctx, title, sub, t, t0, col):
    u = prog(t, t0, t0 + 0.2)
    if u <= 0:
        return
    draw_text(ctx, title, W / 2, 140, 96, fam=FG, ow=9, oc=hexc('#0B0710'), shadow=(0, 10, col), sc=lerp(1.5, 1, e_out_back(u)), alpha=clamp(u * 3), grad=bone_grad)
    draw_text(ctx, sub, W / 2, 222, 40, fam=FB, bold=True, fill=DIM, alpha=prog(t, t0 + 0.15, t0 + 0.35))
