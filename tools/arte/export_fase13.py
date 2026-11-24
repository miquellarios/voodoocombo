#!/usr/bin/env python3
"""Fase 13: efectos de hechizos (tira de sprites) y referencia de cómo se ve cada hechizo al lanzarlo.
Uso: python3 export_fase13.py [carpeta_salida]"""
import cairo, json, math, os, random, sys
from gfx import *

OUT = sys.argv[1] if len(sys.argv) > 1 else 'out/godot_f13'
UI = os.path.join(OUT, 'assets', 'ui'); REF = os.path.join(OUT, 'referencias')
for d in (UI, REF):
    os.makedirs(d, exist_ok=True)

DARK = hexc('#0B0710'); BONEW = hexc('#EFE7DA'); EMBER = hexc('#FF6A2B')
FROSTC = hexc('#7FE7FF'); SOUL = hexc('#B06BFF'); GOLDC = hexc('#FFD23F')
F = 192                      # tamaño de cada frame (2x: en Godot se dibuja a 96 px)
ORDER = ['oveja_a', 'oveja_b', 'hielo', 'capa', 'iman', 'botas', 'anillo', 'alfiler', 'lanzar', 'escarcha']
CHARS = '../../assets/characters'


def glow_circle(c, x, y, r, col, a=0.5, steps=10):
    for k in range(steps, 0, -1):
        c.arc(x, y, r * (1 + k * 0.06), 0, 2 * math.pi)
        c.set_source_rgba(col[0], col[1], col[2], a * 0.08); c.fill()


def fx_sheep(c, x, y, t):
    draw_sheep(c, x, y + 8, 46, t, EMBER)


def fx_ice(c, x, y):
    draw_ice(c, x, y + 6, 52, 0)


def fx_cloak(c, x, y):
    glow_circle(c, x, y, 70, FROSTC, 0.7)
    c.arc(x, y, 70, 0, 2 * math.pi)
    g = cairo.RadialGradient(x - 20, y - 25, 5, x, y, 72)
    g.add_color_stop_rgba(0, 1, 1, 1, 0.35); g.add_color_stop_rgba(0.7, *wa(FROSTC, 0.10)); g.add_color_stop_rgba(1, *wa(FROSTC, 0.45))
    c.set_source(g); c.fill_preserve(); c.set_source_rgba(*wa(FROSTC, 0.9)); c.set_line_width(3); c.stroke()
    c.arc(x - 18, y - 30, 22, math.pi * 1.1, math.pi * 1.6); c.set_source_rgba(1, 1, 1, 0.8); c.set_line_width(5); c.stroke()
    for k in range(6):                                   # costuras de la capa en el borde
        a = k * math.pi / 3 + 0.3
        c.move_to(x + math.cos(a) * 64, y + math.sin(a) * 64); c.line_to(x + math.cos(a) * 76, y + math.sin(a) * 76)
        c.set_source_rgba(*wa(BONEW, 0.8)); c.set_line_width(3); c.stroke()


def fx_magnet(c, x, y):
    for r, a in ((84, 0.55), (62, 0.75), (40, 0.9)):
        c.arc(x, y, r, 0, 2 * math.pi); c.set_source_rgba(*wa(GOLDC, a * 0.6)); c.set_line_width(3)
        c.set_dash([10, 8]); c.stroke(); c.set_dash([])
    for k in range(6):
        a = k * math.pi / 3 + 0.4
        x0, y0 = x + math.cos(a) * 86, y + math.sin(a) * 86
        x1, y1 = x + math.cos(a) * 54, y + math.sin(a) * 54
        c.move_to(x0, y0); c.line_to(x1, y1); c.set_source_rgba(*wa(GOLDC, 0.9)); c.set_line_width(4); c.stroke()
        c.move_to(x1, y1); c.line_to(x1 + math.cos(a + 2.6) * 10, y1 + math.sin(a + 2.6) * 10)
        c.move_to(x1, y1); c.line_to(x1 + math.cos(a - 2.6) * 10, y1 + math.sin(a - 2.6) * 10); c.stroke()


def fx_boots(c, x, y):
    for k, (dy, ln) in enumerate(((-34, 70), (-10, 90), (14, 80), (36, 60))):
        g = cairo.LinearGradient(x - 90, 0, x + 10, 0)
        g.add_color_stop_rgba(0, *wa(hexc('#63E6A8'), 0)); g.add_color_stop_rgba(1, *wa(hexc('#63E6A8'), 0.95))
        c.move_to(x + 10 - ln, y + dy); c.line_to(x + 10, y + dy); c.set_source(g); c.set_line_width(6)
        c.set_line_cap(cairo.LINE_CAP_ROUND); c.stroke()


