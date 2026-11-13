"""Mundo del tráiler: arena, muñecos, doblones, partículas, cámara y HUD."""
import cairo, math, random
from gfx import *
from heroes import draw_hero
import arenas as AR

AW, AH, TILE = 1200, 600, 40
PAD = 40      # margen alrededor de la arena en la textura de fondo
BGS = 3       # escala de la textura de fondo


# ---------------------------------------------------------------- arena activa
OBS_PX = []   # obstáculos de la arena activa en píxeles (x, y, w, h, tipo)
HZ_PX = []    # trampas fijas de la arena activa (x, y, w, h): ahí no caen doblones
CAND = [(205, 150), (995, 150), (205, 450), (995, 450), (480, 225), (720, 225), (480, 375), (720, 375), (600, 255)]
LIGHTS = {
    'cienaga': [('candle', x, y) for (x, y) in CAND],
    'cripta': [('candle', x, y) for (x, y) in ((150, 130), (1050, 130), (150, 470), (1050, 470))] +
              [('glow', 570, 268, 55, '#FFB060'), ('glow', 630, 268, 55, '#FFB060'), ('glow', 600, 300, 150, '#8A3DFF')],
    'taller': [('glow', 600, 300, 210, '#FF8A3A')] + [('lamp', x, y) for (x, y) in ((110, 150), (1090, 150), (110, 450), (1090, 450))],
    'biblioteca': [('candle', x, y) for (x, y) in ((220, 215), (980, 215), (220, 385), (980, 385))] +
                  [('glow', x, y, 70, '#7FE7FF') for (x, y) in ((380, 244), (820, 244), (380, 324), (820, 324))],
}


def arena_rects(aid):
    A = AR.ARENAS[aid]
    obs = [(x * TILE, y * TILE, w * TILE, h * TILE, k) for (x, y, w, h, k) in A['obstacles']]
    hz = []
    for h in A['hazards']:
        ty = h['type']
        if ty in ('pinchos', 'cinta'):
            hz += [(tx * TILE, tyy * TILE, TILE, TILE) for (tx, tyy) in h['tiles']]
        elif ty == 'vapor':
            hz.append((h['x'] * TILE - 22, h['y'] * TILE - 22, 44, 44))
        elif ty == 'barril':
            hz.append((h['x'] * TILE - 20, h['y'] * TILE - 22, 40, 44))
        elif ty == 'portal':
            for p in (h['a'], h['b']):
                hz.append((p[0] * TILE - 26, p[1] * TILE - 26, 52, 52))
        elif ty == 'rayo':
            hz.append((h['x'] * TILE - 24, h['y'] * TILE - 24, 48, 48))
    return obs, hz


def blocked(x, y, m=0.0):
    if x < m or y < m or x > AW - m or y > AH - m:
        return True
    for (ox, oy, ow, oh, _) in OBS_PX:
        if ox - m < x < ox + ow + m and oy - m < y < oy + oh + m:
            return True
    return False


def on_hazard(x, y, m=0.0):
    for (ox, oy, ow, oh) in HZ_PX:
        if ox - m < x < ox + ow + m and oy - m < y < oy + oh + m:
            return True
    return False


def free_spot(x, y, m=0.0):
    return not blocked(x, y, m) and not on_hazard(x, y, m)


def draw_lamp(ctx, x, y):
    ellipse(ctx, x, y + 14, 10, 3.5); ctx.set_source_rgba(0, 0, 0, 0.45); ctx.fill()
    rrect(ctx, x - 9, y - 12, 18, 24, 4); fill_stroke(ctx, hexc('#FFD27A'), OUTL, 3.5)
    for xx in (x - 3, x + 3):
        ctx.move_to(xx, y - 12); ctx.line_to(xx, y + 12)
    ctx.set_source_rgba(*OUTL); ctx.set_line_width(2); ctx.stroke()
    rrect(ctx, x - 11, y - 17, 22, 6, 2); fill_stroke(ctx, hexc('#3A3A46'), OUTL, 3)
    rrect(ctx, x - 11, y + 11, 22, 6, 2); fill_stroke(ctx, hexc('#3A3A46'), OUTL, 3)


def build_arena_bg(aid='cienaga'):
    sw, sh = (AW + 2 * PAD) * BGS, (AH + 2 * PAD) * BGS
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, sw, sh)
    ctx = cairo.Context(surf); ctx.scale(BGS, BGS); ctx.translate(PAD, PAD)
    AR.draw_static(ctx, aid, 0.0, with_obstacles=True)
    for L in LIGHTS[aid]:
        if L[0] == 'candle':
            cx, cy = L[1], L[2]
            ellipse(ctx, cx, cy + 9, 9, 3); ctx.set_source_rgba(0, 0, 0, 0.4); ctx.fill()
            for (dx, h) in ((-5, 14), (3, 18), (8, 10)):
                rrect(ctx, cx + dx - 2.5, cy + 8 - h, 5, h, 1.5); fill_stroke(ctx, hexc('#E8DCC4'), OUTL, 2)
        elif L[0] == 'lamp':
            draw_lamp(ctx, L[1], L[2])
    return surf


