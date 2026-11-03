#!/usr/bin/env python3
"""Controlla che ogni carattere usato nei testi del gioco esista nei font (niente quadratini).

Uso: python3 tools/controlla_glifi.py
Legge le stringhe di scripts/*.gd e dei file della pagina del telefono e le confronta con
Bangers (titoli) e Barlow Condensed (testi). Esce con errore se manca qualcosa.
"""
import glob, os, re, sys
from fontTools.ttLib import TTFont

R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
testi = []
for f in glob.glob(R + '/scripts/*.gd'):
    src = open(f, encoding='utf-8').read()
    src = '\n'.join(l for l in src.splitlines() if not l.strip().startswith('#'))
    testi += re.findall(r'"((?:[^"\\]|\\.)*)"', src)
for f in [R + '/web/js/telefono.js', R + '/web/shell.html', R + '/web/telefono.html']:
    src = open(f, encoding='utf-8').read()
    src = re.sub(r'//[^\n]*', '', src)
    testi += re.findall(r"'((?:[^'\\]|\\.)*)'", src)
    testi += re.findall(r'`([^`]*)`', src, re.S)
    testi += re.findall(r'>([^<>{}]+)<', src)
caratteri = set(''.join(testi)) - set('\n\t\r')
errori = 0
for font in ['Bangers-Regular.ttf', 'BarlowCondensed-Bold.ttf', 'BarlowCondensed-Medium.ttf']:
    cmap = TTFont(R + '/assets/font/' + font).getBestCmap()
    manca = sorted(ch for ch in caratteri if ord(ch) not in cmap and ord(ch) > 31)
    if manca:
        print(f'{font}: mancano {"".join(manca)!r} ' + ' '.join(f'U+{ord(c):04X}' for c in manca))
        errori += 1
    else:
        print(f'{font}: tutti i {len(caratteri)} caratteri presenti')
sys.exit(1 if errori else 0)