def fx_ring(c, x, y):
    glow_circle(c, x, y, 60, GOLDC, 0.8)
    for k in range(8):
        a = k * math.pi / 4
        star_path(c, x + math.cos(a) * 70, y + math.sin(a) * 70, 9, n=4, inner=0.35, rot=0)
        fill_stroke(c, GOLDC, DARK, 2)
    draw_text(c, "+1", x, y - 70, 34, fam="Oswald", fill=GOLDC, ow=6, oc=DARK)


def fx_pin(c, x, y):
    for k in range(5):                                    # estela
        c.arc(x - 30 - k * 14, y, 6 - k, 0, 2 * math.pi); c.set_source_rgba(*wa(EMBER, 0.7 - k * 0.12)); c.fill()
    draw_pin_big(c, x + 30, y, 90, math.pi, head=16)


def fx_cast(c, x, y):
    glow_circle(c, x, y, 70, EMBER, 0.7)
    for r, w in ((78, 4), (60, 2)):
        c.arc(x, y, r, 0, 2 * math.pi); c.set_source_rgba(*wa(EMBER, 0.9)); c.set_line_width(w); c.stroke()
    for k in range(8):                                    # runas
        a = k * math.pi / 4
        px, py = x + math.cos(a) * 69, y + math.sin(a) * 69
        c.save(); c.translate(px, py); c.rotate(a + math.pi / 2)
        c.move_to(-5, -6); c.line_to(0, 6); c.line_to(5, -6); c.set_source_rgba(*wa(BONEW, 0.95)); c.set_line_width(2.5); c.stroke()
        c.restore()


def fx_frost_wave(c, x, y):
    c.arc(x, y, 86, 0, 2 * math.pi)
    g = cairo.RadialGradient(x, y, 40, x, y, 88)
    g.add_color_stop_rgba(0, *wa(FROSTC, 0)); g.add_color_stop_rgba(0.85, *wa(FROSTC, 0.35)); g.add_color_stop_rgba(1, *wa(FROSTC, 0.9))
    c.set_source(g); c.fill()
    for k in range(12):
        a = k * math.pi / 6
        c.save(); c.translate(x + math.cos(a) * 84, y + math.sin(a) * 84); c.rotate(a)
        c.move_to(0, -7); c.line_to(16, 0); c.line_to(0, 7); c.close_path(); fill_stroke(c, FROSTC, DARK, 2)
        c.restore()


DRAW = {
    'oveja_a': lambda c, x, y: fx_sheep(c, x, y, 0.0), 'oveja_b': lambda c, x, y: fx_sheep(c, x, y, 0.17),
    'hielo': fx_ice, 'capa': fx_cloak, 'iman': fx_magnet, 'botas': fx_boots, 'anillo': fx_ring,
    'alfiler': fx_pin, 'lanzar': fx_cast, 'escarcha': fx_frost_wave,
}


def sheet():
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, F * len(ORDER), F); c = cairo.Context(s)
    for i, k in enumerate(ORDER):
        c.save(); c.rectangle(i * F, 0, F, F); c.clip(); DRAW[k](c, i * F + F / 2, F / 2); c.restore()
    s.write_to_png(os.path.join(UI, 'efectos_hechizos.png'))
    meta = {"frame_w": F, "frame_h": F, "scale": 0.5, "order": ORDER,
            "note": "Centro del frame = centro del muñeco (su posición - 40 px en y). Dibujar a escala 0,5."}
    json.dump(meta, open(os.path.join(UI, 'efectos_hechizos.json'), 'w'), ensure_ascii=False, indent=1)


def char_frame(name, color='coral', row=0, col=0):
    img = cairo.ImageSurface.create_from_png(f'{CHARS}/{name}_{color}.png')
    sub = cairo.ImageSurface(cairo.FORMAT_ARGB32, 224, 256); cc = cairo.Context(sub)
    cc.set_source_surface(img, -col * 224, -row * 256); cc.paint()
    return sub


def put_char(c, sub, x, y, sc=0.75, alpha=1.0, tint=None):
    c.save(); c.translate(x - 112 * sc, y - 168 * sc); c.scale(sc, sc); c.set_source_surface(sub, 0, 0); c.paint_with_alpha(alpha)
    c.restore()


def put_fx(c, key, x, y, sc=1.0):
    c.save(); c.translate(x, y); c.scale(sc, sc); DRAW[key](c, 0, 0); c.restore()


