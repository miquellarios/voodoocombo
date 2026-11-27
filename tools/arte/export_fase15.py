#!/usr/bin/env python3
"""Fase 15: referencia de la pantalla JUGAR (online primero) y del lobby con INVITAR.
Uso: python3 export_fase15.py  ->  out/godot_f15/referencias/"""
import cairo, os
from gfx import *

OUT = 'out/godot_f15/referencias'
os.makedirs(OUT, exist_ok=True)
DARK = hexc('#0B0710'); BONEW = hexc('#EFE7DA'); EMBER = hexc('#FF6A2B'); MUTED = hexc('#B8A9D1')
PANEL = hexc('#1E1430'); PANEL2 = hexc('#2A1C3E'); LINE = hexc('#3A2A52'); OK = hexc('#63E6A8')


def boton(c, x, y, w, h, txt, lleno=True, size=30):
    rrect(c, x, y, w, h, h / 2)
    if lleno:
        c.set_source_rgba(*EMBER); c.fill()
        draw_text(c, txt, x + w / 2, y + h / 2, size, fam="Oswald", fill=DARK, ow=0, bold=True)
    else:
        c.set_source_rgba(*PANEL2); c.fill_preserve(); c.set_source_rgba(*LINE); c.set_line_width(2); c.stroke()
        draw_text(c, txt, x + w / 2, y + h / 2, size, fam="Oswald", fill=BONEW, ow=0, bold=True)


