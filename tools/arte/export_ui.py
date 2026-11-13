#!/usr/bin/env python3
"""Exporta para Godot las texturas de objetos (doblón, cofre, hechizos) y de interfaz (logo, fondo del menú, botones,
paneles). Uso: python3 export_ui.py [carpeta_salida]   (por defecto out/godot_ui; copiar su assets/ a la raíz del proyecto)"""
import cairo, json, math, os, random, sys
from gfx import *
from heroes import draw_hero
from world import Doll, fog_layer

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_ui'
ITEMS_DIR = os.path.join(OUT, 'assets', 'items'); UI_DIR = os.path.join(OUT, 'assets', 'ui')
for d in (ITEMS_DIR, UI_DIR):
    os.makedirs(d, exist_ok=True)
S = 2   # escala de exportación: en Godot los sprites van con scale = 0.5


def strip(path, fw, fh, n, draw, scale=S):
    """Tira horizontal de n frames de fw×fh unidades del mundo. draw(ctx, i) dibuja con el centro del frame en (0, 0)."""
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, int(fw * n * scale), int(fh * scale))
    for i in range(n):
        ctx = cairo.Context(surf); ctx.scale(scale, scale)
        ctx.rectangle(i * fw, 0, fw, fh); ctx.clip(); ctx.translate(i * fw + fw / 2, fh / 2)
        draw(ctx, i)
    surf.write_to_png(path)
    return {"file": os.path.basename(path), "frame_w": int(fw * scale), "frame_h": int(fh * scale), "frames": n, "scale": 1 / scale}


# ================================================================ objetos
def export_items():
    meta = {}
    n = 8   # el doblón gira: el frame i equivale a cos(2πi/n)
    def coin(ctx, i):
        ph = 2 * math.pi * i / n
        c = math.cos(ph); s = abs(c) * 0.82 + 0.18; r = 11.0
        ellipse(ctx, 0, 0, r * s, r); fill_stroke(ctx, GOLD_DK, OUTL, r * 0.3)
        ellipse(ctx, 0, 0, r * s * 0.76, r * 0.76); ctx.set_source_rgba(*GOLD); ctx.fill()
        ellipse(ctx, -r * s * 0.22, -r * 0.28, r * s * 0.22, r * 0.28); ctx.set_source_rgba(*wa(GOLD_HI, 0.85)); ctx.fill()
        if i == 0:
            star_path(ctx, r * 0.55, -r * 0.7, r * 0.5, n=4, inner=0.25, rot=0); ctx.set_source_rgba(1, 1, 1, 0.95); ctx.fill()
    meta['doblon'] = strip(os.path.join(ITEMS_DIR, 'doblon.png'), 32, 32, n, coin)
    meta['doblon'].update(fps=10, loop=True, note="Centro del frame = centro del doblón. Para que bote, mover el sprite en y y dejar la sombra en el suelo.")

    def coin_shadow(ctx, i):
        ellipse(ctx, 0, 0, 9.5, 3.4); ctx.set_source_rgba(0, 0, 0, 0.4); ctx.fill()
    meta['doblon_sombra'] = strip(os.path.join(ITEMS_DIR, 'doblon_sombra.png'), 32, 12, 1, coin_shadow)
    meta['doblon_sombra'].update(note="Va en el suelo, 11 px por debajo del centro del doblón.")

    def chest(ctx, i):
        lid = [0.0, 0.3, 0.7, 1.15, 1.6, 1.9][i]          # giro de la tapa (rad)
        beam = [0.0, 0.0, 0.25, 0.55, 0.85, 1.0][i]        # haz de luz al abrirse
        chest_frame(ctx, 0, 16, lid, beam)
    meta['cofre'] = strip(os.path.join(ITEMS_DIR, 'cofre.png'), 112, 128, 6, chest)
    meta['cofre'].update(fps=20, loop=False, frames_info="0 cerrado · 1-4 abriéndose · 5 abierto",
                         note="El cofre se apoya en (0, +16) respecto al centro del frame; su posición de juego es el centro del frame. "
                              "Cerrado: frame 0 con un bote suave (sin(t·3,2)·2,5 px) y el brillo latiendo con modulate.")

    order = ITEMS
    def icon(ctx, i):
        ctx.arc(0, 0, 29, 0, 2 * math.pi); ctx.set_source_rgba(*wa(PANEL, 0.0)); ctx.fill()
        draw_icon(ctx, order[i], 0, 0, 26)
    meta['hechizos'] = strip(os.path.join(ITEMS_DIR, 'hechizos.png'), 64, 64, len(order), icon)
    meta['hechizos'].update(order=order, note="Un icono por frame, en el orden de ITEMS (magnet, boots, cloak, pin, frost, sheep, ring). "
                                              "Para la ranura del HUD y la ruleta.")
    return meta


