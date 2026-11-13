"""Personajes v5: chibi simple que mezcla muñeco vudú (cabeza de tela cosida) y personaje de fantasía (cuerpo y clase)."""
import cairo, math
from gfx import *
from chars import OUT2, THREAD, BONE, weave, bez, stitched, button_eye, socket_eye
from humans import ofill, vgrad, glow, staff, mini_voodoo, path_pts

KINDS = ['maga', 'trol', 'gnoma', 'brujo']
HERO_NAME = {'maga': 'BRASA', 'trol': 'COLMILLO', 'gnoma': 'TUERCA', 'brujo': 'CRIPTA'}
HERO_ROLE = {'maga': 'Maga del fuego', 'trol': 'Trol chamán', 'gnoma': 'Gnoma inventora', 'brujo': 'Brujo de las almas'}
PCOL5 = [hexc('#D9434B'), hexc('#3A7BD5'), hexc('#5BAA34'), hexc('#DCD3BE')]
HEAD_Y, HEAD_R = -0.62, 0.56


def flat(ctx, path, col, ow, light=0.12, dark=-0.32, y0=-1.0, y1=1.0, r=1.0):
    ofill(ctx, path, vgrad(y0 * r, y1 * r, shade(col, light), shade(col, dark)), ow)


def head_shape(ctx, r):
    ctx.new_path()
    cy = HEAD_Y * r; R = HEAD_R * r
    ctx.move_to(-R, cy)
    ctx.curve_to(-R, cy - R * 1.05, R, cy - R * 1.05, R, cy)
    ctx.curve_to(R, cy + R * 0.82, -R, cy + R * 0.82, -R, cy)
    ctx.close_path()


def body(ctx, r, col, ow, lift, robe_len=0.78, wide=0.42):
    dark = shade(col, -0.25)
    for i, s in enumerate((-1, 1)):
        ly = lift[i] * r
        ellipse(ctx, s * 0.17 * r, 0.9 * r - ly, 0.15 * r, 0.09 * r); fill_stroke(ctx, hexc('#2A1E26'), OUT2, ow * 2)
    def robe():
        ctx.new_path(); ctx.move_to(-0.26 * r, -0.12 * r)
        ctx.curve_to(-0.34 * r, 0.2 * r, -wide * r, 0.5 * r, -wide * r, robe_len * r)
        ctx.curve_to(-0.15 * r, (robe_len + 0.06) * r, 0.15 * r, (robe_len + 0.06) * r, wide * r, robe_len * r)
        ctx.curve_to(wide * r, 0.5 * r, 0.34 * r, 0.2 * r, 0.26 * r, -0.12 * r); ctx.close_path()
    flat(ctx, robe, dark, ow, y0=-0.12, y1=0.85, r=r)
    k = 0.09 * r; cy = 0.35 * r
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for (lw, c) in ((0.1 * r, OUT2), (0.05 * r, BONE)):
        ctx.move_to(-k, cy - k); ctx.line_to(k, cy + k); ctx.move_to(-k, cy + k); ctx.line_to(k, cy - k)
        ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()
    for s in (-1, 1):
        def arm(s=s):
            path_pts(ctx, [(s * 0.22 * r, -0.08 * r), (s * 0.36 * r, -0.04 * r), (s * 0.5 * r, 0.3 * r), (s * 0.34 * r, 0.33 * r), (s * 0.24 * r, 0.1 * r)])
        flat(ctx, arm, dark, ow, y0=-0.1, y1=0.35, r=r)
        ctx.arc(s * 0.43 * r, 0.36 * r, 0.085 * r, 0, 2 * math.pi); fill_stroke(ctx, col, OUT2, ow * 2)
        ctx.move_to(s * 0.43 * r - 0.04 * r, 0.33 * r); ctx.line_to(s * 0.43 * r + 0.04 * r, 0.39 * r)
        ctx.set_source_rgba(*wa(THREAD, 0.7)); ctx.set_line_width(0.02 * r); ctx.stroke()


