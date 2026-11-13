"""Muñecos vudú v2: más oscuros y detallados (arpillera, costuras, botones desparejados, alfileres)."""
import cairo, math, random
from gfx import *

OUT2 = hexc('#0B0710')
THREAD = hexc('#1A0F14')
BONE = hexc('#E8DCC4')
TWINE = hexc('#8A6A45')
PCOL = [hexc('#D8484F'), hexc('#3C7FD0'), hexc('#63A83A'), hexc('#D9D0BE')]

_weave = None


def weave(r):
    global _weave
    if _weave is None:
        s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 16, 16); c = cairo.Context(s)
        for i in range(4):
            y = i * 4 + 2
            c.set_source_rgba(1, 1, 1, 0.13 if i % 2 else 0.05); c.rectangle(0, y - 1, 16, 2); c.fill()
            c.set_source_rgba(0, 0, 0, 0.16 if i % 2 == 0 else 0.07); c.rectangle(y - 1, 0, 2, 16); c.fill()
        _weave = cairo.SurfacePattern(s); _weave.set_extend(cairo.EXTEND_REPEAT); _weave.set_filter(cairo.FILTER_GOOD)
    k = 16.0 / max(r * 0.22, 0.5)
    m = cairo.Matrix(xx=k, yy=k); _weave.set_matrix(m)
    return _weave


def blob(ctx, cx, cy, rx, ry, seed, jit=0.05, n=10):
    rng = random.Random(seed)
    pts = []
    for i in range(n):
        a = i * 2 * math.pi / n; k = 1 + rng.uniform(-jit, jit)
        pts.append((cx + math.cos(a) * rx * k, cy + math.sin(a) * ry * k))
    ctx.new_sub_path(); ctx.move_to(*pts[0])
    for i in range(n):
        p0, p1, p2, p3 = pts[(i - 1) % n], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        ctx.curve_to(p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6,
                     p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6, p2[0], p2[1])
    ctx.close_path()


def bez(p0, p1, p2, n):
    out = []
    for i in range(n + 1):
        u = i / n
        out.append(((1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * p1[0] + u * u * p2[0],
                    (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * p1[1] + u * u * p2[1]))
    return out


def stitched(ctx, pts, tick, lw, col=THREAD, line=True, every=1):
    if line:
        ctx.new_path(); ctx.move_to(*pts[0])
        for p in pts[1:]:
            ctx.line_to(*p)
        ctx.set_line_width(lw); ctx.set_source_rgba(*col); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    for i in range(1, len(pts) - 1, every):
        (x0, y0), (x1, y1) = pts[i - 1], pts[i + 1]
        dx, dy = x1 - x0, y1 - y0; L = math.hypot(dx, dy) + 1e-6
        nx, ny = -dy / L, dx / L
        x, y = pts[i]
        ctx.move_to(x - nx * tick + dx / L * tick * 0.25, y - ny * tick + dy / L * tick * 0.25)
        ctx.line_to(x + nx * tick - dx / L * tick * 0.25, y + ny * tick - dy / L * tick * 0.25)
    ctx.set_line_width(lw * 0.85); ctx.set_source_rgba(*col); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()


def fabric_fill(ctx, path_fn, col, r, light=(-0.4, -0.6), cx=0.0, cy=0.0, rad=1.0):
    """Relleno con luz, textura de arpillera, sombra inferior y luz de borde."""
    path_fn()
    g = cairo.RadialGradient(cx + light[0] * r * rad, cy + light[1] * r * rad, r * 0.1 * rad, cx, cy, r * 1.15 * rad)
    g.add_color_stop_rgba(0, *shade(col, 0.22)); g.add_color_stop_rgba(0.55, *col); g.add_color_stop_rgba(1, *shade(col, -0.45))
    ctx.set_source(g); ctx.fill()
    ctx.save(); path_fn(); ctx.clip()
    ctx.set_source(weave(r)); ctx.paint_with_alpha(0.9)
    ctx.arc(cx + r * 0.55 * rad, cy - r * 0.15 * rad, r * 0.95 * rad, -1.3, 0.5)
    ctx.set_line_width(r * 0.12 * rad); ctx.set_source_rgba(*wa(hexc('#B9A6FF'), 0.18)); ctx.stroke()
    ctx.restore()


def pin(ctx, x0, y0, ang, L, head_col, r):
    x1, y1 = x0 + math.cos(ang) * L, y0 + math.sin(ang) * L
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    ctx.move_to(x0, y0); ctx.line_to(x1, y1); ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.09); ctx.stroke()
    ctx.move_to(x0, y0); ctx.line_to(x1, y1); ctx.set_source_rgba(*hexc('#C9CCD8')); ctx.set_line_width(r * 0.04); ctx.stroke()
    ctx.arc(x1, y1, r * 0.11, 0, 2 * math.pi); fill_stroke(ctx, head_col, OUT2, r * 0.05)
    ctx.arc(x1 - r * 0.03, y1 - r * 0.035, r * 0.035, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.7); ctx.fill()


def button_eye(ctx, x, y, rr, r, look, col=hexc('#1E1430'), cracked=False, thread=BONE):
    ctx.arc(x, y + rr * 0.12, rr, 0, 2 * math.pi); ctx.set_source_rgba(0, 0, 0, 0.35); ctx.fill()
    ctx.arc(x, y, rr, 0, 2 * math.pi)
    g = cairo.RadialGradient(x - rr * 0.4, y - rr * 0.4, rr * 0.1, x, y, rr)
    g.add_color_stop_rgba(0, *shade(col, 0.35)); g.add_color_stop_rgba(1, *col)
    fill_stroke(ctx, g, OUT2, r * 0.06)
    ctx.arc(x, y, rr * 0.72, 0, 2 * math.pi); ctx.set_source_rgba(*shade(col, -0.4)); ctx.set_line_width(rr * 0.12); ctx.stroke()
    hx, hy = x + look[0] * rr * 0.18, y + look[1] * rr * 0.18
    hs = rr * 0.25; hr = rr * 0.12
    holes = [(hx - hs, hy - hs), (hx + hs, hy - hs), (hx - hs, hy + hs), (hx + hs, hy + hs)]
    for (a, b) in holes:
        ctx.arc(a, b, hr, 0, 2 * math.pi); ctx.set_source_rgba(*OUT2); ctx.fill()
    ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_line_width(rr * 0.13); ctx.set_source_rgba(*thread)
    ctx.move_to(*holes[0]); ctx.line_to(*holes[3]); ctx.move_to(*holes[1]); ctx.line_to(*holes[2]); ctx.stroke()
    ctx.arc(x - rr * 0.45, y - rr * 0.45, rr * 0.16, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.45); ctx.fill()
    if cracked:
        ctx.move_to(x + rr * 0.1, y - rr); ctx.line_to(x + rr * 0.25, y - rr * 0.4); ctx.line_to(x + rr * 0.05, y)
        ctx.line_to(x + rr * 0.35, y + rr * 0.5); ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.035); ctx.stroke()