def chest_frame(ctx, x, y, lid, beam):
    """Igual que gfx.draw_chest, pero con el giro de la tapa lineal para que los frames de apertura se vean distintos."""
    ctx.save(); ctx.translate(x, y)
    g = cairo.RadialGradient(0, 0, 4, 0, 0, 46)
    g.add_color_stop_rgba(0, *wa(GOLD, 0.45)); g.add_color_stop_rgba(1, *wa(GOLD, 0))
    ctx.set_source(g); ctx.arc(0, 0, 46, 0, 2 * math.pi); ctx.fill()
    ellipse(ctx, 0, 22, 20, 6); ctx.set_source_rgba(0, 0, 0, 0.35); ctx.fill()
    if beam > 0:
        g2 = cairo.LinearGradient(0, -6, 0, -70)
        g2.add_color_stop_rgba(0, *wa(GOLD_HI, 0.8 * beam)); g2.add_color_stop_rgba(1, *wa(GOLD, 0))
        ctx.move_to(-16, -6); ctx.line_to(16, -6); ctx.line_to(30, -70); ctx.line_to(-30, -70); ctx.close_path(); ctx.set_source(g2); ctx.fill()
    rrect(ctx, -20, -6, 40, 25, 5); fill_stroke(ctx, hexc('#8E5A33'), OUTL, 6)
    if lid > 0.2:   # interior oscuro con el oro dentro
        rrect(ctx, -17, -8, 34, 6, 2); ctx.set_source_rgba(*hexc('#3A2312')); ctx.fill()
        for k in range(5):
            ctx.arc(-12 + k * 6, -7 + (k % 2), 3.2, 0, 2 * math.pi); fill_stroke(ctx, GOLD, OUTL, 1.5)
    for bx in (-11, 11):
        ctx.rectangle(bx - 2.5, -6, 5, 25); ctx.set_source_rgba(*GOLD); ctx.fill()
    rrect(ctx, -5, 1, 10, 9, 2); fill_stroke(ctx, GOLD, OUTL, 3)
    ctx.save(); ctx.translate(-20, -6); ctx.rotate(-lid); ctx.translate(20, 6)
    rrect(ctx, -21, -20, 42, 15, 7); fill_stroke(ctx, hexc('#A8703F'), OUTL, 6)
    ctx.rectangle(-13.5, -19, 5, 13); ctx.rectangle(8.5, -19, 5, 13); ctx.set_source_rgba(*GOLD); ctx.fill()
    ctx.restore(); ctx.restore()


# ================================================================ interfaz
STITCH_P = 12   # periodo de la costura: 7 px de hilo y 5 de hueco


