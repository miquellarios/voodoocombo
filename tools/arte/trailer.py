#!/usr/bin/env python3
"""VoodooCombo — tráiler conceptual. Uso: python3 trailer.py samples t1 t2 ...  |  python3 trailer.py full"""
import cairo, math, random, subprocess, os, sys
from gfx import *
from world import *
from heroes import draw_hero, HERO_NAME, HERO_ROLE, KINDS
import arenas as AR

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out'); os.makedirs(OUT, exist_ok=True)
TOTAL = 49.5
TL = dict(groove=7.5, lift=30.5, frenzy=34.5, count=39.5, podium=41.5, end=44.5)
w = World()
for _d in w.d:
    _d.r = 27.0

# ---------------------------------------------------------------- caminos de referencia
CORAL_A = [(9.6, 100, 500), (10.6, 300, 540), (11.4, 390, 510), (12.2, 475, 465), (13.0, 540, 420), (13.8, 600, 460),
           (14.6, 660, 500), (15.4, 720, 480), (16.2, 690, 410), (16.5, 670, 400)]
CORAL_S6 = [(20.5, 365, 300), (20.85, 453, 300, 'E'), (22.6, 453, 300, 'L'), (23.0, 495, 345), (23.3, 530, 375),
            (23.6, 565, 400), (24.0, 605, 420)]
CORAL_S8 = [(27.0, 240, 520), (27.65, 300, 520), (29.9, 860, 520), (30.35, 980, 530), (30.8, 1080, 470),
            (31.5, 1110, 390), (32.0, 1112, 372)]
S4_PICKS = [11.0 + 0.4 * k for k in range(13)]
S6_PICKS = [23.0, 23.3, 23.6]
S8_PICKS = [27.75 + 0.145 * i for i in range(22)]
CHESTS = [(345, 300), (855, 300)]
CHESTS_MID = [(480, 300), (720, 300)]   # Cripta y Taller: fuera de pinchos y barriles
SPAWNS = [(100, 500), (1100, 100), (1100, 500), (100, 100)]


def samples_of(keys, t0, t1, step=0.05):
    f = path_fn(keys); n = int((t1 - t0) / step) + 1
    return [f(t0 + i * step) for i in range(n)]


def far_from(x, y, pts, dmin):
    return all((x - px) ** 2 + (y - py) ** 2 >= dmin * dmin for (px, py) in pts)


def enter_arena(aid, seed=1, fill=0, clear=(), avoid=()):
    """Cambia de arena: quita los doblones que caerían en obstáculos o trampas fijas y rellena hasta `fill`."""
    w.set_arena(aid)
    inz = lambda x, y: any((x - cx) ** 2 + (y - cy) ** 2 < r * r for (cx, cy, r) in clear)
    for c in w.coins:
        if c.alive and (not free_spot(c.x, c.y, 16) or inz(c.x, c.y) or not far_from(c.x, c.y, avoid, 40)):
            c.alive = False
    rng = random.Random(seed); tries = 0
    alive = [(c.x, c.y) for c in w.coins if c.alive]
    while len(alive) < fill and tries < 6000:
        tries += 1
        x, y = rng.uniform(30, AW - 30), rng.uniform(30, AH - 30)
        if not free_spot(x, y, 22) or inz(x, y) or not far_from(x, y, alive, 40) or not far_from(x, y, avoid, 46):
            continue
        w.coins.append(Coin(x, y, -9.0, rng=rng)); alive.append((x, y))


def knock(d, drops, src_dy=-8, txt=True):
    """Golpe: destello, aturdido, pierde el combo y suelta doblones en las posiciones `drops`."""
    st = w.st
    d.flash_until = st + 0.12; d.invuln_until = st + 1.3; d.stun_until = st + 0.6; d.combo = 0
    n = len(drops); d.score = max(0, d.score - n)
    for (x, y) in drops:
        w.coins.append(Coin(x, y, st, src=(d.x, d.y + src_dy), flight=0.45, block_pid=d.pid, block_until=st + 0.6,
                            stolen_from=d.pid, rng=w.rng))
    w.sparks(d.x, d.y - 10, 14, WHITE, 380); w.part('ring', d.x, d.y, life=0.35, size=10, col=WHITE, r0=10, r1=80)
    if txt:
        w.text(d.x, d.y - 62, f"-{n}", col=hexc('#FF5A5F'), size=30)
    w.ev('scatter', n)


# ================================================================ escenas
class Scene:
    t0 = t1 = 0
    shift = 0.0   # las escenas antiguas guardan su tiempo de diseño; shift las coloca en la línea de tiempo global

    def setup(self): pass
    def update(self, t): pass
    def draw(self, ctx, t, fi): pass


class S1(Scene):  # ojos de botón en la oscuridad
    t0, t1 = 0.0, 4.0

    def setup(self):
        r = random.Random(3)
        self.dust = [(r.uniform(0, W), r.uniform(0, H), r.uniform(1, 3), r.uniform(-8, 8), r.uniform(-16, -4)) for _ in range(80)]

    def update(self, t):
        for tt, g in ((0.45, 1.0), (0.72, 0.7), (1.75, 1.0), (2.02, 0.7), (3.0, 1.0), (3.27, 0.7)):
            if t >= tt and w.once(('hb', tt)):
                w.ev('heart', g)
        if t >= 2.55 and w.once('blink1'):
            w.ev('blink')
        if t >= 3.1 and w.once('riser1'):
            w.ev('riser', 0.9)

    def draw(self, ctx, t, fi):
        ctx.set_source_rgba(*DEEP); ctx.paint()
        for (x, y, r, vx, vy) in self.dust:
            ctx.arc((x + vx * t) % W, (y + vy * t) % H, r, 0, 2 * math.pi); ctx.set_source_rgba(*wa(DIM, 0.13)); ctx.fill()
        a = prog(t, 0.5, 2.0)
        zoom = 1.0 + 0.03 * t + 6.0 * e_in_cubic(prog(t, 3.5, 4.0))
        ctx.save(); ctx.translate(W / 2, 520); ctx.scale(zoom, zoom)
        g = cairo.RadialGradient(0, 0, 40, 0, 40, 400)
        g.add_color_stop_rgba(0, *wa(hexc('#2A1A40'), a)); g.add_color_stop_rgba(1, *wa(hexc('#120A1C'), a))
        ctx.arc(0, 40, 380, 0, 2 * math.pi); ctx.set_source(g); ctx.fill()
        ctx.arc(0, 40, 360, 0, 2 * math.pi); ctx.set_dash([18, 14]); ctx.set_line_width(5)
        ctx.set_source_rgba(*wa(STITCH, 0.7 * a)); ctx.stroke(); ctx.set_dash([])
        openv = 1.0
        if 2.55 <= t <= 2.72:
            openv = 0.08
        openv *= 1 - 0.95 * prog(t, 3.45, 3.75)
        ea = prog(t, 0.9, 1.6)
        for sx in (-1, 1):
            ctx.save(); ctx.translate(sx * 150, -20); ctx.scale(1, max(openv, 0.05))
            ctx.arc(0, 0, 88, 0, 2 * math.pi); fill_stroke(ctx, wa(hexc('#1E1430'), ea), wa(OUTL, ea), 12)
            ctx.arc(0, 0, 62, 0, 2 * math.pi); ctx.set_line_width(8); ctx.set_source_rgba(*wa(hexc('#3B2C52'), ea)); ctx.stroke()
            for (ax, ay) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
                gg = cairo.RadialGradient(ax * 22, ay * 22, 2, ax * 22, ay * 22, 30)
                gg.add_color_stop_rgba(0, *wa(GOLD, 0.9 * ea)); gg.add_color_stop_rgba(1, *wa(GOLD, 0))
                ctx.set_source(gg); ctx.arc(ax * 22, ay * 22, 30, 0, 2 * math.pi); ctx.fill()
                ctx.arc(ax * 22, ay * 22, 10, 0, 2 * math.pi); ctx.set_source_rgba(*wa(GOLD_HI, ea)); ctx.fill()
            ctx.restore()
        ctx.new_path(); ctx.move_to(-90, 150)
        for i in range(1, 10):
            ctx.line_to(-90 + i * 20, 150 + (14 if i % 2 else 0))
        ctx.set_line_width(9); ctx.set_line_cap(cairo.LINE_CAP_ROUND); ctx.set_source_rgba(*wa(STITCH, 0.8 * a)); ctx.stroke()
        ctx.restore()
        draw_text(ctx, "En una arena maldita…", W / 2, 960, 50, fam=FB, bold=True, fill=DIM,
                  alpha=prog(t, 1.3, 2.0) * (1 - prog(t, 3.2, 3.5)))
        vignette(ctx, 0.7)
        flash(ctx, prog(t, 3.75, 4.0), DEEP)