def draw_lights(ctx, aid, t):
    for i, L in enumerate(LIGHTS[aid]):
        f = 0.75 + 0.25 * math.sin(t * 11 + i * 1.7) * math.sin(t * 6.3 + i)
        if L[0] == 'candle':
            cx, cy = L[1], L[2]
            g = cairo.RadialGradient(cx, cy - 6, 2, cx, cy - 6, 70)
            g.add_color_stop_rgba(0, 1.0, 0.75, 0.4, 0.42 * f); g.add_color_stop_rgba(1, 1.0, 0.5, 0.2, 0)
            ctx.set_source(g); ctx.arc(cx, cy - 6, 70, 0, 2 * math.pi); ctx.fill()
            for (dx, h) in ((-5, 14), (3, 18), (8, 10)):
                ellipse(ctx, cx + dx, cy + 8 - h - 4 - f * 1.5, 2.2, 3.6 + f); ctx.set_source_rgba(1, 0.85, 0.45, 0.95); ctx.fill()
        elif L[0] == 'lamp':
            cx, cy = L[1], L[2]
            g = cairo.RadialGradient(cx, cy, 2, cx, cy, 90)
            g.add_color_stop_rgba(0, 1.0, 0.8, 0.45, 0.45 * f); g.add_color_stop_rgba(1, 1.0, 0.55, 0.2, 0)
            ctx.set_source(g); ctx.arc(cx, cy, 90, 0, 2 * math.pi); ctx.fill()
            ellipse(ctx, cx, cy, 4, 6 + f * 1.5); ctx.set_source_rgba(1, 0.95, 0.7, 0.95); ctx.fill()
        else:
            _, cx, cy, rad, col = L
            c = hexc(col); g = cairo.RadialGradient(cx, cy, 2, cx, cy, rad)
            g.add_color_stop_rgba(0, *wa(c, 0.3 * f)); g.add_color_stop_rgba(1, *wa(c, 0))
            ctx.set_source(g); ctx.arc(cx, cy, rad, 0, 2 * math.pi); ctx.fill()


def vapor_fx(ctx, h, state, u):
    x, y = h['x'] * TILE, h['y'] * TILE
    if state == 'warn':
        for k in range(4):
            a = k * 1.6 + u * 3; rr = 6 + u * 10
            ctx.arc(x + math.cos(a) * 8, y - 8 - u * 16 - k * 3, rr * 0.5, 0, 2 * math.pi)
            ctx.set_source_rgba(0.85, 0.85, 0.9, 0.35 * (1 - u * 0.5)); ctx.fill()
    elif state == 'blast':
        R = h['radius'] * (0.4 + 0.6 * e_out_cubic(min(1, u * 2.5)))
        g = cairo.RadialGradient(x, y, 4, x, y, R); g.add_color_stop_rgba(0, 1, 1, 1, 0.85); g.add_color_stop_rgba(1, 0.9, 0.9, 0.95, 0.0)
        ctx.set_source(g); ctx.arc(x, y, R, 0, 2 * math.pi); ctx.fill()
        for k in range(8):
            a = k * math.pi / 4
            ctx.arc(x + math.cos(a) * R * 0.75, y + math.sin(a) * R * 0.75, 8 + u * 6, 0, 2 * math.pi)
            ctx.set_source_rgba(0.95, 0.95, 1, 0.5 * (1 - u)); ctx.fill()