def head(ctx, r, col, ow, t):
    flat(ctx, lambda: head_shape(ctx, r), col, ow, light=0.18, dark=-0.25, y0=-1.2, y1=-0.15, r=r)
    ctx.save(); head_shape(ctx, r); ctx.clip(); ctx.set_source(weave(r * 0.9)); ctx.paint_with_alpha(0.28)
    ctx.translate(-0.06 * r, 0.04 * r); head_shape(ctx, r); ctx.set_source_rgba(1, 1, 1, 0.18); ctx.set_line_width(0.08 * r); ctx.stroke()
    ctx.restore()
    pts = bez((0.05 * r, -1.17 * r), (0.45 * r, -1.05 * r), (0.52 * r, -0.7 * r), 7)
    stitched(ctx, pts, 0.04 * r, 0.022 * r, wa(THREAD, 0.8))


def mouth(ctx, r, y=-0.38, w=0.24):
    pts = bez((-w * r, y * r), (0, (y + 0.1) * r), (w * r, (y - 0.02) * r), 6)
    ctx.new_path(); ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    ctx.set_line_width(0.045 * r); ctx.set_source_rgba(*THREAD); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    stitched(ctx, pts, 0.045 * r, 0.022 * r, wa(BONE, 0.8), line=False)


def blink_eyes(ctx, r, xs, y):
    for x in xs:
        ctx.move_to(x - 0.1 * r, y); ctx.line_to(x + 0.1 * r, y)
    ctx.set_line_width(0.05 * r); ctx.set_source_rgba(*THREAD); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()


def ember_eye(ctx, r, x, y, t, col):
    glow(ctx, x, y, 0.22 * r, col, 0.8 + 0.2 * math.sin(t * 9))
    ellipse(ctx, x, y, 0.08 * r, 0.1 * r); fill_stroke(ctx, shade(col, 0.5), OUT2, 0.03 * r)
    ellipse(ctx, x, y, 0.035 * r, 0.05 * r); ctx.set_source_rgba(1, 1, 1, 1); ctx.fill()


# ---------------------------------------------------------------- clases
def draw_maga(ctx, r, t, col, look, blink, lift):
    ow = 0.065 * r
    staff(ctx, r, 0.56 * r, -0.95, 0.95)
    f = 0.8 + 0.2 * math.sin(t * 13) * math.sin(t * 7.3)
    glow(ctx, 0.58 * r, -1.08 * r, 0.5 * r, hexc('#FF7A2A'), 0.75 * f)
    ctx.new_path(); ctx.move_to(0.58 * r, -1.36 * r - 0.04 * r * math.sin(t * 11))
    ctx.curve_to(0.71 * r, -1.16 * r, 0.69 * r, -0.98 * r, 0.58 * r, -0.96 * r)
    ctx.curve_to(0.47 * r, -0.98 * r, 0.45 * r, -1.16 * r, 0.58 * r, -1.36 * r - 0.04 * r * math.sin(t * 11))
    fill_stroke(ctx, hexc('#FFB347'), OUT2, ow)
    body(ctx, r, col, ow, lift)
    rrect(ctx, -0.3 * r, 0.14 * r, 0.6 * r, 0.08 * r, 0.03 * r); fill_stroke(ctx, hexc('#2A1408'), OUT2, ow)
    head(ctx, r, col, ow, t)
    if blink:
        blink_eyes(ctx, r, (-0.2 * r, 0.2 * r), -0.66 * r)
    else:
        button_eye(ctx, -0.2 * r, -0.66 * r, 0.14 * r, r, look)
        ember_eye(ctx, r, 0.21 * r, -0.66 * r, t, hexc('#FF8A2A'))
    mouth(ctx, r)
    def hat():
        ctx.new_path(); ctx.move_to(-0.42 * r, -1.0 * r)
        ctx.curve_to(-0.25 * r, -1.4 * r, 0.0, -1.75 * r, 0.1 * r, -1.98 * r)
        ctx.curve_to(0.28 * r, -2.02 * r, 0.46 * r, -1.9 * r, 0.52 * r, -1.78 * r)
        ctx.curve_to(0.32 * r, -1.8 * r, 0.25 * r, -1.55 * r, 0.42 * r, -1.0 * r); ctx.close_path()
    hc = hexc('#2C1D44')
    flat(ctx, hat, hc, ow, light=0.2, dark=-0.2, y0=-2.0, y1=-1.0, r=r)
    star_path(ctx, -0.02 * r, -1.4 * r, 0.07 * r); fill_stroke(ctx, GOLD, OUT2, ow * 0.6)
    rrect(ctx, -0.42 * r, -1.1 * r, 0.84 * r, 0.1 * r, 0.03 * r); fill_stroke(ctx, col, OUT2, ow)
    ofill(ctx, lambda: (ctx.new_path(), ellipse(ctx, 0, -0.98 * r, 0.7 * r, 0.13 * r)), vgrad(-1.1 * r, -0.85 * r, shade(hc, 0.25), hc), ow)