class S2(Scene):  # logo
    t0, t1 = 4.0, 7.5
    T = 4.15

    def setup(self):
        r = random.Random(5)
        self.coins = [(r.uniform(0, W), r.uniform(0, H), r.uniform(60, 140), r.uniform(10, 24), r.uniform(0, 6)) for _ in range(30)]

    def update(self, t):
        T = self.T
        for i in range(6):
            if t >= T + i * 0.07 + 0.145 and w.once(('tok', i)):
                w.ev('tok')
        if t >= T + 0.83 and w.once('slam'):
            w.ev('impact'); w.shake = 0
            w.sparks(W / 2, 470 + 95, 40, GOLD, 900, sp='s', size=9)
        if t >= T + 1.43 and w.once('tink'):
            w.ev('tink'); w.sparks(W / 2 + 330, 560, 20, WHITE, 520, sp='s', size=7)
        if t >= T + 1.9 and w.once('tag'):
            w.ev('pop')
        if t >= 7.0 and w.once('fill'):
            w.ev('fill')
        w.update(t)

    def draw(self, ctx, t, fi):
        g = cairo.RadialGradient(W / 2, 480, 60, W / 2, 480, 1150)
        g.add_color_stop_rgba(0, *hexc('#4A1022')); g.add_color_stop_rgba(1, *hexc('#0B0710'))
        ctx.set_source(g); ctx.paint()
        ca = prog(t, 4.6, 5.4)
        for (x, y, v, r, ph) in self.coins:
            draw_coin(ctx, x, (y + v * t) % (H + 80) - 40, t, ph, r=r, alpha=0.22 * ca)
        T = self.T; slam = T + 0.83
        k = 24 * math.exp(-(t - slam) * 9) if t > slam else 0
        rng = random.Random(fi)
        sh = (rng.uniform(-k, k), rng.uniform(-k, k))
        out = prog(t, 7.15, 7.5)
        draw_logo(ctx, W / 2, 470, t, T, sc=1.0 - 0.1 * out, alpha=1 - out, shake=sh)
        draw_text(ctx, "R E C O G E   ·   E N C A D E N A   ·   R O B A", W / 2, 760, 44, fam=FB, bold=True, fill=DIM,
                  alpha=prog(t, T + 1.9, T + 2.3) * (1 - out))
        draw_parts(ctx, w.parts, 's')
        vignette(ctx, 0.5)
        flash(ctx, 0.4 * (1 - prog(t, slam, slam + 0.25)) if t >= slam else 0)


class Roster(Scene):  # elige tu personaje
    t0, t1 = 7.5, 11.0
    XS = (300, 740, 1180, 1620)
    GY = 600   # centro del muñeco

    def setup(self):
        self.dolls = []
        for i, x in enumerate(self.XS):
            dd = Doll(i); dd.r = 100; dd.x, dd.y = x, self.GY; dd.look = (0.0, 0.3); dd.marker = False; dd.visible = True
            dd.face = 1 if x < W / 2 else -1; dd.blink_off = i * 0.9
            self.dolls.append(dd)
        self.land = [8.0 + i * 0.5 for i in range(4)]   # cada uno cae en un golpe de la música
        r = random.Random(17)
        self.motes = [(r.uniform(0, W), r.uniform(0, H), r.uniform(1.5, 3.5), r.uniform(-10, 10), r.uniform(-30, -10), r.randrange(4)) for _ in range(70)]

    def update(self, t):
        if t >= 7.55 and w.once('r_title'):
            w.ev('word')
        for i, lt in enumerate(self.land):
            if t >= lt and w.once(('r_land', i)):
                x = self.XS[i]; w.ev('slam')
                w.sparks(x, self.GY + 92, 18, PL[i]['col'], 620, sp='s', size=8)
                for k in range(10):
                    a = math.pi + k * math.pi / 9; v = w.rng.uniform(120, 260)
                    w.part('puff', x + math.cos(a) * 60, self.GY + 92, math.cos(a) * v, -abs(math.sin(a)) * v * 0.3, life=0.6,
                           size=16, col=hexc('#3A2A50'), drag=3, sp='s')
            if t >= lt + 0.12 and w.once(('r_name', i)):
                w.ev('pop')
        for i in range(4):
            if t >= 10.05 + i * 0.1 and w.once(('r_tag', i)):
                w.ev('pop')
        w.update(t)

    def draw(self, ctx, t, fi):
        g = cairo.RadialGradient(W / 2, 560, 80, W / 2, 560, 1200)
        g.add_color_stop_rgba(0, *hexc('#2E1446')); g.add_color_stop_rgba(1, *hexc('#0B0710'))
        ctx.set_source(g); ctx.paint()
        for (x, y, rr, vx, vy, k) in self.motes:
            ctx.arc((x + vx * t) % W, (y + vy * t) % H, rr, 0, 2 * math.pi); ctx.set_source_rgba(*wa(shade(PL[k]['col'], 0.3), 0.22)); ctx.fill()
        ctx.rectangle(0, self.GY + 120, W, H); lg = cairo.LinearGradient(0, self.GY + 120, 0, H)
        lg.add_color_stop_rgba(0, *wa(hexc('#120A1C'), 0.0)); lg.add_color_stop_rgba(0.25, *hexc('#120A1C')); lg.add_color_stop_rgba(1, *hexc('#08050C'))
        ctx.set_source(lg); ctx.fill()
        for i, dd in enumerate(self.dolls):
            lt = self.land[i]; x = self.XS[i]; col = PL[i]['col']
            on = prog(t, lt, lt + 0.25)
            if on > 0:   # foco y peana
                cone = cairo.LinearGradient(0, 0, 0, self.GY + 110)
                cone.add_color_stop_rgba(0, *wa(shade(col, 0.4), 0.0)); cone.add_color_stop_rgba(1, *wa(shade(col, 0.4), 0.2 * on))
                ctx.move_to(x - 40, -10); ctx.line_to(x + 40, -10); ctx.line_to(x + 190, self.GY + 110); ctx.line_to(x - 190, self.GY + 110); ctx.close_path()
                ctx.set_source(cone); ctx.fill()
                rg = cairo.RadialGradient(x, self.GY + 104, 10, x, self.GY + 104, 210)
                rg.add_color_stop_rgba(0, *wa(col, 0.45 * on)); rg.add_color_stop_rgba(1, *wa(col, 0))
                ctx.set_source(rg); ellipse(ctx, x, self.GY + 104, 210, 60); ctx.fill()
            ellipse(ctx, x, self.GY + 104, 150, 34); fill_stroke(ctx, hexc('#2A1E3C'), OUTL, 7)
            ellipse(ctx, x, self.GY + 98, 132, 26); ctx.set_dash([12, 9]); ctx.set_line_width(3)
            ctx.set_source_rgba(*wa(STITCH, 1.0)); ctx.stroke(); ctx.set_dash([])
            if t < lt - 0.3:
                continue
            fall = prog(t, lt - 0.3, lt)
            yy = self.GY - 760 * (1 - e_in_cubic(fall))
            dd.squash = 0.32 * math.exp(-(t - lt) * 9) * math.cos((t - lt) * 30) if t >= lt else -0.12
            if t >= lt + 0.6:
                dd.squash = 0.0
            dd.y = yy
            draw_hero(ctx, dd, t, t)
            dd.y = self.GY
            nu = prog(t, lt + 0.1, lt + 0.3)
            if nu > 0:
                draw_text(ctx, HERO_NAME[KINDS[i]], x, self.GY + 205, 74, fam=FG, fill=shade(col, 0.12), ow=8, oc=hexc('#0B0710'),
                          shadow=(0, 8, hexc('#0B0710')), sc=lerp(1.6, 1, e_out_back(nu)), alpha=clamp(nu * 3))
                draw_text(ctx, HERO_ROLE[KINDS[i]], x, self.GY + 268, 36, fam=FB, bold=True, fill=DIM, alpha=prog(t, lt + 0.25, lt + 0.45))
            tu = prog(t, 10.05 + i * 0.1, 10.25 + i * 0.1)
            if tu > 0:   # cada jugador elige el suyo
                s_ = e_out_back(tu); ty = self.GY - 330 + math.sin(t * 6 + i) * 5
                ctx.save(); ctx.translate(x, ty); ctx.scale(s_, s_)
                rrect(ctx, -56, -32, 112, 64, 20); fill_stroke(ctx, col, OUTL, 7)
                draw_text(ctx, f"J{i + 1}", 0, 2, 42, fill=WHITE if i < 3 else OUTL, ow=4 if i < 3 else 0)
                ctx.move_to(-12, 32); ctx.line_to(12, 32); ctx.line_to(0, 48); ctx.close_path(); fill_stroke(ctx, col, OUTL, 5)
                ctx.restore()
        draw_parts(ctx, w.parts, 's')
        u = prog(t, 7.55, 7.8)
        draw_text(ctx, "ELIGE TU PERSONAJE", W / 2, 130, 104, fam=FG, grad=bone_grad, ow=10, oc=hexc('#0B0710'), shadow=(0, 12, hexc('#5C1018')),
                  sc=lerp(1.6, 1, e_out_back(u)), alpha=clamp(u * 3))
        vignette(ctx, 0.5)
        flash(ctx, 1 - prog(t, 7.5, 7.7), DEEP)
        flash(ctx, prog(t, 10.8, 11.0), BG)