def draw_arena_hz(ctx, w, t, layer):
    """Trampas de la arena activa. Las periódicas usan el reloj de trampas (w.st + w.hz_off);
    raíces y barriles los decide la escena (w.roots, w.barrels), igual que el servidor en el juego."""
    A = AR.ARENAS[w.arena]; ht = w.st + w.hz_off; st = w.st
    for i, h in enumerate(A['hazards']):
        ty = h['type']
        if layer == 'ground':
            if ty == 'lodo':
                AR.hz_lodo(ctx, h, t, static=False)
            elif ty == 'pinchos':
                s_ = AR.pinchos_state(h, ht)
                for (tx, tyy) in h['tiles']:
                    AR.hz_pincho_tile(ctx, tx, tyy, s_)
            elif ty == 'cinta':
                AR.hz_cinta(ctx, h, ht)
            elif ty == 'vapor':
                AR.hz_vapor(ctx, h, 'idle', 0)
            elif ty == 'portal':
                AR.hz_portal(ctx, h['a'][0] * TILE, h['a'][1] * TILE, h['color'], ht)
                AR.hz_portal(ctx, h['b'][0] * TILE, h['b'][1] * TILE, h['color'], ht + 1)
            elif ty == 'barril':
                b = w.barrels.get(i)
                if b is None or st < b['fuse']:
                    AR.hz_barril(ctx, h, 'idle', 0, t)
                elif st < b['boom']:
                    AR.hz_barril(ctx, h, 'fuse', prog(st, b['fuse'], b['boom']), t)
            elif ty == 'raices':
                for r_ in w.roots:
                    if r_['t0'] <= st < r_['t0'] + r_['warn']:
                        AR.hz_raices(ctx, r_['x'], r_['y'], 'warn', st - r_['t0'])
        else:
            if ty == 'fantasma':
                x, y, dx = AR.path_pos(h['path'], h['speed'], ht)
                AR.hz_fantasma(ctx, x, y, ht, 1 if dx >= 0 else -1)
            elif ty == 'rayo':
                AR.hz_rayo(ctx, h, ht)
            elif ty == 'vapor':
                s_, u = AR.vapor_state(h, ht)
                if s_ != 'idle':
                    vapor_fx(ctx, h, s_, u)
            elif ty == 'barril':
                b = w.barrels.get(i)
                if b is not None and b['boom'] <= st < b['boom'] + 0.6:
                    AR.hz_barril(ctx, h, 'boom', prog(st, b['boom'], b['boom'] + 0.6))
            elif ty == 'raices':
                for r_ in w.roots:
                    a0 = r_['t0'] + r_['warn']
                    if a0 <= st < a0 + r_['active']:
                        al = 1 - prog(st, a0 + r_['active'] - 0.15, a0 + r_['active'])
                        ctx.push_group(); ctx.save()
                        ctx.translate(r_['x'], r_['y']); ctx.scale(1.05, 0.62); ctx.translate(-r_['x'], -r_['y'])   # que agarren las piernas, no la cara
                        AR.hz_raices(ctx, r_['x'], r_['y'], 'active', st - a0)
                        ctx.restore(); ctx.pop_group_to_source(); ctx.paint_with_alpha(al)


# ---------------------------------------------------------------- caminos
def path_fn(keys):
    ks = sorted(keys, key=lambda k: k[0])

    def tan(j):
        a = ks[max(j - 1, 0)]; b = ks[min(j + 1, len(ks) - 1)]
        dt = b[0] - a[0]
        return (0.0, 0.0) if dt <= 0 else ((b[1] - a[1]) / dt, (b[2] - a[2]) / dt)

    def f(t):
        if t <= ks[0][0]:
            return ks[0][1], ks[0][2]
        if t >= ks[-1][0]:
            return ks[-1][1], ks[-1][2]
        i = 0
        while not (ks[i][0] <= t <= ks[i + 1][0]):
            i += 1
        t0, x0, y0 = ks[i][:3]; t1, x1, y1 = ks[i + 1][:3]
        h = t1 - t0; u = (t - t0) / h
        mode = ks[i + 1][3] if len(ks[i + 1]) > 3 else None
        if mode == 'L':
            return lerp(x0, x1, u), lerp(y0, y1, u)
        if mode == 'E':
            v = e_out_cubic(u); return lerp(x0, x1, v), lerp(y0, y1, v)
        m0 = tan(i) if not (len(ks[i]) > 3) else (0.0, 0.0)
        m1 = tan(i + 1)
        h00 = 2 * u ** 3 - 3 * u ** 2 + 1; h10 = u ** 3 - 2 * u ** 2 + u; h01 = -2 * u ** 3 + 3 * u ** 2; h11 = u ** 3 - u ** 2
        return (h00 * x0 + h10 * h * m0[0] + h01 * x1 + h11 * h * m1[0],
                h00 * y0 + h10 * h * m0[1] + h01 * y1 + h11 * h * m1[1])
    return f


# ---------------------------------------------------------------- entidades
class Doll:
    def __init__(self, pid):
        p = PL[pid]
        self.pid = pid; self.col = p['col']; self.shape = p['shape']; self.hat = p['hat']; self.name = p['name']
        self.x = self.y = 0.0; self.vx = self.vy = 0.0; self.r = 22.0
        self.path = None; self.visible = False; self.walk = 0.0
        self.score = 0; self.combo = 0; self.last_pick = -99.0; self.max_combo = 0; self.pop_t = -9.0
        self.squash = 0.0; self.tilt = 0.0
        self.flash_until = self.invuln_until = self.stun_until = -9.0
        self.ring_until = self.frozen_until = self.sheep_until = -9.0
        self.spawn_t = -9.0; self.look = (0.0, 0.3); self.face = 1
        self.blink_off = pid * 0.83; self.dash_until = -9.0; self.trail = []
        self.collect = True; self.marker = True; self.stolen = 0; self.crown_t = -9.0

    def keys(self, ks):
        self.path = path_fn(ks)

    def place(self, x, y):
        self.x, self.y = x, y; self.path = None; self.vx = self.vy = 0.0