def draw_trol(ctx, r, t, col, look, blink, lift):
    ow = 0.065 * r
    for s in (-1, 1):
        def ear(s=s):
            path_pts(ctx, [(s * 0.42 * r, -0.78 * r), (s * 1.02 * r, -1.0 * r), (s * 0.9 * r, -0.86 * r), (s * 0.94 * r, -0.78 * r), (s * 0.45 * r, -0.52 * r)])
        flat(ctx, ear, col, ow, light=0.15, dark=-0.25, y0=-1.0, y1=-0.5, r=r)
    body(ctx, r, col, ow, lift, robe_len=0.62, wide=0.38)
    ctx.new_path(); ctx.arc(0, -0.12 * r, 0.22 * r, math.radians(20), math.radians(160)); ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.035 * r); ctx.stroke()
    for kk in range(4):
        a = math.radians(40 + kk * 33); x, y = math.cos(a) * 0.22 * r, -0.12 * r + math.sin(a) * 0.22 * r
        ctx.save(); ctx.translate(x, y); ctx.rotate(a - math.pi / 2)
        path_pts(ctx, [(-0.03 * r, 0), (0.03 * r, 0), (0, 0.09 * r)]); fill_stroke(ctx, BONE, OUT2, ow * 0.6); ctx.restore()
    head(ctx, r, col, ow, t)
    ctx.new_path()
    for k in range(5):
        a = math.radians(-150 + k * 30)
        ctx.move_to(math.cos(a) * 0.2 * r, -1.08 * r + math.sin(a) * 0.05 * r)
        ctx.line_to(math.cos(a) * 0.36 * r, -1.08 * r + math.sin(a) * 0.32 * r)
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.13 * r); ctx.stroke_preserve()
    ctx.set_source_rgba(*hexc('#ECE6DA')); ctx.set_line_width(0.07 * r); ctx.stroke()
    if blink:
        blink_eyes(ctx, r, (-0.2 * r, 0.2 * r), -0.7 * r)
    else:
        button_eye(ctx, -0.2 * r, -0.7 * r, 0.12 * r, r, look, col=hexc('#2A2018'))
        button_eye(ctx, 0.2 * r, -0.69 * r, 0.14 * r, r, look)
    mouth(ctx, r, y=-0.4, w=0.26)
    for s in (-1, 1):
        ofill(ctx, lambda s=s: path_pts(ctx, [(s * 0.14 * r, -0.36 * r), (s * 0.22 * r, -0.58 * r), (s * 0.24 * r, -0.36 * r)]),
              vgrad(-0.58 * r, -0.36 * r, hexc('#FFF6E4'), hexc('#C2B394')), ow * 0.8)