def reference():
    Wr, Hr = 1920, 1080
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, Wr, Hr); c = cairo.Context(s)
    c.set_source_rgba(*hexc('#120B1A')); c.paint()
    draw_text(c, "HECHIZOS: QUE SE VEA QUE LOS LANZAS", Wr / 2, 70, 46, fam="Cinzel", fill=BONEW, ow=0, align='c', bold=True)
    draw_text(c, "Al pulsar E: círculo de runas (0,25 s) + icono que sale del muñeco + efecto propio. Sin texto encima.",
              Wr / 2, 122, 24, fam="Oswald", fill=hexc('#B8A9D1'), ow=0, align='c')
    cells = [
        ('Imán de Mithril', 'Aura con flechas hacia dentro; los doblones vuelan en espiral.', 'iman', 'mago'),
        ('Botas de Montaraz', 'Estela verde y copias fantasma detrás del muñeco.', 'botas', 'gnomo'),
        ('Capa Élfica', 'Burbuja cian; al bloquear se rompe en cristales.', 'capa', 'nigro'),
        ('Alfiler Vudú', 'Un alfiler vuela de verdad hacia donde miras.', 'alfiler', 'trol'),
        ('Nova de Escarcha', 'Onda de hielo que crece; los rivales quedan en un bloque.', 'escarcha', 'mago'),
        ('Maldición Ovina', 'Rayo hacia el líder y ¡puf!: se convierte en oveja.', 'oveja_a', 'gnomo'),
        ('Anillo de Poder', 'Aura dorada con destellos; cada doblón vale +1.', 'anillo', 'nigro'),
        ('Al lanzar (todos)', 'Círculo de runas en brasa bajo los pies.', 'lanzar', 'trol'),
    ]
    cw, ch = 440, 430
    for i, (name, desc, fx, who) in enumerate(cells):
        col, row = i % 4, i // 4
        x0, y0 = 40 + col * (cw + 20), 170 + row * (ch + 20)
        rrect(c, x0, y0, cw, ch, 18); c.set_source_rgba(*hexc('#1E1430')); c.fill_preserve()
        c.set_source_rgba(*hexc('#3A2A52')); c.set_line_width(2); c.stroke()
        cx, cy = x0 + cw / 2, y0 + 175
        ellipse(c, cx, cy + 62, 70, 18); c.set_source_rgba(0, 0, 0, 0.35); c.fill()
        sub = char_frame(who, ['coral', 'azul', 'lima', 'hueso'][i % 4])
        if fx in ('lanzar',):
            put_fx(c, 'lanzar', cx, cy + 50, 1.0); put_char(c, sub, cx, cy + 40)
        elif fx == 'oveja_a':
            put_char(c, sub, cx - 90, cy + 40, 0.5, 0.35)
            c.move_to(cx - 60, cy - 30); c.curve_to(cx - 20, cy - 90, cx + 20, cy - 70, cx + 40, cy - 20)
            c.set_source_rgba(*wa(SOUL, 0.9)); c.set_line_width(5); c.set_dash([8, 6]); c.stroke(); c.set_dash([])
            for k in range(10):
                random.seed(k); a = random.uniform(0, 6.28); r = random.uniform(30, 70)
                c.arc(cx + 50 + math.cos(a) * r, cy + 10 + math.sin(a) * r * 0.6, random.uniform(6, 14), 0, 6.28)
                c.set_source_rgba(1, 1, 1, 0.5); c.fill()
            put_fx(c, 'oveja_a', cx + 50, cy + 10, 1.1)
        elif fx == 'escarcha':
            put_fx(c, 'escarcha', cx, cy + 15, 1.3)
            put_char(c, sub, cx - 60, cy + 40, 0.6)
            put_char(c, char_frame('trol', 'azul'), cx + 80, cy + 40, 0.55); put_fx(c, 'hielo', cx + 80, cy + 10, 0.8)
        elif fx == 'alfiler':
            put_char(c, sub, cx - 110, cy + 40, 0.6); put_fx(c, 'alfiler', cx + 40, cy - 10, 1.0)
            put_char(c, char_frame('gnomo', 'lima', 3, 0), cx + 150, cy + 40, 0.5)
            draw_text(c, "-3", cx + 150, cy - 70, 34, fam="Oswald", fill=hexc('#FF3B3B'), ow=7, oc=DARK)
        elif fx == 'botas':
            for k in (3, 2, 1):
                put_char(c, sub, cx - k * 38, cy + 40, 0.7, 0.12 * (4 - k))
            put_fx(c, 'botas', cx - 30, cy + 10, 1.0); put_char(c, sub, cx, cy + 40, 0.7)
        elif fx == 'iman':
            put_fx(c, 'iman', cx, cy + 5, 1.25); put_char(c, sub, cx, cy + 40, 0.7)
            for k in range(5):
                a = k * 1.25 + 0.5; r = 112 - k * 10
                draw_coin(c, cx + math.cos(a) * r, cy + math.sin(a) * r * 0.7, 0, k, r=11)
        elif fx == 'anillo':
            put_fx(c, fx, cx, cy + 5, 1.2); put_char(c, sub, cx, cy + 40, 0.7)
        else:
            put_char(c, sub, cx, cy + 40, 0.7); put_fx(c, fx, cx, cy + 5, 1.2)
        draw_text(c, name.upper(), cx, y0 + ch - 92, 26, fam="Cinzel", fill=EMBER if i < 7 else BONEW, ow=0, bold=True)
        # descripción partida en 2 líneas
        words = desc.split(); l1 = []; l2 = []
        for w in words:
            (l1 if len(' '.join(l1 + [w])) < 40 and not l2 else l2).append(w)
        draw_text(c, ' '.join(l1), cx, y0 + ch - 52, 21, fam="Oswald", fill=BONEW, ow=0)
        draw_text(c, ' '.join(l2), cx, y0 + ch - 24, 21, fam="Oswald", fill=BONEW, ow=0)
    s.write_to_png(os.path.join(REF, 'hechizos_efectos_referencia.png'))


