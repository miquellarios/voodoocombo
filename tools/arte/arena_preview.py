"""Vista previa de las 4 arenas con personajes, doblones y trampas en acción."""
import cairo, math, random, sys
from gfx import *
from arenas import *
from heroes import draw_hero, KINDS, PCOL3
from world import Doll, blocked as _unused

def blocked_a(aid, x, y, m):
    if x < m or y < m or x > AW - m or y > AH - m:
        return True
    for (ox, oy, ow, oh, _) in ARENAS[aid]['obstacles']:
        if px(ox) - m < x < px(ox + ow) + m and px(oy) - m < y < px(oy + oh) + m:
            return True
    return False

def render(aid, t, out, scale=1.45):
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); ctx = cairo.Context(s)
    ctx.set_source_rgba(*hexc('#0B0710')); ctx.paint()
    A = ARENAS[aid]
    g = cairo.RadialGradient(W / 2, 80, 40, W / 2, 200, 1100)
    g.add_color_stop_rgba(0, *wa(hexc(A['accent']), 0.22)); g.add_color_stop_rgba(1, *wa(hexc('#0B0710'), 0))
    ctx.set_source(g); ctx.paint()
    draw_text(ctx, A['name'].upper(), W / 2, 62, 64, fam=FG, grad=bone_grad, ow=6, oc=OUTL2, shadow=(0, 7, hexc('#5C1018')))
    ctx.save(); ctx.translate(W / 2 - AW * scale / 2, 120); ctx.scale(scale, scale)
    floor(ctx, aid)
    draw_hazards(ctx, aid, t, layer='ground')
    draw_obstacles(ctx, aid, t)
    rng = random.Random(len(aid))
    n = 0
    while n < 34:
        x, y = rng.uniform(30, AW - 30), rng.uniform(30, AH - 30)
        if blocked_a(aid, x, y, 22):
            continue
        draw_coin(ctx, x, y, t + n, n * 0.7, r=9.5); n += 1
    spots = {'cienaga': [(150, 150), (1010, 170), (230, 470), (980, 460)], 'cripta': [(140, 140), (1060, 170), (180, 480), (1000, 470)],
             'taller': [(150, 140), (1050, 150), (160, 470), (1030, 480)], 'biblioteca': [(170, 170), (1050, 190), (150, 450), (1010, 470)]}[aid]
    for i, (x, y) in enumerate(spots):
        d = Doll(i); d.kind = KINDS[i]; d.col = PCOL3[i]; d.r = 24; d.x, d.y = x, y; d.look = (0.4, 0.2)
        draw_hero(ctx, d, t, t, crown=(i == 0))
    draw_hazards(ctx, aid, t, layer='top')
    ctx.restore()
    chips = A['rules']
    x0 = 120; y0 = 1018
    names = {'lodo': 'LODO', 'raices': 'RAÍCES', 'pinchos': 'PINCHOS', 'fantasma': 'FANTASMA', 'cinta': 'CINTAS', 'vapor': 'VAPOR',
             'barril': 'BARRIL EXPLOSIVO', 'portal': 'PORTALES', 'rayo': 'RAYO ARCANO'}
    keys = list(chips.keys()); wcell = (W - 240) / len(keys)
    for i, k in enumerate(keys):
        cx = x0 + wcell * i + wcell / 2
        rrect(ctx, cx - wcell / 2 + 10, y0 - 32, wcell - 20, 64, 18); ctx.set_source_rgba(*wa(hexc('#1A1226'), 0.95)); ctx.fill_preserve()
        ctx.set_source_rgba(*wa(hexc(A['accent']), 0.7)); ctx.set_line_width(2.5); ctx.stroke()
        draw_text(ctx, names[k], cx, y0, 32, fam=FG, grad=bone_grad, ow=3, oc=OUTL2)
    vignette(ctx, 0.45)
    s.write_to_png(out)

if __name__ == '__main__':
    for aid, t in (('cienaga', 1.0), ('cripta', 2.3), ('taller', 3.65), ('biblioteca', 1.1)):
        render(aid, t, f'out/arena_{aid}.png')
    from PIL import Image
    sheet = Image.new('RGB', (1920, 1080))
    for i, aid in enumerate(('cienaga', 'cripta', 'taller', 'biblioteca')):
        im = Image.open(f'out/arena_{aid}.png').convert('RGB').resize((960, 540), Image.LANCZOS)
        sheet.paste(im, ((i % 2) * 960, (i // 2) * 540))
    sheet.save('out/arenas_preview.jpg', quality=88)