class S3(Scene):  # Ciénaga: lluvia de doblones y aparición
    t0, t1, shift = 7.5, 10.5, 3.5

    def setup(self):
        w.st = 7.5; w.set_arena('cienaga')
        rng = random.Random(21)
        OTHER_A = {1: [(9.6, 1100, 100), (10.8, 1010, 225), (12.0, 900, 232), (13.2, 720, 196), (14.4, 590, 190), (15.4, 530, 205), (16.5, 480, 200)],
                   2: [(9.6, 1100, 500), (10.8, 1000, 400), (12.0, 1100, 330), (13.2, 1010, 545), (14.4, 900, 548), (15.6, 1060, 525), (16.5, 1100, 420)],
                   3: [(9.6, 100, 100), (10.8, 180, 205), (12.0, 115, 250), (13.2, 200, 75), (14.4, 300, 55), (15.0, 205, 90), (15.6, 175, 215), (16.5, 110, 250)]}
        self.other = OTHER_A
        avoid = samples_of(CORAL_A, 9.6, 16.5) + list(CHESTS) + SPAWNS
        pts = [path_fn(CORAL_A)(ti) for ti in S4_PICKS]
        coral_s = samples_of(CORAL_A, 9.6, 16.5)
        for pid, ks in OTHER_A.items():
            f = path_fn(ks)
            for k in range(7):
                x, y = f(10.6 + k * 0.8)
                if not blocked(x, y, 18) and far_from(x, y, coral_s, 50) and far_from(x, y, pts, 36) and far_from(x, y, CHESTS, 45):
                    pts.append((x, y))
        tries = 0
        while len(pts) < 50 and tries < 5000:
            tries += 1
            x, y = rng.uniform(30, AW - 30), rng.uniform(30, AH - 30)
            if blocked(x, y, 22) or not far_from(x, y, avoid, 46) or not far_from(x, y, pts, 38):
                continue
            pts.append((x, y))
        order = sorted(range(len(pts)), key=lambda i: pts[i][0])
        for rank, i in enumerate(order):
            x, y = pts[i]
            w.coins.append(Coin(x, y, 7.6 + rank * 0.022, drop_h=320, rng=rng))
        for (cx, cy) in CHESTS:
            w.chests.append(dict(x=cx, y=cy, born=9.3))
        d0, d1, d2, d3 = w.d
        for d, (sx, sy) in zip(w.d, SPAWNS):
            d.place(sx, sy); d.spawn_t = 8.75 + d.pid * 0.06
        d0.keys(CORAL_A)
        d1.keys(OTHER_A[1]); d2.keys(OTHER_A[2]); d3.keys(OTHER_A[3])
        self.cam = Cam(600, 300, 1.42)

    def update(self, t):
        if t >= 8.75 and w.once('spawn'):
            for d in w.d:
                d.visible = True; w.puff(d.x, d.y); w.ev('puff')
        if t >= 9.3 and w.once('chests'):
            w.ev('pop')
        if t >= 9.05 and w.once('you'):
            w.ev('pop')
        w.update(t)
        self.cam.z = lerp(1.42, 1.5, e_in_out(prog(t, 7.5, 10.5)))

    def draw(self, ctx, t, fi):
        render_world(ctx, w, self.cam, t, fi)
        vignette(ctx, 0.45)
        u = prog(t, 9.05, 9.3); e = prog(t, 10.2, 10.45)
        if u > 0 and e < 1:
            d = w.d[0]; sx, sy = self.cam.to_screen(d.x, d.y - 64); sx = max(sx, 230)
            bob = math.sin(t * 8) * 6
            ctx.save(); ctx.translate(sx, sy - 70 + bob); ctx.scale(e_out_back(u) * (1 - e), e_out_back(u) * (1 - e))
            rrect(ctx, -190, -40, 380, 80, 26); fill_stroke(ctx, PANEL, d.col, 8)
            draw_text(ctx, "¡Eres el Jugador 1!", 0, 0, 40, fill=WHITE, ow=3)
            ctx.move_to(-18, 40); ctx.line_to(18, 40); ctx.line_to(0, 62); ctx.close_path(); fill_stroke(ctx, d.col, OUTL, 4)
            ctx.restore()
        draw_hud(ctx, w, t, 90, slide=prog(t, 8.9, 9.3))
        watermark(ctx)
        flash(ctx, 1 - prog(t, 7.5, 7.85), BG)


class S4(Scene):  # recoge y encadena
    t0, t1, shift = 10.5, 16.5, 3.5

    def setup(self):
        w.crown_on = True
        self.cam = Cam(600, 300, 1.5)

    def update(self, t):
        w.update(t)
        d = w.d[0]
        z = lerp(1.5, 2.3, e_in_out(prog(t, 10.5, 11.1)))
        tx, ty = d.x + 40, d.y - 10
        k = e_in_out(prog(t, 10.5, 11.1))
        self.cam.cx = lerp(600, lerp(self.cam.cx, tx, 0.12), k) if k < 1 else lerp(self.cam.cx, tx, 0.12)
        self.cam.cy = lerp(300, lerp(self.cam.cy, ty, 0.12), k) if k < 1 else lerp(self.cam.cy, ty, 0.12)
        self.cam.z = z
        if z > 1.6:
            hw, hh = 960 / z, 540 / z
            self.cam.cx = clamp(self.cam.cx, hw - 30, AW + 30 - hw); self.cam.cy = clamp(self.cam.cy, hh - 30, AH + 30 - hh)
        for (s, a) in (("RECOGE", 10.75), ("ENCADENA", 13.4)):
            if t >= a and w.once(('word', s)):
                w.ev('word')

    def draw(self, ctx, t, fi):
        render_world(ctx, w, self.cam, t, fi)
        vignette(ctx, 0.45)
        kword(ctx, "RECOGE", t, 10.75, 12.7)
        kword(ctx, "ENCADENA", t, 13.4, 16.4, shcol=hexc('#8A1E6E'))
        draw_hud(ctx, w, t, lerp(88, 82, prog(t, 10.5, 16.5)))
        watermark(ctx)