def jugar():
    W, H = 1920, 1080
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(s)
    c.set_source_rgba(*hexc('#120B1A')); c.paint()
    draw_text(c, "JUGAR", W / 2, 80, 64, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    c.arc(W / 2 - 150, 140, 8, 0, 6.28); c.set_source_rgba(*OK); c.fill()
    draw_text(c, "Servidor conectado · 32 ms", W / 2 + 10, 140, 24, fam="Oswald", fill=MUTED, ow=0)
    # tarjeta principal
    x, y, w, h = 160, 200, 780, 560
    rrect(c, x, y, w, h, 24); c.set_source_rgba(*PANEL); c.fill_preserve(); c.set_source_rgba(*EMBER); c.set_line_width(3); c.stroke()
    draw_text(c, "JUGAR CON AMIGOS", x + w / 2, y + 80, 44, fam="Cinzel", fill=EMBER, ow=0, bold=True)
    draw_text(c, "Crea una sala y manda el enlace por WhatsApp.", x + w / 2, y + 150, 26, fam="Oswald", fill=BONEW, ow=0)
    draw_text(c, "Tu amigo lo abre y aparece en tu sala.", x + w / 2, y + 190, 26, fam="Oswald", fill=BONEW, ow=0)
    draw_text(c, "Sin instalar nada · desde cualquier casa", x + w / 2, y + 250, 22, fam="Oswald", fill=MUTED, ow=0)
    boton(c, x + 140, y + 330, w - 280, 96, "CREAR SALA", size=36)
    # partida rápida y unirse
    x2 = 980
    rrect(c, x2, y, w, 260, 24); c.set_source_rgba(*PANEL); c.fill_preserve(); c.set_source_rgba(*LINE); c.set_line_width(2); c.stroke()
    draw_text(c, "PARTIDA RÁPIDA", x2 + w / 2, y + 60, 36, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    draw_text(c, "Te junta con quien esté buscando partida", x2 + w / 2, y + 112, 24, fam="Oswald", fill=MUTED, ow=0)
    boton(c, x2 + 190, y + 150, w - 380, 76, "BUSCAR PARTIDA", lleno=False)
    yy = y + 300
    rrect(c, x2, yy, w, 260, 24); c.set_source_rgba(*PANEL); c.fill_preserve(); c.set_source_rgba(*LINE); c.set_line_width(2); c.stroke()
    draw_text(c, "¿TE HAN PASADO UN ENLACE O CÓDIGO?", x2 + w / 2, yy + 60, 30, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    rrect(c, x2 + 60, yy + 110, w - 330, 80, 14); c.set_source_rgba(*PANEL2); c.fill_preserve(); c.set_source_rgba(*LINE); c.stroke()
    draw_text(c, "KWET7", x2 + 95, yy + 150, 38, fam="Oswald", fill=BONEW, ow=0, align='l', bold=True)
    boton(c, x2 + w - 250, yy + 112, 190, 76, "ENTRAR", size=30)
    draw_text(c, "Pega el enlace o escribe las 5 letras", x2 + w / 2, yy + 225, 20, fam="Oswald", fill=MUTED, ow=0)
    draw_text(c, "CONTRA BOTS", W / 2 - 420, 900, 30, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    draw_text(c, "SIN INTERNET (EN CLASE)", W / 2, 900, 30, fam="Cinzel", fill=MUTED, ow=0, bold=True)
    draw_text(c, "MENÚ", W / 2 + 420, 900, 30, fam="Cinzel", fill=BONEW, ow=0, bold=True)
    draw_text(c, "Sin internet: Partida en mi red · Alojar en mi PC (fase 14)", W / 2, 960, 22, fam="Oswald", fill=MUTED, ow=0)
    s.write_to_png(os.path.join(OUT, 'jugar_online_referencia.png'))


def invitar():
    W, H = 1920, 1080
    s = cairo.ImageSurface(cairo.FORMAT_ARGB32, W, H); c = cairo.Context(s)
    c.set_source_rgba(*hexc('#120B1A')); c.paint()
    draw_text(c, "LOBBY (arriba a la izquierda)", W / 2, 70, 40, fam="Cinzel", fill=MUTED, ow=0, bold=True)
    x, y, w, h = 160, 140, 820, 330
    rrect(c, x, y, w, h, 22); c.set_source_rgba(*PANEL); c.fill_preserve(); c.set_source_rgba(*EMBER); c.set_line_width(3); c.stroke()
    draw_text(c, "SALA", x + 60, y + 60, 26, fam="Oswald", fill=MUTED, ow=0, align='l')
    draw_text(c, "KWET7", x + 60, y + 130, 84, fam="Oswald", fill=BONEW, ow=0, align='l', bold=True)
    boton(c, x + 400, y + 70, 360, 96, "INVITAR", size=40)
    draw_text(c, "Enlace copiado", x + 580, y + 200, 26, fam="Oswald", fill=OK, ow=0)
    draw_text(c, "https://voodoocombo.duckdns.org/?sala=KWET7", x + w / 2, y + 270, 26, fam="Oswald", fill=MUTED, ow=0)
    # mensaje de WhatsApp
    x2, y2 = 1060, 140
    rrect(c, x2, y2, 700, 330, 22); c.set_source_rgba(*hexc('#0F2A22')); c.fill()
    draw_text(c, "Lo que se copia (para WhatsApp):", x2 + 40, y2 + 50, 24, fam="Oswald", fill=MUTED, ow=0, align='l')
    rrect(c, x2 + 40, y2 + 90, 620, 190, 16); c.set_source_rgba(*hexc('#1F4D3A')); c.fill()
    draw_text(c, "¡Te reto a VoodooCombo!", x2 + 70, y2 + 135, 28, fam="Oswald", fill=BONEW, ow=0, align='l', bold=True)
    draw_text(c, "Entra aquí y apareces en mi sala:", x2 + 70, y2 + 185, 24, fam="Oswald", fill=BONEW, ow=0, align='l')
    draw_text(c, "https://voodoocombo.duckdns.org/?sala=KWET7", x2 + 70, y2 + 230, 22, fam="Oswald", fill=hexc('#7FE7FF'), ow=0, align='l')
    # flujo del amigo
    draw_text(c, "EL AMIGO ABRE EL ENLACE", W / 2, 560, 40, fam="Cinzel", fill=MUTED, ow=0, bold=True)
    pasos = [("1", "Se abre el juego", "en el navegador"), ("2", "¿Cómo te llamas?", "solo la primera vez"),
             ("3", "Entra solo a la sala", "KWET7, sin escribir nada"), ("4", "¡LISTO!", "y a jugar")]
    for i, (n, t1, t2) in enumerate(pasos):
        xx = 160 + i * 410
        rrect(c, xx, 620, 380, 220, 20); c.set_source_rgba(*PANEL); c.fill()
        c.arc(xx + 60, 680, 30, 0, 6.28); c.set_source_rgba(*EMBER); c.fill()
        draw_text(c, n, xx + 60, 680, 34, fam="Oswald", fill=DARK, ow=0, bold=True)
        draw_text(c, t1, xx + 190, 750, 30, fam="Oswald", fill=BONEW, ow=0, bold=True)
        draw_text(c, t2, xx + 190, 795, 22, fam="Oswald", fill=MUTED, ow=0)
        if i < 3:
            draw_text(c, "›", xx + 395, 730, 60, fam="Oswald", fill=EMBER, ow=0, bold=True)
    draw_text(c, "Si el enlace se abre con el .exe instalado, también vale pegarlo en UNIRSE.", W / 2, 920, 24, fam="Oswald", fill=MUTED, ow=0)
    s.write_to_png(os.path.join(OUT, 'invitar_referencia.png'))


if __name__ == '__main__':
    jugar(); invitar(); print('ok')