if __name__ == '__main__':
    sheet(); reference(); print('ok', OUT)


def reference_settings():
    Wr, Hr = 1920, 1080
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, Wr, Hr); c = cairo.Context(s)
    c.set_source_rgba(*hexc('#120B1A')); c.paint()
    draw_text(c, "AJUSTES", Wr / 2, 90, 64, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    tabs = ["PARTIDA", "PANTALLA", "SONIDO", "ONLINE"]
    for i, t in enumerate(tabs):
        x = Wr / 2 + (i - 1.5) * 260
        draw_text(c, t, x, 175, 26, fam="Cinzel", fill=EMBER if i == 0 else hexc('#8C7FA6'), ow=0, bold=True)
        if i == 0:
            c.move_to(x - 70, 200); c.line_to(x + 70, 200); c.set_source_rgba(*EMBER); c.set_line_width(2); c.stroke()
    rows = [("Escala de la interfaz", "100 %", 'arrows', False), ("Reducir movimiento", "NO", 'arrows', False),
            ("Reducir destellos", "SÍ", 'arrows', True), ("Vibración del mando", "SÍ", 'arrows', False),
            ("Idioma", "ESPAÑOL", 'arrows', False)]
    y = 290
    for i, (name, val, kind, focus) in enumerate(rows):
        x0, x1 = 420, 1500
        rrect(c, x0, y - 42, x1 - x0, 84, 14)
        c.set_source_rgba(*(hexc('#2A1C3E') if focus else hexc('#1B1228'))); c.fill_preserve()
        c.set_source_rgba(*(EMBER if focus else hexc('#33264A'))); c.set_line_width(2 if focus else 1.5); c.stroke()
        if focus:
            c.arc(x0 + 26, y, 5, 0, 6.28); c.set_source_rgba(*EMBER); c.fill()
        draw_text(c, name, x0 + 50, y, 32, fam="Oswald", fill=BONEW, ow=0, align='l')
        cxv = x1 - 220
        for sgn in (-1, 1):
            ax = cxv + sgn * 150
            c.move_to(ax - sgn * 10, y - 16); c.line_to(ax + sgn * 10, y); c.line_to(ax - sgn * 10, y + 16); c.close_path()
            c.set_source_rgba(*(EMBER if focus else BONEW)); c.fill()
        draw_text(c, val, cxv, y, 32, fam="Oswald", fill=EMBER if focus else BONEW, ow=0, bold=True)
        if name.startswith("Escala"):
            for k in range(6):
                c.arc(cxv - 50 + k * 20, y + 30, 4, 0, 6.28); c.set_source_rgba(*(EMBER if k == 2 else hexc('#5C4A78'))); c.fill()
        y += 110
    draw_text(c, "Izquierda / derecha o clic en las flechas: cambia el valor  ·  Arriba / abajo: cambia de fila  ·  Esc: volver (se guarda solo)",
              Wr / 2, 900, 24, fam="Oswald", fill=hexc('#B8A9D1'), ow=0)
    draw_text(c, "VOLVER", Wr / 2, 980, 32, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    s.write_to_png(os.path.join(REF, 'ajustes_referencia.png'))


if __name__ == '__main__':
    reference_settings()