class S5(Scene):  # dash y robo, en la Cripta de Huesos
    t0, t1, shift = 16.5, 20.5, 3.5
    HX, HY = 845, 380      # donde recibe el golpe Tuerca
    DROPS = [(-170, 105), (150, 110), (90, 80), (60, 100), (-15, 110), (-35, 100)]

    def setup(self):
        w.st = 16.5
        d0, d1, d2, d3 = w.d
        self.drops = [(self.HX + math.cos(math.radians(a)) * r, self.HY + math.sin(math.radians(a)) * r) for (a, r) in self.DROPS]
        enter_arena('cripta', seed=31, fill=30, clear=[(self.HX - 40, self.HY, 200)])
        w.hz_off = 2.62 - 17.38      # los pinchos de la fila saltan justo en el golpe
        for ch, (x, y) in zip(w.chests, CHESTS_MID):
            ch['x'], ch['y'] = x, y
        d2.score = max(d2.score, 24)
        d1.place(670, 380); d2.place(820, 378)
        d1.keys([(16.5, 670, 380), (17.2, 670, 380, 'L'), (17.38, 801, 380, 'L'), (17.6, 782, 378, 'E'), (18.0, 770, 372),
                 (18.25, 742, 362), (18.6, 748, 428), (18.95, 845, 452), (19.3, 895, 467), (20.5, 965, 515)])
        d2.keys([(16.5, 820, 378), (17.38, 845, 380, 'L'), (17.6, 878, 390, 'E'), (17.98, 878, 390, 'L'),
                 (18.6, 948, 345), (19.1, 927, 323), (20.5, 1010, 300)])
        d0.place(300, 470); d0.keys([(16.5, 300, 470), (18.5, 330, 560), (20.5, 250, 540)])
        d3.place(130, 300); d3.keys([(16.5, 130, 300), (18.5, 110, 230), (20.5, 140, 330)])
        self.cam = Cam(800, 390, 2.6)

    def update(self, t):
        st = w.st; d1, d2 = w.d[1], w.d[2]
        if 16.95 <= st < 17.2:
            d1.squash = 0.28 * e_out_cubic(prog(st, 16.95, 17.15))
            if w.once('windup'):
                w.ev('windup')
        elif st >= 17.2 and w.once('dash'):
            d1.squash = 0.0; d1.dash_until = 17.38; w.ev('dash')
        if st >= 17.38 and w.once('hit'):
            w.ev('hit'); w.ev('spikes'); w.hitstop = 3; w.shake = 14
            d2.flash_until = st + 0.12; d2.invuln_until = st + 1.4; d2.stun_until = st + 0.6; d2.combo = 0
            n = len(self.drops); d2.score -= n
            for (x, y) in self.drops:
                w.coins.append(Coin(x, y, st, src=(self.HX, self.HY - 8), flight=0.45,
                                    block_pid=2, block_until=st + 0.6, stolen_from=2, rng=w.rng))
            w.part('ring', self.HX - 22, self.HY - 2, life=0.35, size=10, col=WHITE, r0=10, r1=90)
            w.sparks(self.HX - 22, self.HY - 2, 16, WHITE, 420, size=6)
            w.text(self.HX, self.HY - 50, f"-{n}", col=hexc('#FF5A5F'), size=34, life=1.0)
            w.ev('scatter', n)
        if st >= 18.8 and w.once('s5ghost'):
            w.ev('ghost')
        w.update(t)
        self.cam.z = lerp(2.6, 2.75, prog(t, 16.5, 20.5))
        for (s, a) in (("GOLPEA", 17.38), ("¡Y ROBA!", 18.55)):
            if w.st >= a and w.once(('word', s)):
                w.ev('word')

    def draw(self, ctx, t, fi):
        render_world(ctx, w, self.cam, t, fi)
        vignette(ctx, 0.45)
        if 17.38 <= w.st < 17.46:
            flash(ctx, 0.35)
        kword(ctx, "GOLPEA", t, 17.42, 18.5, shcol=hexc('#1B4F8A'))
        kword(ctx, "¡Y ROBA!", t, 18.6, 20.4, shcol=hexc('#8A1E2A'))
        draw_hud(ctx, w, t, lerp(65, 61, prog(t, 16.5, 20.5)))
        watermark(ctx)


class S6(Scene):  # cofre, ruleta y Anillo de Poder, en el Taller Gnómico
    t0, t1, shift = 20.5, 24.0, 3.5

    def setup(self):
        w.st = 20.5
        d0, d1, d2, d3 = w.d
        enter_arena('taller', seed=41, fill=30, clear=[(530, 340, 140)], avoid=CHESTS_MID)
        w.hz_off = 3.5 - 23.2        # los chorros de vapor salen cuando ya va a por los doblones
        for ch, (x, y) in zip(w.chests, CHESTS_MID):
            ch['x'], ch['y'] = x, y
        for (x, y) in [path_fn(CORAL_S6)(ti) for ti in S6_PICKS]:
            w.coins.append(Coin(x, y, -9.0, rng=w.rng))
        d0.place(365, 300); d0.keys(CORAL_S6)
        d3.place(840, 460); d3.keys([(20.5, 840, 460), (24.0, 360, 460, 'L')])     # se deja llevar por la cinta
        d1.place(1100, 520); d1.path = None
        d2.place(1090, 140); d2.path = None
        w.roulette = dict(pid=0, t0=20.9, dur=0.8, n=20, hide=22.2)
        self.cam = Cam(495, 330, 2.6)
        self.item = None; self.ticks = 0

    def update(self, t):
        st = w.st; ch = w.chests[0]
        if st >= 20.85 and w.once('chest'):
            ch['open'] = 20.85; ch['fade'] = 21.15; w.ev('chest')
        if st >= 21.35 and w.once('chestpuff'):
            w.puff(ch['x'], ch['y'], 7, col=hexc('#B08A5C'))
        R = w.roulette
        if R['t0'] <= st <= R['t0'] + R['dur']:
            p = int(R['n'] * e_out_cubic(prog(st, R['t0'], R['t0'] + R['dur'])))
            while self.ticks < p:
                self.ticks += 1; w.ev('tick')
        if st >= 21.7 and w.once('ding'):
            w.ev('ding')
        if st >= 21.74 and w.once('legend'):
            w.ev('legend'); w.shake = 8
        if st >= 22.5 and w.once('slot'):
            self.item = 'ring'; w.ev('pop')
        if st >= 22.6 and w.once('activate'):
            self.item = None; w.d[0].ring_until = 28.6; w.ev('activate')
            w.sparks(w.d[0].x, w.d[0].y, 22, GOLD, 300, size=7)
        if st >= 23.2 and w.once('s6vent'):
            w.ev('vent')
        if t >= 20.55 and w.once(('word', 'cofres')):
            w.ev('word')
        w.update(t)
        self.cam.cx = lerp(self.cam.cx, w.d[0].x + 30, 0.08); self.cam.cy = lerp(self.cam.cy, w.d[0].y + 10, 0.08)

    def draw(self, ctx, t, fi):
        render_world(ctx, w, self.cam, t, fi)
        vignette(ctx, 0.45)
        st = w.st; d0 = w.d[0]
        sx, sy = self.cam.to_screen(d0.x, d0.y - d0.r * 2.9)
        la = prog(st, 21.72, 21.85) * (1 - prog(st, 22.3, 22.5))
        if la > 0:
            hx, hy = self.cam.to_screen(d0.x, d0.y)
            g = cairo.RadialGradient(hx, hy - 60, 120, hx, hy - 60, 900)
            g.add_color_stop_rgba(0, 0, 0, 0, 0); g.add_color_stop_rgba(1, 0, 0, 0, 0.72 * la)
            ctx.set_source(g); ctx.paint()
            rays(ctx, sx, sy, t, la)
            u = prog(st, 21.74, 21.96)
            draw_text(ctx, "L E G E N D A R I O", W / 2, 150, 34, fam=FB, bold=True, fill=GOLD, alpha=la)
            draw_text(ctx, "¡ANILLO DE PODER!", W / 2, 232, 112, fam=FG, grad=oldgold_grad, ow=10, oc=hexc('#0B0710'), shadow=(0, 12, GOLD_SH),
                      sc=lerp(1.8, 1, e_out_back(u)), alpha=la)
            draw_icon(ctx, 'ring', sx, sy, 34 * (1 + 0.6 * e_out_back(u)))
        fu = prog(st, 22.2, 22.5)
        if 0 < fu < 1:
            fx = lerp(sx, 118, e_in_out(fu)); fy = lerp(sy, 958, e_in_out(fu)) - math.sin(math.pi * fu) * 160
            draw_icon(ctx, 'ring', fx, fy, lerp(54, 34, fu))
        kword(ctx, "ABRE COFRES", t, 20.55, 21.7, shcol=hexc('#6B3F1F'))
        draw_hud(ctx, w, t, lerp(52, 49, prog(t, 20.5, 24.0)), item=self.item,
                 item_flash=1 - prog(st, 22.6, 22.9) if st >= 22.6 else 0.0)
        kword(ctx, "HECHIZOS", t, 22.75, 23.95, shcol=hexc('#5A2E8A'))
        watermark(ctx)