def draw_gnoma(ctx, r, t, col, look, blink, lift):
    ow = 0.065 * r
    ctx.save(); ctx.translate(-0.42 * r, -0.12 * r); ctx.rotate(t * 1.2)
    star_path(ctx, 0, 0, 0.16 * r, n=8, inner=0.72, rot=0); fill_stroke(ctx, hexc('#B98A3A'), OUT2, ow * 1.4)
    ctx.arc(0, 0, 0.045 * r, 0, 2 * math.pi); ctx.set_source_rgba(*OUT2); ctx.fill(); ctx.restore()
    body(ctx, r, col, ow, lift, robe_len=0.72, wide=0.4)
    for s in (-1, 1):
        ctx.move_to(s * 0.16 * r, -0.1 * r); ctx.line_to(s * 0.18 * r, 0.25 * r); ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.07 * r); ctx.stroke()
        ctx.move_to(s * 0.16 * r, -0.1 * r); ctx.line_to(s * 0.18 * r, 0.25 * r); ctx.set_source_rgba(*hexc('#E8DCC4')); ctx.set_line_width(0.035 * r); ctx.stroke()
    head(ctx, r, col, ow, t)
    def beard():
        ctx.new_path()
        for (bx, by, br) in ((-0.3, -0.4, 0.15), (-0.12, -0.32, 0.17), (0.1, -0.32, 0.17), (0.3, -0.4, 0.15), (-0.18, -0.18, 0.15), (0.0, -0.12, 0.17), (0.18, -0.18, 0.15)):
            ctx.new_sub_path(); ctx.arc(bx * r, by * r, br * r, 0, 2 * math.pi)
    ofill(ctx, beard, vgrad(-0.5 * r, 0.05 * r, hexc('#FFFFFF'), hexc('#BDB8CB')), ow * 0.8)
    ctx.arc(0, -0.5 * r, 0.1 * r, 0, 2 * math.pi); fill_stroke(ctx, hexc('#E2565E'), OUT2, ow * 1.2)
    ctx.arc(-0.03 * r, -0.53 * r, 0.03 * r, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.7); ctx.fill()
    if blink:
        blink_eyes(ctx, r, (-0.18 * r, 0.18 * r), -0.68 * r)
    else:
        button_eye(ctx, -0.18 * r, -0.68 * r, 0.1 * r, r, look, col=hexc('#2A1A12'))
        button_eye(ctx, 0.18 * r, -0.68 * r, 0.1 * r, r, look, col=hexc('#2A1A12'))
    rrect(ctx, -0.55 * r, -0.98 * r, 1.1 * r, 0.09 * r, 0.04 * r); fill_stroke(ctx, hexc('#4A3020'), OUT2, ow)
    for k, s in enumerate((-1, 1)):
        cx_ = s * 0.2 * r
        ctx.arc(cx_, -0.94 * r, 0.15 * r, 0, 2 * math.pi); fill_stroke(ctx, hexc('#C89640'), OUT2, ow * 1.3)
        ctx.arc(cx_, -0.94 * r, 0.1 * r, 0, 2 * math.pi)
        g = cairo.LinearGradient(cx_ - 0.1 * r, -1.04 * r, cx_ + 0.1 * r, -0.84 * r)
        g.add_color_stop_rgba(0, *hexc('#BFF4FF')); g.add_color_stop_rgba(1, *hexc('#2E7A8A')); ctx.set_source(g); ctx.fill()
        ctx.move_to(cx_ - 0.06 * r, -0.98 * r); ctx.line_to(cx_ - 0.02 * r, -1.02 * r); ctx.set_source_rgba(1, 1, 1, 0.85); ctx.set_line_width(0.025 * r); ctx.stroke()
        if k == 1:
            ctx.move_to(cx_ + 0.04 * r, -1.03 * r); ctx.line_to(cx_ - 0.01 * r, -0.94 * r); ctx.line_to(cx_ + 0.05 * r, -0.86 * r)
            ctx.set_source_rgba(*OUT2); ctx.set_line_width(0.018 * r); ctx.stroke()
    ctx.new_path(); ctx.arc(0, -1.2 * r, 0.13 * r, 0, 2 * math.pi)
    ofill(ctx, lambda: (ctx.new_path(), ctx.arc(0, -1.2 * r, 0.13 * r, 0, 2 * math.pi)), vgrad(-1.33 * r, -1.07 * r, hexc('#F08A3E'), hexc('#B4501E')), ow)