def x_eye(ctx, x, y, rr, r, col=THREAD):
    ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_source_rgba(*col); ctx.set_line_width(r * 0.085)
    ctx.move_to(x - rr, y - rr); ctx.line_to(x + rr, y + rr); ctx.move_to(x - rr, y + rr); ctx.line_to(x + rr, y - rr); ctx.stroke()


def closed_eye(ctx, x, y, rr, r):
    pts = bez((x - rr, y - rr * 0.1), (x, y + rr * 0.8), (x + rr, y - rr * 0.1), 6)
    ctx.new_path(); ctx.move_to(*pts[0])
    for p in pts[1:]:
        ctx.line_to(*p)
    ctx.set_source_rgba(*THREAD); ctx.set_line_width(r * 0.07); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    for p in pts[1:-1:2]:
        ctx.move_to(*p); ctx.line_to(p[0], p[1] + rr * 0.45)
    ctx.set_line_width(r * 0.05); ctx.stroke()


def socket_eye(ctx, x, y, rr, r, t, glow):
    ctx.arc(x, y, rr, 0, 2 * math.pi); fill_stroke(ctx, hexc('#120A14'), OUT2, r * 0.05)
    g = cairo.RadialGradient(x, y, 0, x, y, rr * 1.6)
    a = 0.75 + 0.25 * math.sin(t * 5)
    g.add_color_stop_rgba(0, *wa(glow, a)); g.add_color_stop_rgba(0.35, *wa(glow, a * 0.6)); g.add_color_stop_rgba(1, *wa(glow, 0))
    ctx.set_source(g); ctx.arc(x, y, rr * 1.6, 0, 2 * math.pi); ctx.fill()
    ctx.arc(x, y, rr * 0.28, 0, 2 * math.pi); ctx.set_source_rgba(1, 1, 1, 0.9); ctx.fill()