class S7(Scene):  # montaje de hechizos (Ciénaga)
    t0, t1, shift = 24.0, 27.0, 3.5

    def setup(self):
        enter_arena('cienaga', clear=[(260, 380, 80), (870, 300, 120), (470, 548, 90), (300, 540, 50)])
        w.chests = []
        self.cam = Cam(290, 370, 3.0)
        w.crown_on = False

    def update(self, t):
        st = w.st; d0, d1, d2, d3 = w.d
        if t >= 24.0 and w.once('cutA'):
            for d in w.d:
                d.visible = False
            d1.visible = True; d1.place(230, 380); d1.keys([(24.0, 230, 380), (24.42, 272, 380), (25.0, 286, 380)])
            w.force_crown = 1; d1.crown_t = -9
            w.projs.append(dict(kind='cloud', t0=24.05, t1=24.42, x0=80, y0=310, x1=272, y1=372))
            self.cam = Cam(290, 370, 3.0)
        if st >= 24.42 and w.once('sheep'):
            d1.sheep_until = st + 0.58; w.puff(272, 375, 12); w.ev('sheep')
            w.text(272, 320, "¡beee!", col=WHITE, size=26, life=0.6, rise=30)
        if t >= 25.0 and w.once('cutB'):
            w.force_crown = -1; d1.visible = False
            d2.visible = True; d2.place(820, 300); d2.face = 1
            d3.visible = True; d3.place(930, 300); d3.keys([(25.0, 930, 300), (25.25, 910, 301), (26.0, 908, 301)])
            self.cam = Cam(870, 300, 3.0); w.ev('cut')
        if st >= 25.12 and w.once('frost'):
            w.part('ring', 820, 300, life=0.4, size=10, col=FROST, r0=10, r1=180)
            for _ in range(14):
                a = w.rng.uniform(0, 2 * math.pi); v = w.rng.uniform(120, 260)
                w.part('shard', 820, 300, math.cos(a) * v, math.sin(a) * v, life=0.5, size=9, col=FROST, drag=3, rot=a + 1.57)
            w.ev('frost')
        if 25.05 <= st <= 25.4:
            d2.squash = -0.15 * math.sin(math.pi * prog(st, 25.05, 25.4))
        if st >= 25.2 and w.once('freeze'):
            d3.frozen_until = st + 1.1
        if t >= 26.0 and w.once('cutC'):
            d2.visible = False; d3.frozen_until = -9; d2.squash = 0
            d3.place(300, 540); d3.face = 1
            d0.visible = True; d0.place(500, 546); d0.keys([(26.0, 500, 546), (26.38, 470, 546), (26.6, 505, 550, 'E'), (27.0, 510, 550)])
            self.cam = Cam(405, 460, 3.0); w.ev('cut')
        if 26.05 <= st <= 26.2:
            d3.squash = 0.2 * math.sin(math.pi * prog(st, 26.05, 26.2))
        if st >= 26.12 and w.once('pinthrow'):
            w.projs.append(dict(kind='pin', t0=26.12, t1=26.38, x0=335, y0=538, x1=462, y1=544)); w.ev('pin')
        if st >= 26.38 and w.once('pinhit'):
            d0.flash_until = st + 0.12; d0.stun_until = st + 0.5; d0.invuln_until = st + 1.0
            n = min(5, d0.score); d0.score -= n
            for k in range(n):
                a = math.radians(-160 + k * 35)
                w.coins.append(Coin(470 + math.cos(a) * 95 + 30, 546 + math.sin(a) * 60 + 50, st, src=(470, 540), flight=0.45,
                                    block_pid=0, block_until=st + 0.6, stolen_from=0, rng=w.rng))
            w.sparks(470, 544, 14, WHITE, 380); w.shake = 8; w.ev('pinhit', n)
            w.text(470, 490, f"-{n}", col=hexc('#FF5A5F'), size=30)
        w.update(t)

    def draw(self, ctx, t, fi):
        render_world(ctx, w, self.cam, t, fi)
        vignette(ctx, 0.55)
        if t < 25.0:
            label(ctx, "MALDICIÓN OVINA", "Siempre va a por el líder", t, 24.02, PURPLE)
        elif t < 26.0:
            label(ctx, "NOVA DE ESCARCHA", "Congela a quien tengas cerca", t, 25.02, hexc('#1F6F8A'))
        else:
            label(ctx, "ALFILER VUDÚ", "Le hace soltar sus doblones", t, 26.02, hexc('#6E7388'))
        for c0 in (25.0, 26.0):
            if c0 <= t < c0 + 0.07:
                flash(ctx, 0.35)
        watermark(ctx)


class Arenas(Scene):  # montaje: las 4 arenas con sus trampas
    t0, t1 = 30.5, 34.5
    CUTS = [('cienaga', "CIÉNAGA EMBRUJADA", "Lodo que frena y raíces que atrapan"),
            ('cripta', "CRIPTA DE HUESOS", "Pinchos que avisan y un fantasma que ronda"),
            ('taller', "TALLER GNÓMICO", "Cintas, chorros de vapor y barriles"),
            ('biblioteca', "BIBLIOTECA ARCANA", "Portales y un rayo que gira")]

    def setup(self):
        self.snap = (w.coins, w.chests, [dict(d.__dict__) for d in w.d], w.crown_on, w.force_crown, w.projs, w.roulette)
        w.crown_on = False; w.force_crown = -1; w.projs = []; w.roulette = None; w.chests = []
        self.cur = -1; self.cam = Cam(600, 300, 1.5)

    def restore(self):
        coins, chests, dd, cr, fc, pj, ro = self.snap
        w.coins, w.chests = coins, chests
        for d, st_ in zip(w.d, dd):
            d.__dict__.clear(); d.__dict__.update(st_)
        w.crown_on, w.force_crown, w.projs, w.roulette = cr, fc, pj, ro
        w.set_arena('cienaga'); w.parts = []; w.texts = []; w.shake = 0.0; w.hitstop = 0; w.hz_off = 0.0

    def start(self, i):
        self.cur = i; aid = self.CUTS[i][0]
        w.roots = []; w.barrels = {}; w.set_arena(aid)
        w.st = 0.0; w.coins = []; w.texts = []; w.parts = [p for p in w.parts if p['sp'] == 's']; w.shake = 0.0; w.hitstop = 0
        for d in w.d:
            d.visible = False; d.path = None; d.trail = []; d.squash = 0.0; d.tilt = 0.0; d.combo = 0; d.spawn_t = -9.0
            d.flash_until = d.invuln_until = d.stun_until = d.sheep_until = d.frozen_until = d.ring_until = d.dash_until = -9.0
        d0, d1, d2, d3 = w.d
        paths = []
        if i == 0:     # raíces y lodo
            w.hz_off = 0.0
            w.roots = [dict(x=600, y=232, t0=0.0, warn=0.35, active=1.0)]
            d1.visible = True; d1.place(470, 200); d1.keys([(0.0, 470, 200), (0.35, 600, 200, 'E'), (1.2, 600, 200, 'L')])
            d2.visible = True; d2.place(745, 150); d2.keys([(0.0, 745, 150), (1.2, 830, 172, 'L')])
            paths = [(470, 200), (600, 200), (745, 150), (830, 172)]
            self.cam = Cam(660, 205, 2.3); w.ev('warn')
        elif i == 1:   # pinchos y fantasma
            w.hz_off = 2.15
            d2.visible = True; d2.place(690, 300); d2.keys([(0.0, 690, 300), (0.45, 797, 300, 'L'), (0.62, 745, 335, 'E'), (1.2, 735, 340)])
            d3.visible = True; d3.place(985, 300); d3.face = -1
            paths = [(690, 300), (797, 300), (745, 335), (985, 300), (665, 250), (700, 370), (745, 400)]
            self.cam = Cam(790, 290, 2.3); w.ev('warn')
        elif i == 2:   # cinta, barril y vapor
            w.hz_off = 2.9
            d3.visible = True; d3.place(740, 460); d3.keys([(0.0, 740, 460), (1.2, 560, 460, 'L')])     # se deja llevar por la cinta
            d1.visible = True; d1.place(880, 430)
            d1.keys([(0.0, 880, 430), (0.08, 895, 345, 'L'), (0.2, 882, 385, 'E'), (0.45, 862, 430), (0.62, 830, 478, 'E'), (1.2, 826, 484)])
            d1.dash_until = 0.08; w.barrels = {7: dict(fuse=0.08, boom=0.45)}
            paths = [(780, 530), (860, 550), (1000, 450)]
            self.cam = Cam(800, 300, 2.2); w.ev('dash')
        else:          # portales y rayo
            w.hz_off = 2.51
            d0.visible = True; d0.place(200, 90); d0.keys([(0.0, 200, 90), (0.3, 296, 62, 'L')])
            d2.visible = True; d2.place(400, 462); d2.keys([(0.0, 400, 462), (0.6, 430, 445, 'L'), (1.2, 432, 444)])
            d1.visible = True; d1.place(1100, 110); d1.keys([(0.0, 1100, 110), (1.2, 1105, 190)])
            d3.visible = True; d3.place(1095, 520); d3.keys([(0.0, 1095, 520), (1.2, 1080, 505)])
            paths = [(900, 540), (870, 512), (840, 490), (470, 520), (370, 525), (505, 480)]
            self.cam = Cam(600, 265, 1.3)
        for d in w.d:
            if d.visible:
                paths += [d.path(k * 0.05) for k in range(25)] if d.path else [(d.x, d.y)]
        enter_arena(aid, seed=50 + i, fill=26, avoid=paths)

    def update(self, t):
        i = min(3, int((t - self.t0) * 1.0000001))
        if i != self.cur:
            self.start(i)
            if i > 0:
                w.ev('cut')
        st = w.st; d0, d1, d2, d3 = w.d
        if i == 0:
            if st >= 0.35 and w.once('m_roots'):
                w.ev('roots'); d1.flash_until = st + 0.1
                w.text(600, 120, "¡ATRAPADO!", col=hexc('#9BE05A'), size=30, life=0.8, rise=20)
            if st >= 0.35:
                d1.tilt = 0.14 * math.sin(st * 34) * (1 - prog(st, 0.9, 1.0))
            if int(st * 9) != int((st - DT) * 9):
                w.part('dust', d2.x + w.rng.uniform(-14, 14), d2.y + 24, w.rng.uniform(-30, 30), -20, life=0.4, size=6, col=hexc('#4A4A26'), drag=3)
            if st >= 0.45 and w.once('m_lento'):
                w.text(d2.x, d2.y - 70, "¡LENTO!", col=hexc('#C9B26A'), size=26, life=0.7, rise=20)
        elif i == 1:
            if st >= 0.1 and w.once('m_ghost'):
                w.ev('ghost')
            if st >= 0.45 and w.once('m_spike'):
                w.ev('spikes'); w.ev('hit'); w.shake = 10; w.hitstop = 2
                knock(d2, [(665, 250), (700, 370), (745, 400)])
        elif i == 2:
            if st >= 0.1 and w.once('m_fuse'):
                w.ev('fuse')
            if st >= 0.45 and w.once('m_boom'):
                w.ev('boom'); w.shake = 18; w.hitstop = 2
                knock(d1, [(780, 530), (860, 550), (1000, 450)])
                w.text(900, 250, "¡BUM!", col=ORANGE, size=46, life=0.6, rise=30)
            if st >= 0.6 and w.once('m_vent'):
                w.ev('vent')
        else:
            if st >= 0.3 and w.once('m_portal_in'):
                d0.visible = False; w.ev('portal')
                w.part('ring', 300, 60, life=0.35, size=8, col=FROST, r0=8, r1=60); w.puff(300, 60, 8, col=FROST, size=9)
            if st >= 0.42 and w.once('m_portal_out'):
                d0.visible = True; d0.place(900, 540); d0.keys([(0.42, 900, 540), (1.2, 830, 485, 'E')])
                w.part('ring', 900, 540, life=0.35, size=8, col=FROST, r0=60, r1=8); w.puff(900, 540, 8, col=FROST, size=9)
            if st >= 0.6 and w.once('m_zap'):
                w.ev('zap'); w.shake = 8
                knock(d2, [(470, 520), (370, 525), (505, 480)])
                w.text(d2.x + 80, d2.y - 50, "¡ZAS!", col=FROST, size=44, life=0.6, rise=25)
        w.update(t)

    def draw(self, ctx, t, fi):
        i = max(self.cur, 0); c0 = self.t0 + i
        render_world(ctx, w, self.cam, t, fi)
        vignette(ctx, 0.5)
        if i == 2 and 0.45 <= w.st < 0.53:
            flash(ctx, 0.4, hexc('#FFD9A0'))
        aid, title, sub = self.CUTS[i]
        acc = hexc(AR.ARENAS[aid]['accent'])
        draw_text(ctx, f"ARENA {i + 1} DE 4", W / 2, 52, 30, fam=FB, bold=True, fill=acc, ow=4, oc=hexc('#0B0710'), alpha=prog(t, c0, c0 + 0.1))
        label(ctx, title, sub, t, c0 + 0.02, shade(acc, -0.45))
        if c0 <= t < c0 + 0.07 and i > 0:
            flash(ctx, 0.35)
        watermark(ctx)