class Coin:
    def __init__(self, x, y, born, drop_h=0.0, src=None, flight=0.45, block_pid=-1, block_until=-9.0, stolen_from=-1, rng=None):
        self.x, self.y = x, y; self.born = born; self.drop_h = drop_h; self.src = src
        self.flight = flight if (drop_h > 0 or src) else 0.0
        self.alive = True; self.phase = (rng or random).uniform(0, 6.28)
        self.block_pid = block_pid; self.block_until = block_until; self.landed = False; self.stolen_from = stolen_from

    def land_t(self):
        return self.born + self.flight

    def pos(self, st):
        if self.flight <= 0:
            return self.x, self.y, 0.0
        u = clamp((st - self.born) / self.flight)
        if self.src:
            return lerp(self.src[0], self.x, u), lerp(self.src[1], self.y, u), math.sin(math.pi * u) * 80
        return self.x, self.y, self.drop_h * (1 - e_out_bounce(u))


class Cam:
    def __init__(self, cx=600, cy=300, z=1.5, ax=960, ay=600):
        self.cx, self.cy, self.z, self.ax, self.ay = cx, cy, z, ax, ay

    def to_screen(self, x, y):
        return self.ax + (x - self.cx) * self.z, self.ay + (y - self.cy) * self.z


class World:
    def __init__(self):
        self.d = [Doll(i) for i in range(4)]
        self.coins, self.chests, self.parts, self.texts, self.projs = [], [], [], [], []
        self.events = []; self.st = 0.0; self.ts = 1.0; self.t = 0.0
        self.frenzy = False; self.multi = True
        self.rng = random.Random(11); self.fired = set()
        self.leader = -1; self.crown_on = False; self.force_crown = -1
        self.shake = 0.0; self.hitstop = 0; self.roulette = None; self.tier3_t = -9.0
        self.tg = 0.0; self.hz_off = 0.0; self.roots = []; self.barrels = {}
        self._bgs = {}; self.set_arena('cienaga')

    def set_arena(self, aid):
        if getattr(self, 'arena', None) != aid:
            self.roots = []; self.barrels = {}
        self.arena = aid
        obs, hz = arena_rects(aid)
        OBS_PX[:] = obs; HZ_PX[:] = hz
        if aid not in self._bgs:
            self._bgs[aid] = build_arena_bg(aid)
        self.bg = self._bgs[aid]

    def ev(self, kind, *a):
        self.events.append((self.tg, kind) + a)

    def once(self, key):
        if key in self.fired:
            return False
        self.fired.add(key); return True

    def part(self, kind, x, y, vx=0.0, vy=0.0, life=0.5, size=4.0, col=GOLD, g=0.0, drag=0.0, rot=0.0, vr=0.0, sp='w', **kw):
        p = dict(k=kind, x=x, y=y, vx=vx, vy=vy, life=life, max=life, size=size, col=col, g=g, drag=drag, rot=rot, vr=vr, sp=sp)
        p.update(kw); self.parts.append(p)

    def sparks(self, x, y, n=7, col=GOLD, spd=260, sp='w', size=5):
        for _ in range(n):
            a = self.rng.uniform(0, 2 * math.pi); v = spd * self.rng.uniform(0.35, 1.0)
            self.part('spark', x, y, math.cos(a) * v, math.sin(a) * v, life=0.45, size=size * self.rng.uniform(0.7, 1.3), col=col, drag=5, sp=sp)

    def puff(self, x, y, n=9, col=PURPLE, size=11):
        for _ in range(n):
            a = self.rng.uniform(0, 2 * math.pi); v = self.rng.uniform(40, 110)
            self.part('puff', x, y, math.cos(a) * v, math.sin(a) * v - 25, life=0.55, size=size * self.rng.uniform(0.8, 1.3), col=col, drag=3)

    def text(self, x, y, s, col=GOLD_HI, size=26, life=0.75, rainbow=False, rise=40):
        self.texts.append(dict(x=x, y=y, s=s, col=col, born=self.t, size=size, life=life, rainbow=rainbow, rise=rise))

    # ---------------------------------------------------------- simulación
    def update(self, t):
        self.t = t
        if self.hitstop > 0:
            self.hitstop -= 1; dt = 0.0
        else:
            dt = DT * self.ts
        self.st += dt; st = self.st
        for d in self.d:
            if not d.visible:
                continue
            ox, oy = d.x, d.y
            if d.path:
                d.x, d.y = d.path(st)
            if dt > 0:
                d.vx = lerp(d.vx, (d.x - ox) / dt, 0.5); d.vy = lerp(d.vy, (d.y - oy) / dt, 0.5)
            d.walk += math.hypot(d.x - ox, d.y - oy)
            if abs(d.vx) > 15:
                d.face = 1 if d.vx > 0 else -1
            if st < d.dash_until:
                d.trail.append((d.x, d.y, t))
            d.trail = [p for p in d.trail if t - p[2] < 0.22]
            best, bd = None, 1e9
            for c in self.coins:
                if c.alive and st >= c.born:
                    dd = (c.x - d.x) ** 2 + (c.y - d.y) ** 2
                    if dd < bd:
                        bd, best = dd, c
            tx, ty = (0.0, 0.25)
            if best and bd < 420 ** 2:
                L = math.sqrt(bd) + 1e-6; tx, ty = (best.x - d.x) / L, (best.y - d.y) / L
            d.look = (lerp(d.look[0], tx, 0.25), lerp(d.look[1], ty, 0.25))
        for c in self.coins:
            if c.alive and not c.landed and c.flight > 0 and st >= c.land_t():
                c.landed = True
                if c.src is None:
                    self.ev('land', c.x / AW)
                for _ in range(3):
                    a = self.rng.uniform(math.pi, 2 * math.pi)
                    self.part('dust', c.x, c.y + 8, math.cos(a) * 40, math.sin(a) * 15, life=0.35, size=4, col=hexc('#9A92A8'), drag=4)
        for d in self.d:
            if not (d.visible and d.collect) or st < d.sheep_until or st < d.frozen_until:
                continue
            for c in self.coins:
                if not c.alive or st < c.land_t():
                    continue
                if c.block_pid == d.pid and st < c.block_until:
                    continue
                if (c.x - d.x) ** 2 + (c.y - d.y) ** 2 < 28 ** 2:
                    self.collect(d, c)
        for p in self.parts:
            pdt = dt if p['sp'] == 'w' else DT
            p['life'] -= pdt; p['vy'] += p['g'] * pdt
            f = max(0.0, 1 - p['drag'] * pdt); p['vx'] *= f; p['vy'] *= f
            p['x'] += p['vx'] * pdt; p['y'] += p['vy'] * pdt; p['rot'] += p['vr'] * pdt
        self.parts = [p for p in self.parts if p['life'] > 0]
        self.texts = [x for x in self.texts if t - x['born'] < x['life']]
        if self.crown_on:
            vis = [d for d in self.d if d.visible]
            if vis:
                ld = max(vis, key=lambda d: d.score)
                cur = self.d[self.leader] if self.leader >= 0 else None
                if ld.score > 0 and (cur is None or (ld.pid != cur.pid and ld.score > cur.score)):
                    self.leader = ld.pid; ld.crown_t = st; self.ev('crown')
        self.shake *= 0.85

    def collect(self, d, c):
        st = self.st
        c.alive = False
        d.combo = d.combo + 1 if st - d.last_pick <= 1.5 else 1
        d.last_pick = st; d.max_combo = max(d.max_combo, d.combo)
        tier = 0
        if self.multi:
            tier = 3 if d.combo >= 20 else 2 if d.combo >= 10 else 1 if d.combo >= 5 else 0
        val = (tier + 1) * (2 if self.frenzy else 1) * (2 if st < d.ring_until else 1)
        d.score += val; d.pop_t = self.t
        if c.stolen_from >= 0 and c.stolen_from != d.pid:
            d.stolen += 1
        self.ev('coin', d.pid, d.combo)
        col = GOLD if st < d.ring_until else TIER_COL[tier] or GOLD_HI
        self.text(c.x, c.y - 12, f"+{val}", col=col, size=24 + 4 * tier, rainbow=(tier == 3))
        if self.multi and d.combo in (5, 10, 20):
            self.ev('tier', d.pid, tier)
            if d.pid == 0 and tier < 3:
                self.text(d.x, d.y - 62, ["", "¡Combo!", "¡Vudú!"][tier], col=TIER_COL[tier], size=32, life=1.0, rise=30)
            if d.pid == 0 and tier == 3:
                self.tier3_t = self.t
        self.sparks(c.x, c.y, 7)