def topper(ctx, pid, r, t):
    ow = r * 0.12
    if pid == 0:   # mechones de lana roja y alfiler de corazón
        rng = random.Random(1)
        for k in range(6):
            a = -math.pi / 2 + (k - 2.5) * 0.22
            x0, y0 = math.cos(a) * r * 0.62, -r * 0.42 + math.sin(a) * r * 0.62
            x1 = x0 + math.cos(a) * r * 0.42 + rng.uniform(-0.1, 0.1) * r; y1 = y0 + math.sin(a) * r * 0.42 - r * 0.05
            for (wcol, wl) in ((OUT2, r * 0.17), (hexc('#8E1F2B'), r * 0.1)):
                ctx.move_to(x0, y0); ctx.curve_to(x0 + r * 0.1, y0 - r * 0.2, x1 - r * 0.2, y1 + r * 0.1, x1, y1)
                ctx.set_line_width(wl); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_source_rgba(*wcol); ctx.stroke()
        pin(ctx, r * 0.55, -r * 0.6, -0.75, r * 0.55, hexc('#FFD23F'), r)
    elif pid == 1:  # chistera raída
        ctx.save(); ctx.translate(r * 0.08, -r * 1.12); ctx.rotate(0.14)
        ctx.new_path(); ctx.move_to(-r * 0.36, 0); ctx.line_to(-r * 0.3, -r * 0.7); ctx.line_to(r * 0.32, -r * 0.74); ctx.line_to(r * 0.38, 0); ctx.close_path()
        g = cairo.LinearGradient(-r * 0.36, 0, r * 0.38, 0); g.add_color_stop_rgba(0, *hexc('#2A2338')); g.add_color_stop_rgba(1, *hexc('#15111E'))
        fill_stroke(ctx, g, OUT2, ow * 2)
        ctx.rectangle(-r * 0.35, -r * 0.2, r * 0.72, r * 0.11); ctx.set_source_rgba(*hexc('#7A1E2A')); ctx.fill()
        rrect(ctx, r * 0.02, -r * 0.6, r * 0.2, r * 0.18, r * 0.03); fill_stroke(ctx, hexc('#4A3B2A'), OUT2, ow)
        ctx.new_path(); ctx.move_to(-r * 0.66, r * 0.02)
        for i in range(1, 12):
            ctx.line_to(-r * 0.66 + i * r * 0.12, r * 0.02 + (r * 0.06 if i % 2 else -r * 0.01))
        ctx.line_to(r * 0.66, -r * 0.08); ctx.line_to(-r * 0.66, -r * 0.08); ctx.close_path()
        fill_stroke(ctx, hexc('#1B1626'), OUT2, ow * 1.6)
        ctx.restore()
        pin(ctx, -r * 0.2, -r * 1.42, -2.3, r * 0.5, hexc('#3DA5FF'), r)
    elif pid == 2:  # seta y musgo
        ctx.save(); ctx.translate(-r * 0.35, -r * 1.02); ctx.rotate(-0.35)
        ctx.rectangle(-r * 0.07, -r * 0.05, r * 0.14, r * 0.3); fill_stroke(ctx, hexc('#D9CDB8'), OUT2, ow)
        ctx.new_path(); ctx.arc(0, 0, r * 0.32, math.pi, 2 * math.pi); ctx.close_path()
        g = cairo.LinearGradient(0, -r * 0.32, 0, 0); g.add_color_stop_rgba(0, *hexc('#B2453A')); g.add_color_stop_rgba(1, *hexc('#6E2420'))
        fill_stroke(ctx, g, OUT2, ow * 1.6)
        for (a, b, s) in ((-0.15, -0.18, 0.06), (0.12, -0.12, 0.05), (0.0, -0.26, 0.04)):
            ctx.arc(a * r, b * r, s * r, 0, 2 * math.pi); ctx.set_source_rgba(*BONE); ctx.fill()
        ctx.restore()
        for (a, b, s) in ((0.3, -1.0, 0.13), (0.45, -0.88, 0.1), (0.15, -1.08, 0.09)):
            ctx.arc(a * r, b * r, s * r, 0, 2 * math.pi); ctx.set_source_rgba(*hexc('#3E6B2A')); ctx.fill()
    elif pid == 3:  # cuernos de hueso
        for s in (-1, 1):
            ctx.new_path(); ctx.move_to(s * r * 0.36, -r * 0.98)
            ctx.curve_to(s * r * 0.85, -r * 1.15, s * r * 0.9, -r * 1.5, s * r * 0.7, -r * 1.75)
            ctx.curve_to(s * r * 0.62, -r * 1.45, s * r * 0.45, -r * 1.25, s * r * 0.12, -r * 1.12)
            ctx.close_path()
            g = cairo.LinearGradient(0, -r * 1.75, 0, -r * 1.0); g.add_color_stop_rgba(0, *hexc('#F2EAD8')); g.add_color_stop_rgba(1, *hexc('#A89878'))
            fill_stroke(ctx, g, OUT2, ow * 1.8)
            for k in range(3):
                yy = -r * (1.2 + k * 0.15); xx = s * r * (0.55 + k * 0.07)
                ctx.move_to(xx - r * 0.08, yy); ctx.line_to(xx + r * 0.08, yy - r * 0.04)
            ctx.set_source_rgba(*wa(hexc('#6B5E48'), 0.8)); ctx.set_line_width(r * 0.035); ctx.stroke()
        pin(ctx, -r * 0.62, -r * 0.55, -2.6, r * 0.45, hexc('#2A1E3A'), r)