class S8(Scene):  # ¡FRENESÍ!
    t0, t1, shift = 27.0, 32.0, 7.5

    def setup(self):
        MONTAGE.restore()
        w.st = 27.0; w.frenzy = True; w.crown_on = True; w.force_crown = -1; w.projs = []
        lane = samples_of(CORAL_S8, 27.0, 32.0)
        for c in w.coins:
            if c.alive and not far_from(c.x, c.y, lane, 50):
                c.alive = False
        f = path_fn(CORAL_S8)
        for ti in S8_PICKS:
            x, y = f(ti)
            w.coins.append(Coin(x, y, max(27.0, ti - 0.95), drop_h=360, rng=w.rng))
        d0, d1, d2, d3 = w.d
        for d in w.d:
            d.visible = True; d.sheep_until = d.frozen_until = d.stun_until = -9; d.squash = 0
        d0.place(240, 400); d0.keys(CORAL_S8)
        d1.place(640, 90); d1.keys([(27.0, 640, 90), (28.5, 860, 70), (30.0, 1060, 75), (31.5, 1110, 190), (32.0, 1105, 200)])
        d2.place(150, 90); d2.keys([(27.0, 150, 90), (28.5, 330, 62), (30.0, 540, 95), (31.5, 640, 70), (32.0, 660, 80)])
        d3.place(100, 300); d3.keys([(27.0, 100, 300), (28.5, 115, 220), (30.0, 95, 335), (31.5, 125, 385), (32.0, 135, 392)])
        for d in (d1, d2, d3):
            for k in range(14):
                ti = 27.6 + 0.3 * k; x, y = d.path(ti)
                if free_spot(x, y, 18) and far_from(x, y, lane, 60):
                    w.coins.append(Coin(x, y, max(27.0, ti - 0.95), drop_h=360, rng=w.rng))
        self.lane = lane; self.rng = random.Random(77); self.cam = Cam(600, 300, 1.5); self.next_rain = 27.0

    def update(self, t):
        st = w.st
        if t >= 27.0 and w.once('frenzy'):
            w.ev('frenzy'); w.shake = 10
        while self.next_rain <= min(st, 31.6):
            for _ in range(30):
                x, y = self.rng.uniform(30, AW - 30), self.rng.uniform(30, AH - 30)
                if free_spot(x, y, 22) and far_from(x, y, self.lane, 60):
                    w.coins.append(Coin(x, y, self.next_rain, drop_h=360, rng=self.rng)); break
            self.next_rain += 0.09
        w.update(t)
        if w.tier3_t > 0 and w.once('vcombo'):
            w.shake = 14
            for _ in range(140):
                w.part('confetti', self.rng.uniform(0, W), self.rng.uniform(-300, -10), self.rng.uniform(-120, 120),
                       self.rng.uniform(200, 480), life=2.6, size=16, col=PL[self.rng.randrange(4)]['col'] if self.rng.random() < 0.8 else GOLD,
                       g=120, rot=self.rng.uniform(0, 6), vr=self.rng.uniform(-10, 10), sp='s')
        d0 = w.d[0]
        k = e_in_out(prog(t, 28.2, 29.0))
        tz = 2.1 + (0.25 * (1 - prog(t, w.tier3_t, w.tier3_t + 0.6)) if w.tier3_t > 0 and t >= w.tier3_t else 0)
        self.cam.z = lerp(1.5, tz, k)
        fx, fy = lerp(600, d0.x + 80, k), lerp(300, d0.y - 20, k)
        self.cam.cx = lerp(self.cam.cx, fx, 0.15 + 0.85 * (1 - k)); self.cam.cy = lerp(self.cam.cy, fy, 0.15 + 0.85 * (1 - k))
        if self.cam.z > 1.6:
            self.cam.cx = clamp(self.cam.cx, 1920 / (2 * self.cam.z) - 30, AW + 30 - 1920 / (2 * self.cam.z))
            self.cam.cy = clamp(self.cam.cy, 1080 / (2 * self.cam.z) - 30, AH + 30 - 1080 / (2 * self.cam.z))

    def draw(self, ctx, t, fi):
        render_world(ctx, w, self.cam, t, fi)
        vignette(ctx, 0.45)
        frenzy_border(ctx, t)
        u = prog(t, 27.0, 27.25); e = prog(t, 28.1, 28.5)
        if u > 0 and e < 1:
            sc = lerp(2.3, 1.0, e_out_back(u)) * (1 + 0.04 * math.sin(t * 18)) * lerp(1, 0.45, e_in_out(e))
            draw_text(ctx, "¡FRENESÍ!", W / 2, lerp(520, 210, e_in_out(e)), 220, fam=FG, grad=oldgold_grad, ow=14, oc=hexc('#0B0710'),
                      shadow=(0, 16, GOLD_SH), sc=sc, rot=-0.04, alpha=1 - prog(t, 28.3, 28.5))
            draw_text(ctx, "Los doblones valen el doble", W / 2, 680, 44, fam=FB, bold=True, fill=WHITE, ow=4,
                      alpha=prog(t, 27.25, 27.45) * (1 - e))
        if 27.0 <= t < 27.12:
            flash(ctx, 0.45, GOLD_HI)
        tv = w.tier3_t
        if tv > 0 and tv <= t < tv + 1.45:
            uu = prog(t, tv, tv + 0.25); ee = prog(t, tv + 1.15, tv + 1.45)
            flash(ctx, 0.5 * (1 - prog(t, tv, tv + 0.2)))
            draw_text(ctx, "¡VOODOO COMBO!", W / 2, 390, 180, fam=FG, grad=rainbow_grad(t), ow=14, oc=hexc('#0B0710'), shadow=(0, 16, hexc('#2A1240')),
                      sc=lerp(2.2, 1, e_out_back(uu)) * (1 + 0.035 * math.sin(t * 20)), rot=-0.04, alpha=1 - ee)
            draw_text(ctx, "x4", W / 2, 535, 90, grad=rainbow_grad(t + 0.3), ow=8, sc=lerp(2, 1, e_out_back(prog(t, tv + 0.15, tv + 0.35))),
                      alpha=prog(t, tv + 0.15, tv + 0.25) * (1 - ee))
        draw_parts(ctx, w.parts, 's')
        draw_hud(ctx, w, t, lerp(15, 5.01, prog(t, 27.0, 32.0)), frenzy=True)
        watermark(ctx)