# ---------------------------------------------------------------- dibujo del mundo
def draw_parts(ctx, parts, sp):
    for p in parts:
        if p['sp'] != sp:
            continue
        u = p['life'] / p['max']; k = p['k']
        if k == 'spark':
            s = p['size'] * (0.4 + 0.6 * u)
            star_path(ctx, p['x'], p['y'], s, 4, 0.35, 0); ctx.set_source_rgba(*wa(p['col'], min(1, u * 1.6))); ctx.fill()
        elif k == 'dust':
            ctx.arc(p['x'], p['y'], p['size'] * (1.6 - u * 0.6), 0, 2 * math.pi); ctx.set_source_rgba(*wa(p['col'], 0.4 * u)); ctx.fill()
        elif k == 'puff':
            ctx.arc(p['x'], p['y'], p['size'] * (1 + (1 - u) * 1.2), 0, 2 * math.pi); ctx.set_source_rgba(*wa(p['col'], 0.65 * u)); ctx.fill()
        elif k == 'ring':
            v = e_out_cubic(1 - u); r = lerp(p['r0'], p['r1'], v)
            ctx.arc(p['x'], p['y'], r, 0, 2 * math.pi); ctx.set_line_width(p['size'] * u + 1)
            ctx.set_source_rgba(*wa(p['col'], u)); ctx.stroke()
        elif k == 'confetti':
            ctx.save(); ctx.translate(p['x'], p['y']); ctx.rotate(p['rot'])
            ctx.rectangle(-p['size'] / 2, -p['size'] * 0.3, p['size'], p['size'] * 0.6)
            ctx.set_source_rgba(*wa(p['col'], min(1, u * 3))); ctx.fill(); ctx.restore()
        elif k == 'shard':
            ctx.save(); ctx.translate(p['x'], p['y']); ctx.rotate(p['rot'])
            ctx.move_to(0, -p['size']); ctx.line_to(p['size'] * 0.4, 0); ctx.line_to(-p['size'] * 0.4, 0); ctx.close_path()
            ctx.set_source_rgba(*wa(FROST, min(1, u * 2))); ctx.fill(); ctx.restore()
        elif k == 'coinfx':
            draw_coin(ctx, p['x'], p['y'], p['rot'], 0, r=p['size'], alpha=min(1, u * 2))