def stitch_edges(ctx, x0, y0, x1, y1, m, col, lw=2.6):
    """Costura discontinua alineada con los márgenes del 9-slice: el tramo central repite cada STITCH_P px."""
    ctx.set_source_rgba(*col); ctx.set_line_width(lw); ctx.set_line_cap(cairo.LINE_CAP_ROUND)
    def seg(ax, ay, bx, by):
        L = math.hypot(bx - ax, by - ay); k = 0.0
        while k + 7 <= L + 0.01:
            u0, u1 = k / L, (k + 7) / L
            ctx.move_to(lerp(ax, bx, u0), lerp(ay, by, u0)); ctx.line_to(lerp(ax, bx, u1), lerp(ay, by, u1)); k += STITCH_P
        ctx.stroke()
    seg(m + 2.5, y0, x1 - m + 2.5, y0); seg(m + 2.5, y1, x1 - m + 2.5, y1)
    seg(x0, m + 2.5, x0, y1 - m + 2.5); seg(x1, m + 2.5, x1, y1 - m + 2.5)


def nine(path, w, h, m, fill_a, fill_b, border, stitch, glow=None, dy=0.0, radius=20):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, w, h); ctx = cairo.Context(surf)
    if glow:
        for k in range(6, 0, -1):
            rrect(ctx, 6 - k, 6 - k + dy, w - 12 + 2 * k, h - 12 + 2 * k, radius + k); ctx.set_source_rgba(*wa(glow, 0.05)); ctx.fill()
    rrect(ctx, 6, 6 + dy, w - 12, h - 12, radius)
    g = cairo.LinearGradient(0, 6, 0, h - 6); g.add_color_stop_rgba(0, *fill_a); g.add_color_stop_rgba(1, *fill_b)
    ctx.set_source(g); ctx.fill_preserve(); ctx.set_source_rgba(*border); ctx.set_line_width(5); ctx.stroke()
    stitch_edges(ctx, 15, 15 + dy, w - 15, h - 15 + dy, m, stitch)
    surf.write_to_png(path)
    return {"file": os.path.basename(path), "size": [w, h], "margin": m,
            "godot": f"StyleBoxTexture: texture_margin_* = {m}, axis_stretch_horizontal/vertical = TILE_FIT, content_margin_* = {m - 4}"}