class S9(Scene):  # cuenta atrás y ¡TIEMPO!
    t0, t1, shift = 32.0, 34.0, 7.5

    def setup(self):
        w.ts = 0.0; self.cam = Cam(600, 300, 1.5)

    def update(self, t):
        for n, a in ((3, 32.0), (2, 32.5), (1, 33.0)):
            if t >= a and w.once(('count', n)):
                w.ev('count', n)
        if t >= 33.5 and w.once('tiempo'):
            w.ev('tiempo')
        w.update(t)

    def draw(self, ctx, t, fi):
        render_world(ctx, w, self.cam, t, fi)
        ctx.set_source_rgba(0, 0, 0, 0.5); ctx.paint()
        vignette(ctx, 0.5)
        for n, a in ((3, 32.0), (2, 32.5), (1, 33.0)):
            if a <= t < a + 0.5:
                u = prog(t, a, a + 0.18)
                draw_text(ctx, str(n), W / 2, 560, 360, fam=FG, grad=oldgold_grad if n == 1 else bone_grad, ow=16, oc=hexc('#0B0710'), shadow=(0, 18, hexc('#5C1018')),
                          sc=lerp(2.4, 1, e_out_back(u)), alpha=1 - prog(t, a + 0.38, a + 0.5))
        if t >= 33.5:
            u = prog(t, 33.5, 33.7)
            flash(ctx, 0.6 * (1 - prog(t, 33.5, 33.75)))
            draw_text(ctx, "¡TIEMPO!", W / 2, 560, 230, fam=FG, grad=bone_grad, ow=14, oc=hexc('#0B0710'), shadow=(0, 16, hexc('#8A1E2A')), sc=lerp(2.2, 1, e_out_back(u)), rot=-0.03)
        secs = 3 - int((t - 32.0) / 0.5) if t < 33.5 else 0
        draw_hud(ctx, w, t, secs)
        watermark(ctx)


class S10(Scene):  # podio
    t0, t1, shift = 34.0, 37.0, 7.5

    def setup(self):
        order = sorted(w.d, key=lambda d: -d.score)
        if order[0].pid != 0:
            w.d[0].score = order[0].score + 12; order = sorted(w.d, key=lambda d: -d.score)
        self.order = order
        self.blocks = [(960, 300, 300, 'gold'), (630, 300, 210, 'silver'), (1290, 300, 150, 'bronze')]
        self.dolls = []
        for rank, d in enumerate(order):
            dd = Doll(d.pid); dd.r = 84; dd.visible = True; dd.marker = False; dd.look = (0.0, 0.35)
            if rank < 3:
                bx, bw, bh, _ = self.blocks[rank]; dd.x, dd.y = bx, 980 - bh - 84 * 0.98
            else:
                dd.r = 58; dd.x, dd.y = 1540, 920
            self.dolls.append(dd)
        self.rng = random.Random(9)
        d1 = w.d[1]; d3 = w.d[3]
        self.awards = [(w.d[0], "Rey del Combo", f"Combo máximo x{w.d[0].max_combo}"),
                       (d1, "Manos Largas", f"{max(d1.stolen, 4)} doblones robados"),
                       (d3, "Intocable", "0 golpes recibidos")]

    def update(self, t):
        if t >= 34.0 and w.once('podwhoosh'):
            w.ev('whoosh')
        for i, a in enumerate((34.35, 34.45, 34.55)):
            if t >= a and w.once(('thump', i)):
                w.ev('thump')
        if t >= 34.7 and w.once('victory'):
            w.ev('victory')
        if t >= 34.95 and w.once('pcrown'):
            w.ev('crown'); w.sparks(960, 560, 24, GOLD, 520, sp='s', size=9)
            for _ in range(120):
                w.part('confetti', self.rng.uniform(0, W), self.rng.uniform(-400, -10), self.rng.uniform(-100, 100),
                       self.rng.uniform(180, 420), life=3.2, size=16, col=PL[self.rng.randrange(4)]['col'] if self.rng.random() < 0.8 else GOLD,
                       g=100, rot=self.rng.uniform(0, 6), vr=self.rng.uniform(-10, 10), sp='s')
        for i, a in enumerate((35.25, 35.65, 36.05)):
            if t >= a and w.once(('award', i)):
                w.ev('award')
        if t >= 36.4 and w.once('otra'):
            w.ev('pop')
        w.update(t)

    def draw(self, ctx, t, fi):
        g = cairo.RadialGradient(W / 2, 560, 80, W / 2, 560, 1100)
        g.add_color_stop_rgba(0, *hexc('#4A1022')); g.add_color_stop_rgba(1, *hexc('#0B0710'))
        ctx.set_source(g); ctx.paint()
        for i in range(3):
            bx = self.blocks[i][0]
            sg = cairo.LinearGradient(bx, 0, bx, 900)
            sg.add_color_stop_rgba(0, 1, 1, 1, 0.0); sg.add_color_stop_rgba(1, 1, 1, 1, 0.06 if i == 0 else 0.03)
            ctx.move_to(bx - 60, 0); ctx.line_to(bx + 60, 0); ctx.line_to(bx + 210, 980); ctx.line_to(bx - 210, 980); ctx.close_path()
            ctx.set_source(sg); ctx.fill()
        ctx.rectangle(0, 980, W, 100); ctx.set_source_rgba(*hexc('#120A1C')); ctx.fill()
        cols = {'gold': GOLD, 'silver': hexc('#D9D4E8'), 'bronze': hexc('#E39A5B')}
        for i, (bx, bw, bh, kind) in enumerate(self.blocks):
            u = e_out_back(prog(t, 34.15 + i * 0.1, 34.5 + i * 0.1))
            top = 980 - bh * u
            rrect(ctx, bx - bw / 2, top, bw, bh + 30, 18); fill_stroke(ctx, hexc('#2C1B45'), OUTL, 8)
            rrect(ctx, bx - bw / 2 + 10, top + 10, bw - 20, bh + 10, 12); ctx.set_dash([12, 9]); ctx.set_line_width(3)
            ctx.set_source_rgba(*STITCH); ctx.stroke(); ctx.set_dash([])
            draw_text(ctx, f"{i + 1}º", bx, top + min(bh, 150) / 2 + 10, 96, fill=cols[kind], ow=7, alpha=prog(t, 34.3, 34.5))
        for rank, dd in enumerate(self.dolls):
            u = prog(t, 34.35 + rank * 0.1, 34.7 + rank * 0.1)
            if u <= 0:
                continue
            d0 = dd.y
            dd_y = d0 - 500 * (1 - e_out_bounce(u))
            yy = dd.y; dd.y = dd_y
            if rank == 0 and t > 34.7:
                dd.squash = 0.1 * math.sin(t * 14); dd.tilt = 0.12 * math.sin(t * 7)
                dd.y -= abs(math.sin(t * 7)) * 30
            if rank == 3:
                dd.tilt = 0.15 * math.sin(t * 6)
            draw_hero(ctx, dd, t, t, crown=(rank == 0 and t >= 34.6), crown_drop=prog(t, 34.6, 35.0))
            dd.y = yy
        draw_parts(ctx, w.parts, 's')
        wd = self.order[0]
        u = prog(t, 34.7, 34.95)
        draw_text(ctx, f"¡GANA {wd.name}!", W / 2, 105, 110, fam=FG, fill=shade(wd.col, 0.15), ow=10, oc=hexc('#0B0710'), shadow=(0, 12, hexc('#0B0710')), sc=lerp(1.8, 1, e_out_back(u)), alpha=clamp(u * 3))
        for i, (pd, title, detail) in enumerate(self.awards):
            u = prog(t, 35.25 + i * 0.4, 35.5 + i * 0.4)
            if u <= 0:
                continue
            cx = 470 + i * 490; cy = 270
            ctx.save(); ctx.translate(cx, cy); s = e_out_back(u); ctx.scale(s, s)
            rrect(ctx, -225, -58, 450, 116, 26); fill_stroke(ctx, wa(PANEL, 0.96), pd.col, 7)
            ctx.arc(-170, 0, 37, 0, 2 * math.pi); ctx.set_source_rgba(*OUTL); ctx.fill()
            ctx.save(); ctx.translate(-170, 0); ctx.scale(68 / 60, 68 / 60); ctx.set_source_surface(portrait(pd.pid), -30, -30); ctx.paint(); ctx.restore()
            ctx.arc(-170, 0, 34, 0, 2 * math.pi); ctx.set_source_rgba(*pd.col); ctx.set_line_width(5); ctx.stroke()
            draw_text(ctx, title, -118, -18, 38, fam=FG, grad=bone_grad, ow=3, oc=hexc('#0B0710'), align='l')
            draw_text(ctx, detail, -118, 24, 28, fam=FB, bold=True, fill=DIM, align='l')
            ctx.restore()
        u = prog(t, 36.4, 36.6)
        if u > 0:
            s = e_out_back(u) * (1 + 0.04 * math.sin(t * 9))
            ctx.save(); ctx.translate(1700, 1030); ctx.scale(s, s)
            rrect(ctx, -140, -40, 280, 80, 22); fill_stroke(ctx, GOLD, OUTL, 8)
            draw_text(ctx, "¡OTRA!", 0, 2, 50, fill=OUTL)
            ctx.restore()
        vignette(ctx, 0.4)
        watermark(ctx)
        flash(ctx, 1 - prog(t, 34.0, 34.25), BG)