def draw_combo_badge(ctx, w, d, t):
    st = w.st
    if d.combo < 2 or st - d.last_pick > 1.5 or not d.visible:
        return
    tier = 3 if d.combo >= 20 else 2 if d.combo >= 10 else 1 if d.combo >= 5 else 0
    x, y = d.x + d.r * 1.55, d.y - d.r * 1.75
    rem = 1 - (st - d.last_pick) / 1.5
    pop = 1 + 0.35 * max(0.0, 1 - (t - d.pop_t) / 0.15)
    ctx.arc(x, y, 19, 0, 2 * math.pi); ctx.set_source_rgba(*wa(PANEL, 0.88)); ctx.fill()
    ctx.new_path(); ctx.arc(x, y, 19, -math.pi / 2, -math.pi / 2 + 2 * math.pi * rem)
    col = TIER_COL[tier] or GOLD
    ctx.set_line_width(4); ctx.set_source_rgba(*col); ctx.stroke()
    draw_text(ctx, f"x{tier + 1}", x, y, 19, fill=col, ow=2.5, sc=pop, grad=rainbow_grad(t) if tier == 3 else None)
    draw_text(ctx, f"{d.combo}", x + 30, y + 1, 15, fam=FB, bold=True, fill=WHITE, ow=2.5, align='l')


def draw_roulette(ctx, w, t):
    R = w.roulette
    if not R:
        return
    st = w.st; d = w.d[R['pid']]
    if st < R['t0'] or st > R['hide']:
        return
    u = prog(st, R['t0'], R['t0'] + R['dur'])
    bx, by = d.x, d.y - d.r * 3.45
    pop = e_out_back(prog(st, R['t0'], R['t0'] + 0.15))
    ctx.save(); ctx.translate(bx, by); ctx.scale(pop, pop)
    done = u >= 1
    if done:
        g = cairo.RadialGradient(0, 0, 5, 0, 0, 52)
        g.add_color_stop_rgba(0, *wa(GOLD, 0.7)); g.add_color_stop_rgba(1, *wa(GOLD, 0))
        ctx.set_source(g); ctx.arc(0, 0, 52, 0, 2 * math.pi); ctx.fill()
    rrect(ctx, -25, -25, 50, 50, 11); fill_stroke(ctx, PANEL, GOLD if done else PANEL_LN, 6)
    ctx.save(); rrect(ctx, -22, -22, 44, 44, 9); ctx.clip()
    p = R['n'] * e_out_cubic(u); idx = int(p); fr = p - idx
    draw_icon(ctx, ITEMS[idx % 7], 0, fr * 44, 17)
    draw_icon(ctx, ITEMS[(idx + 1) % 7], 0, fr * 44 - 44, 17)
    ctx.restore()
    ctx.move_to(-8, 24); ctx.line_to(8, 24); ctx.line_to(0, 33); ctx.close_path(); fill_stroke(ctx, PANEL, GOLD if done else PANEL_LN, 4)
    ctx.restore()