def body2(ctx, pid, col, r, t, look, blink, walk_lift):
    ow = r * 0.14
    legs = [(-0.3, 0.84 - walk_lift[0]), (0.3, 0.84 - walk_lift[1])]
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
    parts = [leg(0), leg(1), arm(0), arm(1), body, head]
    for f in parts:
        f(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(ow * 2); ctx.set_line_join(cairo.LINE_JOIN_ROUND); ctx.stroke()
    dark = shade(col, -0.32)
    fabric_fill(ctx, leg(0), dark, r * 0.3, cx=legs[0][0] * r, cy=legs[0][1] * r)
    fabric_fill(ctx, leg(1), dark, r * 0.3, cx=legs[1][0] * r, cy=legs[1][1] * r)
    for i in (0, 1):
        fabric_fill(ctx, arm(i), shade(col, -0.15), r * 0.35, cx=arms[i][0] * r, cy=arms[i][1] * r)
        ex = arms[i][0] * r + math.sin(arms[i][2]) * r * 0.27 * (1 if i == 0 else 1)
        ey = arms[i][1] * r + math.cos(arms[i][2]) * r * 0.27
        for k in (-1, 0, 1):
            ctx.move_to(ex + k * r * 0.05, ey); ctx.line_to(ex + k * r * 0.08, ey + r * 0.1)
        ctx.set_source_rgba(*wa(BONE, 0.6)); ctx.set_line_width(r * 0.025); ctx.stroke()
    fabric_fill(ctx, body, col, r * 0.7, cx=0, cy=r * 0.4)
    ctx.save(); body(); ctx.clip()
    ctx.save(); ctx.translate(-r * 0.3, r * 0.6); ctx.rotate(-0.25)
    rrect(ctx, -r * 0.17, -r * 0.15, r * 0.34, r * 0.3, r * 0.04)
    pc = [hexc('#5A4632'), hexc('#2E3E5C'), hexc('#7A5C2E'), hexc('#4A3B52')][pid]
    ctx.set_source_rgba(*pc); ctx.fill_preserve(); ctx.set_source_rgba(*OUT2); ctx.set_line_width(r * 0.035); ctx.stroke()
    rrect(ctx, -r * 0.13, -r * 0.11, r * 0.26, r * 0.22, r * 0.03); ctx.set_dash([r * 0.05, r * 0.035]); ctx.set_line_width(r * 0.025)
    ctx.set_source_rgba(*BONE); ctx.stroke(); ctx.set_dash([])
    ctx.restore()
    ctx.restore()
    k = r * 0.12; cy_ = r * 0.56
    ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    for (lw, c) in ((r * 0.12, OUT2), (r * 0.065, BONE)):
        ctx.move_to(-k, cy_ - k); ctx.line_to(k, cy_ + k); ctx.move_to(-k, cy_ + k); ctx.line_to(k, cy_ - k)
        ctx.set_line_width(lw); ctx.set_source_rgba(*c); ctx.stroke()
    pts = bez((r * 0.36, r * 0.2), (r * 0.46, r * 0.5), (r * 0.3, r * 0.82), 6)
    stitched(ctx, pts, r * 0.045, r * 0.025, wa(THREAD, 0.7), line=False)
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
    mpts = bez((-r * 0.42, -r * 0.2), (0, r * 0.02), (r * 0.44, -r * 0.24), 10)
    ctx.new_path(); ctx.move_to(*mpts[0])
    for p in mpts[1:]:
        ctx.line_to(*p)
    ctx.set_line_width(r * 0.07); ctx.set_source_rgba(*THREAD); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.stroke()
    stitched(ctx, mpts, r * 0.07, r * 0.035, wa(BONE, 0.85), line=False)
    ex1, ex2, ey = -r * 0.32, r * 0.3, -r * 0.55
    if blink:
        for ex in (ex1, ex2):
            ctx.move_to(ex - r * 0.16, ey); ctx.line_to(ex + r * 0.16, ey)
        ctx.set_line_width(r * 0.07); ctx.set_source_rgba(*THREAD); ctx.stroke()
    elif pid == 0:
        button_eye(ctx, ex1, ey, r * 0.24, r, look); x_eye(ctx, ex2, ey + r * 0.02, r * 0.12, r)
    elif pid == 1:
        button_eye(ctx, ex1, ey + r * 0.02, r * 0.19, r, look, col=hexc('#2A2018'))
        button_eye(ctx, ex2, ey, r * 0.26, r, look, col=hexc('#1E1430'))
    elif pid == 2:
        button_eye(ctx, ex1, ey, r * 0.23, r, look, col=hexc('#2A1A12')); closed_eye(ctx, ex2, ey, r * 0.15, r)
    else:
        button_eye(ctx, ex1, ey, r * 0.23, r, look, cracked=True); socket_eye(ctx, ex2, ey, r * 0.15, r, t, hexc('#B06BFF'))
    topper(ctx, pid, r, t)


def draw_doll2(ctx, d, t, st, crown=False, crown_drop=1.0, alpha=1.0):
    r = d.r; x, y = d.x, d.y
    sp = math.hypot(d.vx, d.vy); moving = sp > 25
    blink_inv = st < d.invuln_until and int(t * 16) % 2 == 0
    a_all = alpha * (0.35 if blink_inv else 1.0)
    pop = e_out_back(prog(st, d.spawn_t, d.spawn_t + 0.3)) if d.spawn_t > -5 else 1.0
    if pop <= 0.01:
        return
    if a_all < 1:
        ctx.push_group()
    ellipse(ctx, x, y + r * 1.02, r * 0.95 * pop, r * 0.3 * pop); ctx.set_source_rgba(0, 0, 0, 0.5); ctx.fill()
    if d.marker:
        shape_path(ctx, d.shape, x, y + r * 1.55, r * 0.2 * pop); fill_stroke(ctx, d.col, OUT2, r * 0.16)
    if st < d.sheep_until:
        draw_sheep(ctx, x, y, r * 1.05, t, d.col, d.face)
    else:
        if st < d.ring_until:
            g = cairo.RadialGradient(x, y - r * 0.2, r * 0.4, x, y - r * 0.2, r * 2.0)
            g.add_color_stop_rgba(0, *wa(GOLD, 0.55 + 0.2 * math.sin(t * 10))); g.add_color_stop_rgba(1, *wa(GOLD, 0))
            ctx.set_source(g); ctx.arc(x, y - r * 0.2, r * 2.0, 0, 2 * math.pi); ctx.fill()
        ctx.save()
        bob = -abs(math.sin(d.walk * 0.11)) * r * 0.16 if moving else math.sin(t * 4.4 + d.pid * 1.3) * r * 0.025
        ctx.translate(x, y + bob); ctx.scale(pop, pop)
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
        body2(ctx, d.pid, d.col, r, t, look, blink, (max(0, lift) * 0.18, max(0, -lift) * 0.18))
        if st < d.flash_until:
            ctx.new_path(); blob(ctx, 0, -r * 0.42, r * 0.84, r * 0.75, 20 + d.pid, 0.05)
            blob(ctx, 0, r * 0.4, r * 0.62, r * 0.5, 10 + d.pid, 0.04)
            ctx.set_source_rgba(1, 1, 1, 0.8); ctx.fill()
        if crown:
            if d.face < 0:
                ctx.scale(-1, 1)
            off = -r * 1.6 * (1 - e_out_bounce(crown_drop))
            extra = {1: r * 0.75, 3: r * 0.45, 2: r * 0.2, 0: r * 0.25}[d.pid]
            draw_crown(ctx, 0, -r * 1.28 - extra + off, r * 0.9)
        ctx.restore()
        if st < d.frozen_until:
            draw_ice(ctx, x, y, r, t)
        if st < d.stun_until:
            for k2 in range(3):
                a = t * 7 + k2 * 2.09
                star_path(ctx, x + math.cos(a) * r * 0.75, y - r * 1.45 + math.sin(a) * r * 0.22, r * 0.2)
                fill_stroke(ctx, GOLD, OUT2, 2.5)
    if a_all < 1:
        ctx.pop_group_to_source(); ctx.paint_with_alpha(a_all)