def draw_brujo(ctx, r, t, col, look, blink, lift):
    ow = 0.065 * r
    hood = hexc('#2A1F38')
    def hood_back():
        ctx.new_path(); ctx.move_to(0, -1.42 * r)
        ctx.curve_to(0.6 * r, -1.35 * r, 0.78 * r, -0.8 * r, 0.62 * r, -0.2 * r)
        ctx.line_to(-0.62 * r, -0.2 * r); ctx.curve_to(-0.78 * r, -0.8 * r, -0.6 * r, -1.35 * r, 0, -1.42 * r); ctx.close_path()
    flat(ctx, hood_back, hood, ow, light=0.2, dark=-0.3, y0=-1.4, y1=-0.2, r=r)
    body(ctx, r, col, ow, lift, robe_len=0.82, wide=0.46)
    head(ctx, r, col, ow, t)
    ctx.save(); head_shape(ctx, r); ctx.clip()
    ctx.set_source(vgrad(-1.2 * r, -0.5 * r, (0.05, 0.03, 0.08, 0.75), (0.05, 0.03, 0.08, 0.0))); ctx.paint(); ctx.restore()
    if blink:
        blink_eyes(ctx, r, (-0.2 * r, 0.2 * r), -0.66 * r)
    else:
        button_eye(ctx, -0.2 * r, -0.66 * r, 0.13 * r, r, look, cracked=True)
        socket_eye(ctx, 0.2 * r, -0.66 * r, 0.1 * r, r, t, hexc('#B06BFF'))
    mouth(ctx, r)
    ctx.new_path(); ctx.move_to(0, -1.42 * r)
    ctx.curve_to(0.6 * r, -1.35 * r, 0.76 * r, -0.8 * r, 0.6 * r, -0.3 * r)
    ctx.curve_to(0.56 * r, -0.75 * r, 0.42 * r, -1.12 * r, 0, -1.14 * r)
    ctx.curve_to(-0.42 * r, -1.12 * r, -0.56 * r, -0.75 * r, -0.6 * r, -0.3 * r)
    ctx.curve_to(-0.76 * r, -0.8 * r, -0.6 * r, -1.35 * r, 0, -1.42 * r); ctx.close_path()
    fill_stroke(ctx, vgrad(-1.42 * r, -0.3 * r, shade(hood, 0.3), hood), OUT2, ow * 2)
    mini_voodoo(ctx, 0.5 * r, 0.26 * r, 0.12 * r, -0.2)
    f = 0.8 + 0.2 * math.sin(t * 11)
    glow(ctx, -0.48 * r, 0.2 * r, 0.38 * r, hexc('#B06BFF'), 0.8 * f)
    ctx.new_path(); ctx.move_to(-0.48 * r, -0.02 * r - 0.03 * r * math.sin(t * 9))
    ctx.curve_to(-0.38 * r, 0.1 * r, -0.39 * r, 0.26 * r, -0.48 * r, 0.28 * r)
    ctx.curve_to(-0.57 * r, 0.26 * r, -0.58 * r, 0.1 * r, -0.48 * r, -0.02 * r - 0.03 * r * math.sin(t * 9))
    fill_stroke(ctx, hexc('#D9A8FF'), OUT2, ow)


DRAW = {'maga': draw_maga, 'trol': draw_trol, 'gnoma': draw_gnoma, 'brujo': draw_brujo}
CROWN_Y = {'maga': -2.22, 'trol': -1.55, 'gnoma': -1.55, 'brujo': -1.65}