def export_ui():
    meta = {}
    W9, H9, M = 120, 84, 24     # tramos centrales de 72 y 36 px: 6 y 3 periodos de costura
    meta['boton'] = nine(os.path.join(UI_DIR, 'boton.png'), W9, H9, M, hexc('#2C1E44'), hexc('#1E1430'), PANEL_LN, wa(STITCH, 1))
    meta['boton_hover'] = nine(os.path.join(UI_DIR, 'boton_hover.png'), W9, H9, M, hexc('#3A2758'), hexc('#26183C'), GOLD,
                               wa(GOLD_DK, 1), glow=GOLD)
    meta['boton_pulsado'] = nine(os.path.join(UI_DIR, 'boton_pulsado.png'), W9, H9, M, hexc('#1A1128'), hexc('#140C20'), GOLD_DK,
                                 wa(GOLD_DK, 0.8), dy=2)
    meta['panel'] = nine(os.path.join(UI_DIR, 'panel.png'), W9, H9, M, wa(hexc('#241838'), 0.94), wa(hexc('#1E1430'), 0.94),
                         PANEL_LN, wa(STITCH, 0.9))

    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, 160, 160); ctx = cairo.Context(surf)
    ctx.arc(80, 80, 66, 0, 2 * math.pi); fill_stroke(ctx, wa(PANEL, 0.94), PANEL_LN, 10)
    ctx.arc(80, 80, 54, 0, 2 * math.pi); ctx.set_dash([8, 6]); ctx.set_line_width(2.5); ctx.set_source_rgba(*STITCH); ctx.stroke()
    surf.write_to_png(os.path.join(UI_DIR, 'ranura.png'))
    meta['ranura'] = {"file": "ranura.png", "size": [160, 160], "note": "Ranura del hechizo (HUD, abajo a la izquierda). El icono va centrado."}

    # logo con fondo transparente, recortado
    big = cairo.ImageSurface(cairo.FORMAT_ARGB32, 1400, 760); ctx = cairo.Context(big)
    draw_logo(ctx, 640, 400, 99, 0)
    data = big.get_data(); stride = big.get_stride(); x0, y0, x1, y1 = 1400, 760, 0, 0
    for y in range(0, 760, 2):
        row = bytes(data[y * stride:(y + 1) * stride])
        for x in range(0, 1400, 2):
            if row[x * 4 + 3] > 8:
                x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
    pad = 12; x0, y0, x1, y1 = max(0, x0 - pad), max(0, y0 - pad), min(1400, x1 + pad), min(760, y1 + pad)
    logo = cairo.ImageSurface(cairo.FORMAT_ARGB32, x1 - x0, y1 - y0); c2 = cairo.Context(logo)
    c2.set_source_surface(big, -x0, -y0); c2.paint(); logo.write_to_png(os.path.join(UI_DIR, 'logo.png'))
    meta['logo'] = {"file": "logo.png", "size": [x1 - x0, y1 - y0], "note": "Logo con transparencia. En el menú: ancho ~560 px (scale ≈ %.2f)." % (560 / (x1 - x0))}

    from heroes import KINDS, PCOL3
    cols = ['coral', 'azul', 'lima', 'hueso']
    for ki, kind in enumerate(KINDS):     # retratos redondos para el marcador: personaje × color
        for ci, cname in enumerate(cols):
            surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, 112, 112); c = cairo.Context(surf); c.scale(2, 2)
            c.arc(28, 28, 26, 0, 2 * math.pi); c.save(); c.clip()
            g = cairo.RadialGradient(28, 22, 4, 28, 28, 32)
            g.add_color_stop_rgba(0, *shade(PCOL3[ci], -0.35)); g.add_color_stop_rgba(1, *shade(PCOL3[ci], -0.7)); c.set_source(g); c.paint()
            d = Doll(ki); d.kind = kind; d.col = PCOL3[ci]; d.r = 19; d.x, d.y = 28, 31 + 0.42 * 19 + 3; d.marker = False
            d.look = (0.0, 0.25); d.blink_off = 1.0
            draw_hero(c, d, 0.0, 0.0); c.restore()
            c.arc(28, 28, 26, 0, 2 * math.pi); c.set_source_rgba(*PCOL3[ci]); c.set_line_width(3); c.stroke()
            surf.write_to_png(os.path.join(UI_DIR, f'retrato_{kind}_{cname}.png'))
    meta['retratos'] = {"file": "retrato_<personaje>_<color>.png", "size": [112, 112],
                        "note": "Cabeza en un círculo con borde del color del jugador, para las fichas del marcador. Dibujar a 56×56."}
    menu_background(os.path.join(UI_DIR, 'menu_fondo.png'))
    meta['menu_fondo'] = {"file": "menu_fondo.png", "size": [1920, 1080],
                          "note": "Fondo del menú principal. TextureRect a pantalla completa (stretch KEEP_ASPECT_COVERED). "
                                  "Deja libre la columna central (x 470-810 en 1280×720) para el logo y los botones."}
    return meta