def render_world(ctx, w, cam, t, fi):
    st = w.st
    ctx.set_source_rgba(*BG); ctx.paint()
    ctx.save()
    rng = random.Random(fi)
    sx = rng.uniform(-w.shake, w.shake) if w.shake > 0.5 else 0
    sy = rng.uniform(-w.shake, w.shake) if w.shake > 0.5 else 0
    ctx.translate(cam.ax + sx, cam.ay + sy); ctx.scale(cam.z, cam.z); ctx.translate(-cam.cx, -cam.cy)
    ctx.save(); ctx.translate(-PAD, -PAD); ctx.scale(1 / BGS, 1 / BGS)
    ctx.set_source_surface(w.bg, 0, 0); ctx.get_source().set_filter(cairo.FILTER_GOOD); ctx.paint(); ctx.restore()
    draw_lights(ctx, w.arena, t)
    draw_arena_hz(ctx, w, t, 'ground')
    for ch in w.chests:
        if st >= ch['born']:
            sc = e_out_back(prog(st, ch['born'], ch['born'] + 0.3))
            ou = prog(st, ch.get('open', 1e9), ch.get('open', 1e9) + 0.25)
            al = 1 - prog(st, ch.get('fade', 1e9), ch.get('fade', 1e9) + 0.3)
            draw_chest(ctx, ch['x'], ch['y'], t, ou, sc, al)
    items = []
    for c in w.coins:
        if c.alive and st >= c.born:
            x, y, h = c.pos(st); items.append((y, 0, c, (x, y, h)))
    for d in w.d:
        if d.visible:
            items.append((d.y, 1, d, None))
    items.sort(key=lambda it: (it[0], it[1]))
    for (_, kind, obj, extra) in items:
        if kind == 0:
            x, y, h = extra; draw_coin(ctx, x, y, t, obj.phase, height=h)
        else:
            d = obj
            for (tx_, ty_, tt_) in d.trail:
                a = 0.45 * (1 - (t - tt_) / 0.22)
                ellipse(ctx, tx_, ty_, d.r * 0.85, d.r * 0.95); ctx.set_source_rgba(*wa(d.col, a)); ctx.fill()
            crown = (w.crown_on and w.leader == d.pid) or w.force_crown == d.pid
            draw_hero(ctx, d, t, st, crown=crown, crown_drop=prog(st, d.crown_t, d.crown_t + 0.45))
    draw_arena_hz(ctx, w, t, 'top')
    for pr in w.projs:
        if pr['kind'] == 'pin' and pr['t0'] <= st <= pr['t1']:
            u = prog(st, pr['t0'], pr['t1'])
            x, y = lerp(pr['x0'], pr['x1'], u), lerp(pr['y0'], pr['y1'], u)
            ang = math.atan2(pr['y1'] - pr['y0'], pr['x1'] - pr['x0'])
            draw_pin_big(ctx, x, y, 46, ang + math.pi, head=8)
        if pr['kind'] == 'cloud' and pr['t0'] <= st <= pr['t1']:
            u = e_in_out(prog(st, pr['t0'], pr['t1']))
            x = lerp(pr['x0'], pr['x1'], u); y = lerp(pr['y0'], pr['y1'], u) - math.sin(math.pi * u) * 60
            ctx.new_path()
            for k in range(5):
                a = k * 2 * math.pi / 5 + t * 4
                ctx.new_sub_path(); ctx.arc(x + math.cos(a) * 12, y + math.sin(a) * 8, 13, 0, 2 * math.pi)
            ctx.set_source_rgba(*OUTL); ctx.set_line_width(7); ctx.stroke_preserve(); ctx.set_source_rgba(*PURPLE); ctx.fill()
            draw_icon(ctx, 'sheep', x, y, 11)
    draw_parts(ctx, w.parts, 'w')
    for tx in w.texts:
        age = t - tx['born']
        y = tx['y'] - tx['rise'] * e_out_cubic(min(1, age / 0.6))
        sc = lerp(1.6, 1.0, e_out_back(min(1, age / 0.18)))
        a = 1 - prog(age, tx['life'] - 0.25, tx['life'])
        draw_text(ctx, tx['s'], tx['x'], y, tx['size'], fill=tx['col'], ow=4, sc=sc, alpha=a,
                  grad=rainbow_grad(t) if tx['rainbow'] else None)
    draw_combo_badge(ctx, w, w.d[0], t)
    draw_roulette(ctx, w, t)
    ctx.restore()
    fog_layer(ctx, t)


_FOG = [(random.Random(s).uniform(-200, W + 200), random.Random(s + 50).uniform(0, H), random.Random(s + 99).uniform(220, 420),
         random.Random(s + 7).uniform(-18, 18), s % 2) for s in range(16)]


def fog_layer(ctx, t, a=1.0):
    for (x, y, rad, v, kind) in _FOG:
        xx = (x + v * t) % (W + 600) - 300
        col = hexc('#1E3A2A') if kind == 0 else hexc('#2A1440')
        g = cairo.RadialGradient(xx, y, 0, xx, y, rad)
        g.add_color_stop_rgba(0, *wa(col, 0.28 * a)); g.add_color_stop_rgba(1, *wa(col, 0))
        ctx.set_source(g); ctx.arc(xx, y, rad, 0, 2 * math.pi); ctx.fill()