def draw_chibi(ctx, d, t, st, crown=False, crown_drop=1.0, alpha=1.0):
    kind = getattr(d, 'kind', KINDS[d.pid])
    r = d.r * (0.9 if kind == 'gnoma' else 1.0); x, y = d.x, d.y
    sp = math.hypot(d.vx, d.vy); moving = sp > 25
    blink_inv = st < d.invuln_until and int(t * 16) % 2 == 0
    a_all = alpha * (0.35 if blink_inv else 1.0)
    pop = e_out_back(prog(st, d.spawn_t, d.spawn_t + 0.3)) if d.spawn_t > -5 else 1.0
    if pop <= 0.01:
        return
    if a_all < 1:
        ctx.push_group()
    ellipse(ctx, x, y + d.r * 0.98, d.r * 0.72 * pop, d.r * 0.22 * pop); ctx.set_source_rgba(0, 0, 0, 0.5); ctx.fill()
    if d.marker:
        shape_path(ctx, d.shape, x, y + d.r * 1.38, d.r * 0.2 * pop); fill_stroke(ctx, d.col, OUT2, d.r * 0.16)
    if st < d.sheep_until:
        draw_sheep(ctx, x, y, d.r * 1.05, t, d.col, d.face)
    else:
        if st < d.ring_until:
            g = cairo.RadialGradient(x, y - r * 0.4, r * 0.4, x, y - r * 0.4, r * 2.0)
            g.add_color_stop_rgba(0, *wa(GOLD, 0.55 + 0.2 * math.sin(t * 10))); g.add_color_stop_rgba(1, *wa(GOLD, 0))
            ctx.set_source(g); ctx.arc(x, y - r * 0.4, r * 2.0, 0, 2 * math.pi); ctx.fill()
        ctx.save()
        bob = -abs(math.sin(d.walk * 0.11)) * r * 0.12 if moving else math.sin(t * 3.8 + d.pid * 1.3) * r * 0.025
        ctx.translate(x, y + bob + (d.r - r) * 0.95); ctx.scale(pop, pop)
        stv = clamp(sp / 1400.0, 0, 0.2)
        if stv > 0.01:
            ang = math.atan2(d.vy, d.vx); ctx.rotate(ang); ctx.scale(1 + stv, 1 - stv * 0.5); ctx.rotate(-ang)
        if abs(d.squash) > 0.001:
            ctx.translate(0, r * 0.95); ctx.scale(1 + d.squash, 1 - d.squash); ctx.translate(0, -r * 0.95)
        ctx.rotate((math.sin(d.walk * 0.11) * 0.07 if moving else 0) + d.tilt)
        if d.face < 0:
            ctx.scale(-1, 1)
        lift = math.sin(d.walk * 0.11) if moving else 0
        blink = ((t + d.blink_off) % 3.3) < 0.11
        look = (d.look[0] * d.face, d.look[1])
        DRAW[kind](ctx, r, t, d.col, look, blink, (max(0, lift) * 0.12, max(0, -lift) * 0.12))
        if st < d.flash_until:
            head_shape(ctx, r); ctx.set_source_rgba(1, 1, 1, 0.8); ctx.fill()
            ctx.new_path(); ellipse(ctx, 0, 0.35 * r, 0.4 * r, 0.45 * r); ctx.fill()
        if crown:
            if d.face < 0:
                ctx.scale(-1, 1)
            off = -r * 1.6 * (1 - e_out_bounce(crown_drop))
            draw_crown(ctx, 0, CROWN_Y[kind] * r + off, r * 0.75)
        ctx.restore()
        if st < d.frozen_until:
            draw_ice(ctx, x, y - r * 0.3, d.r * 1.05, t)
        if st < d.stun_until:
            for k2 in range(3):
                a = t * 7 + k2 * 2.09
                star_path(ctx, x + math.cos(a) * r * 0.6, y - r * 1.6 + math.sin(a) * r * 0.18, r * 0.17)
                fill_stroke(ctx, GOLD, OUT2, 2.5)
    if a_all < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(a_all)