def menu_background(path, t=0.6):
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); ctx = cairo.Context(surf)
    g = cairo.RadialGradient(W / 2, 470, 60, W / 2, 470, 1250)
    g.add_color_stop_rgba(0, *hexc('#3A1238')); g.add_color_stop_rgba(0.45, *hexc('#1A0C26')); g.add_color_stop_rgba(1, *hexc('#0B0710'))
    ctx.set_source(g); ctx.paint()
    rng = random.Random(7)
    for _ in range(26):   # doblones flotando, muy apagados
        draw_coin(ctx, rng.uniform(0, W), rng.uniform(40, 760), rng.uniform(0, 6), rng.uniform(0, 6), r=rng.uniform(10, 22),
                  alpha=rng.uniform(0.08, 0.2))
    for _ in range(90):
        ctx.arc(rng.uniform(0, W), rng.uniform(0, H), rng.uniform(1.2, 3.2), 0, 2 * math.pi)
        ctx.set_source_rgba(*wa(shade(PL[rng.randrange(4)]['col'], 0.35), rng.uniform(0.1, 0.3))); ctx.fill()
    GY = 790
    lg = cairo.LinearGradient(0, GY - 40, 0, H)
    lg.add_color_stop_rgba(0, *wa(hexc('#120A1C'), 0)); lg.add_color_stop_rgba(0.3, *hexc('#120A1C')); lg.add_color_stop_rgba(1, *hexc('#07040A'))
    ctx.rectangle(0, GY - 40, W, H); ctx.set_source(lg); ctx.fill()
    xs = (215, 470, 1440, 1700)
    for i, x in enumerate(xs):   # focos y peanas
        col = PL[i]['col']
        cone = cairo.LinearGradient(0, 0, 0, GY + 110)
        cone.add_color_stop_rgba(0, *wa(shade(col, 0.4), 0)); cone.add_color_stop_rgba(1, *wa(shade(col, 0.4), 0.2))
        ctx.move_to(x - 40, -10); ctx.line_to(x + 40, -10); ctx.line_to(x + 200, GY + 112); ctx.line_to(x - 200, GY + 112); ctx.close_path()
        ctx.set_source(cone); ctx.fill()
        rg = cairo.RadialGradient(x, GY + 108, 10, x, GY + 108, 220)
        rg.add_color_stop_rgba(0, *wa(col, 0.42)); rg.add_color_stop_rgba(1, *wa(col, 0))
        ctx.set_source(rg); ellipse(ctx, x, GY + 108, 220, 64); ctx.fill()
        ellipse(ctx, x, GY + 108, 156, 36); fill_stroke(ctx, hexc('#2A1E3C'), OUTL, 7)
        ellipse(ctx, x, GY + 102, 138, 27); ctx.set_dash([12, 9]); ctx.set_line_width(3); ctx.set_source_rgba(*STITCH); ctx.stroke(); ctx.set_dash([])
    for (cx, cy) in ((90, 930), (W - 90, 930), (W / 2 - 300, 1000), (W / 2 + 300, 1000)):   # velas
        gl = cairo.RadialGradient(cx, cy - 10, 2, cx, cy - 10, 110)
        gl.add_color_stop_rgba(0, 1, 0.75, 0.4, 0.4); gl.add_color_stop_rgba(1, 1, 0.5, 0.2, 0)
        ctx.set_source(gl); ctx.arc(cx, cy - 10, 110, 0, 2 * math.pi); ctx.fill()
        for (dx, h) in ((-9, 26), (5, 34), (15, 18)):
            rrect(ctx, cx + dx - 4.5, cy + 12 - h, 9, h, 2.5); fill_stroke(ctx, hexc('#E8DCC4'), OUTL, 3)
            ellipse(ctx, cx + dx, cy + 12 - h - 8, 3.6, 6.5); ctx.set_source_rgba(1, 0.85, 0.45, 0.95); ctx.fill()
    for i, x in enumerate(xs):
        d = Doll(i); d.r = 104; d.x, d.y = x, GY; d.look = (0.0, 0.3); d.marker = False; d.face = 1 if x < W / 2 else -1
        d.blink_off = 1.0 + i
        draw_hero(ctx, d, t, t)
    fog_layer(ctx, 3.0, a=1.3)
    vignette(ctx, 0.55)
    surf.write_to_png(path)