# ---------------------------------------------------------------- HUD
CHIP_X = [56, 414, 1146, 1504]; CHIP_W = 360; CHIP_H = 88; CHIP_Y = 24


_PORT = {}


def portrait(pid):
    """Retrato circular del personaje para las fichas del HUD (60x60, se dibuja una vez)."""
    if pid not in _PORT:
        s = cairo.ImageSurface(cairo.FORMAT_ARGB32, 60, 60); c = cairo.Context(s)
        c.arc(30, 30, 28, 0, 2 * math.pi); c.clip()
        g = cairo.RadialGradient(30, 24, 4, 30, 30, 34)
        g.add_color_stop_rgba(0, *shade(PL[pid]['col'], -0.35)); g.add_color_stop_rgba(1, *shade(PL[pid]['col'], -0.7))
        c.set_source(g); c.paint()
        d = Doll(pid); d.r = 27; d.x, d.y = 30, 30 + 0.42 * 27 + 3; d.marker = False; d.look = (0.0, 0.25); d.blink_off = 1.0
        draw_hero(c, d, 0.0, 0.0)
        _PORT[pid] = s
    return _PORT[pid]


def fmt_time(s):
    s = max(0, int(math.ceil(s - 1e-6)))
    return f"{s // 60}:{s % 60:02d}"


def draw_hud(ctx, w, t, secs, slide=1.0, frenzy=False, item=None, item_flash=0.0):
    oy = -170 * (1 - e_out_cubic(slide))
    for i, d in enumerate(w.d):
        x = CHIP_X[i]; y = CHIP_Y + oy
        pop = max(0.0, 1 - (t - d.pop_t) / 0.22)
        ctx.save(); ctx.translate(x + CHIP_W / 2, y + CHIP_H / 2); ctx.scale(1 + 0.08 * pop, 1 + 0.08 * pop)
        ctx.translate(-CHIP_W / 2, -CHIP_H / 2)
        rrect(ctx, 0, 0, CHIP_W, CHIP_H, 26); fill_stroke(ctx, wa(PANEL, 0.94), PANEL_LN, 6)
        rrect(ctx, 8, 8, CHIP_W - 16, CHIP_H - 16, 19); ctx.set_dash([10, 8]); ctx.set_line_width(2)
        ctx.set_source_rgba(*wa(STITCH, 0.9)); ctx.stroke(); ctx.set_dash([])
        ctx.arc(48, CHIP_H / 2, 31, 0, 2 * math.pi); ctx.set_source_rgba(*OUTL); ctx.fill()
        ctx.set_source_surface(portrait(d.pid), 48 - 30, CHIP_H / 2 - 30); ctx.paint()
        ctx.arc(48, CHIP_H / 2, 30, 0, 2 * math.pi); ctx.set_source_rgba(*d.col); ctx.set_line_width(4); ctx.stroke()
        if (w.crown_on and w.leader == d.pid):
            draw_crown(ctx, 48, 10, 34)
        draw_text(ctx, d.name, 90, CHIP_H / 2 - 16, 24, fam=FB, bold=True, fill=DIM, align='l')
        sub = "TÚ · J1" if d.pid == 0 else f"J{d.pid + 1}"
        draw_text(ctx, sub, 90, CHIP_H / 2 + 16, 20, fam=FB, bold=True, fill=d.col if d.pid == 0 else wa(DIM, 0.7), align='l')
        draw_text(ctx, str(d.score), CHIP_W - 26, CHIP_H / 2 + 2, 56, fill=GOLD if pop > 0 else WHITE, ow=4, align='r')
        ctx.restore()
    ps = 1 + (0.06 * math.sin(t * 12) if frenzy else 0)
    draw_text(ctx, fmt_time(secs), W / 2, 70 + oy, 80, fill=GOLD if frenzy else WHITE, ow=7, sc=ps)
    if True:
        sx, sy = 118, 958
        ctx.arc(sx, sy, 66, 0, 2 * math.pi); fill_stroke(ctx, wa(PANEL, 0.94), GOLD if item else PANEL_LN, 10)
        if item:
            draw_icon(ctx, item, sx, sy, 34)
        if item_flash > 0:
            ctx.arc(sx, sy, 66 + 30 * (1 - item_flash), 0, 2 * math.pi); ctx.set_line_width(8 * item_flash)
            ctx.set_source_rgba(*wa(GOLD, item_flash)); ctx.stroke()
        rrect(ctx, sx + 34, sy + 32, 44, 40, 10); fill_stroke(ctx, WHITE, OUTL, 5)
        draw_text(ctx, "E", sx + 56, sy + 52, 28, fill=OUTL)


def watermark(ctx):
    draw_text(ctx, "CONCEPTO", W / 2, H - 22, 20, fam=FB, bold=True, fill=wa(DIM, 0.5))