class S11(Scene):  # cierre
    t0, t1, shift = 37.0, 42.0, 7.5

    def setup(self):
        self.dolls = []
        for i, x in enumerate((720, 880, 1040, 1200)):
            dd = Doll(i); dd.r = 48; dd.visible = True; dd.x, dd.y = x, 935; dd.look = (0.0, 0.4); dd.marker = True
            self.dolls.append(dd)
        r = random.Random(13)
        self.coins = [(r.uniform(0, W), r.uniform(0, H), r.uniform(60, 140), r.uniform(10, 24), r.uniform(0, 6)) for _ in range(30)]

    def update(self, t):
        if t >= 37.0 and w.once('final'):
            w.ev('final')
        w.update(t)

    def draw(self, ctx, t, fi):
        g = cairo.RadialGradient(W / 2, 420, 60, W / 2, 420, 1150)
        g.add_color_stop_rgba(0, *hexc('#4A1022')); g.add_color_stop_rgba(1, *hexc('#0B0710'))
        ctx.set_source(g); ctx.paint()
        for (x, y, v, r, ph) in self.coins:
            draw_coin(ctx, x, (y + v * t) % (H + 80) - 40, t, ph, r=r, alpha=0.18)
        u = prog(t, 37.0, 37.3)
        draw_logo(ctx, W / 2, 300 + math.sin(t * 2) * 4, 99, 0, sc=0.8 * lerp(1.15, 1, e_out_back(u)), alpha=clamp(u * 3))
        draw_text(ctx, "2–4 JUGADORES  ·  PARTIDAS DE 90 s  ·  MULTIJUGADOR EN RED", W / 2, 585, 44, ow=5, alpha=prog(t, 37.5, 37.8))
        draw_text(ctx, "4 PERSONAJES  ·  4 ARENAS CON TRAMPAS  ·  7 HECHIZOS", W / 2, 648, 40, fam=FG, grad=bone_grad, ow=5, oc=hexc('#0B0710'),
                  alpha=prog(t, 37.75, 38.05))
        draw_text(ctx, "Hecho con Godot y agentes de IA: Claude + Codex", W / 2, 714, 36, fam=FB, bold=True, fill=DIM, alpha=prog(t, 38.0, 38.3))
        draw_text(ctx, "DevChallenge3  ·  2º DAM", W / 2, 768, 32, fam=FB, bold=True, fill=GOLD, alpha=prog(t, 38.25, 38.55))
        for i, dd in enumerate(self.dolls):
            uu = prog(t, 38.4 + i * 0.1, 38.75 + i * 0.1)
            if uu <= 0:
                continue
            yy = dd.y; dd.y = yy - abs(math.sin(t * 5 + i)) * 8
            dd.spawn_t = -9; ctx.save(); ctx.translate(dd.x, yy); ctx.scale(e_out_back(uu), e_out_back(uu)); ctx.translate(-dd.x, -yy)
            draw_hero(ctx, dd, t, t); ctx.restore(); dd.y = yy
        draw_text(ctx, "Tráiler conceptual: escenas de diseño, no capturas del juego final", W / 2, 1038, 24, fam=FB, bold=True,
                  fill=wa(DIM, 0.75), alpha=prog(t, 38.6, 39.0))
        vignette(ctx, 0.5)
        flash(ctx, 1 - prog(t, 37.0, 37.25) if t < 37.25 else 0.0)
        flash(ctx, prog(t, 41.2, 42.0), (0, 0, 0, 1))


MONTAGE = Arenas()
SCENES = [S1(), S2(), Roster(), S3(), S4(), S5(), S6(), S7(), MONTAGE, S8(), S9(), S10(), S11()]


# ================================================================ render
def run(mode, sample_times=()):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H)
    ctx = cairo.Context(surf)
    want = {int(round(s * FPS)) for s in sample_times}
    last = max(want) if want else None
    files = []
    for sc in SCENES:
        f0, f1 = int(round((sc.t0 + sc.shift) * FPS)), int(round((sc.t1 + sc.shift) * FPS))
        if last is not None and f0 > last:
            break
        sc.setup()
        proc = None; tmp = os.path.join(OUT, f'_{sc.__class__.__name__}.tmp.mp4'); final = os.path.join(OUT, f'{sc.__class__.__name__}.mp4')
        if mode == 'full':
            proc = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'bgra', '-s', f'{W}x{H}',
                                     '-r', str(FPS), '-i', '-', '-c:v', 'libx264', '-crf', '18', '-preset', 'veryfast',
                                     '-pix_fmt', 'yuv420p', tmp], stdin=subprocess.PIPE)
        for fi in range(f0, f1):
            tg = fi / FPS; t = tg - sc.shift
            w.tg = tg; w.t = t
            sc.update(t)
            if proc or fi in want:
                ctx.save(); ctx.set_operator(cairo.OPERATOR_SOURCE); ctx.set_source_rgba(0, 0, 0, 1); ctx.paint(); ctx.restore()
                ctx.save(); sc.draw(ctx, t, fi); ctx.restore()
                surf.flush()
                if proc:
                    proc.stdin.write(bytes(surf.get_data()))
                if fi in want:
                    surf.write_to_png(os.path.join(OUT, f'sample_{tg:05.2f}.png'))
        if proc:
            proc.stdin.close()
            if proc.wait() != 0:
                sys.exit('ffmpeg falló en ' + sc.__class__.__name__)
            os.replace(tmp, final); files.append(final)
            print('ok', sc.__class__.__name__, flush=True)
    return files


if __name__ == '__main__':
    if sys.argv[1] == 'samples':
        run('samples', [float(x) for x in sys.argv[2:]])
    else:
        files = run('full')
        import audio
        audio.build(w.events, TOTAL, os.path.join(OUT, 'audio.wav'), TL)
        with open(os.path.join(OUT, 'list.txt'), 'w') as fh:
            for f in files:
                fh.write(f"file '{f}'\n")
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', os.path.join(OUT, 'list.txt'),
                        '-c', 'copy', os.path.join(OUT, '_video.mp4')], check=True)
        final = os.path.join(OUT, 'VoodooCombo-trailer.mp4')
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', os.path.join(OUT, '_video.mp4'), '-i', os.path.join(OUT, 'audio.wav'),
                        '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest',
                        '-movflags', '+faststart', final + '.tmp.mp4'], check=True)
        os.replace(final + '.tmp.mp4', final)
        print('listo', final)