def reference_menu(path):
    """Cómo debería verse el menú montado (solo referencia para Codex; el menú real lo construye Godot)."""
    surf = cairo.ImageSurface.create_from_png(os.path.join(UI_DIR, 'menu_fondo.png')); ctx = cairo.Context(surf)
    lg = cairo.ImageSurface.create_from_png(os.path.join(UI_DIR, 'logo.png'))
    sc = 840 / lg.get_width(); ctx.save(); ctx.translate(W / 2 - 420, 70); ctx.scale(sc, sc); ctx.set_source_surface(lg, 0, 0); ctx.paint(); ctx.restore()
    labels = ["JUGAR", "MODO CLÁSICO", "PERSONAJES", "AJUSTES", "HISTORIAL", "SALIR"]
    for k, s in enumerate(labels):
        y = 470 + k * 92; x = W / 2 - 255; w, h = 510, 76
        hover = k == 0
        bt = cairo.ImageSurface.create_from_png(os.path.join(UI_DIR, 'boton_hover.png' if hover else 'boton.png'))
        draw_nine(ctx, bt, x, y, w, h, 24)
        draw_text(ctx, s, W / 2, y + h / 2 + 2, 40 if hover else 36, fam=FG, grad=oldgold_grad if hover else bone_grad, ow=4, oc=hexc('#0B0710'))
    draw_text(ctx, "WASD mover · Espacio dash · E hechizo · Esc atrás", W / 2, 1040, 26, fam=FB, bold=True, fill=wa(DIM, 0.85))
    draw_text(ctx, "Nivel 3 · 240 XP", 60, 1040, 26, fam=FB, bold=True, fill=wa(DIM, 0.85), align='l')
    surf.write_to_png(path)


def reference_hud(path):
    """Partida con el HUD tal como debería verse (referencia). Se dibuja a 1920×1080 con el motor del tráiler."""
    import world as WD
    w = WD.World(); w.set_arena('cripta'); w.crown_on = True; w.st = 5.0; w.t = 5.0
    rng = random.Random(3)
    for _ in range(40):
        x, y = rng.uniform(30, 1170), rng.uniform(30, 570)
        if WD.free_spot(x, y, 22):
            w.coins.append(WD.Coin(x, y, -9.0, rng=rng))
    w.chests.append(dict(x=480, y=300, born=-9.0))
    for d, (x, y), sc in zip(w.d, ((300, 470), (1000, 300), (700, 420), (150, 130)), (42, 17, 31, 9)):
        d.visible = True; d.place(x, y); d.r = 27.0; d.score = sc; d.spawn_t = -9.0
    w.leader = 0; w.d[0].combo = 7; w.d[0].last_pick = 4.6
    surf = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); ctx = cairo.Context(surf)
    WD.render_world(ctx, w, WD.Cam(600, 300, 1.42), 5.0, 0)
    vignette(ctx, 0.45)
    WD.draw_hud(ctx, w, 5.0, 63, item='frost')
    surf.write_to_png(path)


def draw_nine(ctx, img, x, y, w, h, m):
    iw, ih = img.get_width(), img.get_height()
    xs = [(0, m, x, m), (m, iw - 2 * m, x + m, w - 2 * m), (iw - m, m, x + w - m, m)]
    ys = [(0, m, y, m), (m, ih - 2 * m, y + m, h - 2 * m), (ih - m, m, y + h - m, m)]
    for (sx, sw, dx, dw) in xs:
        for (sy, sh, dy, dh) in ys:
            ctx.save(); ctx.rectangle(dx, dy, dw, dh); ctx.clip(); ctx.translate(dx, dy); ctx.scale(dw / sw, dh / sh)
            ctx.set_source_surface(img, -sx, -sy); ctx.get_source().set_filter(cairo.FILTER_GOOD); ctx.paint(); ctx.restore()


def main():
    meta = {"export_scale": S, "items": export_items()}
    with open(os.path.join(ITEMS_DIR, 'items.json'), 'w', encoding='utf-8') as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
    ui = {"ui": export_ui()}
    with open(os.path.join(UI_DIR, 'ui.json'), 'w', encoding='utf-8') as fh:
        json.dump(ui, fh, ensure_ascii=False, indent=2)
    os.makedirs(os.path.join(OUT, 'referencias'), exist_ok=True)
    reference_menu(os.path.join(OUT, 'referencias', 'menu_referencia.png'))
    reference_hud(os.path.join(OUT, 'referencias', 'hud_referencia.png'))
    print('ok', OUT)


if __name__ == '__main__':
    main()
