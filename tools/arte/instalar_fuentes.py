#!/usr/bin/env python3
"""Instala en ~/.fonts las fuentes de assets/fonts en TTF, para que Cairo las encuentre al generar el arte.
Solo es para el PC donde se genera el arte: el juego usa directamente los .woff2."""
import os, glob, subprocess
from fontTools.ttLib import TTFont   # pip install fonttools brotli

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', '..', 'assets', 'fonts')
DST = os.path.expanduser('~/.fonts'); os.makedirs(DST, exist_ok=True)
for f in sorted(glob.glob(os.path.join(SRC, '*.woff2'))):
    font = TTFont(f); font.flavor = None
    out = os.path.join(DST, os.path.basename(f)[:-6] + '.ttf'); font.save(out); print('ok', out)
subprocess.run(['fc-cache', '-f'], check=False)
