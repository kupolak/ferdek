import sys

def r(path, old, new):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

ch7 = '/Users/kupolak/Desktop/praca_inzynierska_tex/ch7_testy.tex'
r(ch7, r'Indeks LIX & +0,7333 & 0,0158 & Silna korelacja dodatnia (istotna statystycznie) \\', 
       r'Indeks LIX & +0,7333 & 0,0158 & Silna korelacja dodatnia (istotna statystycznie) \\' + '\n' +
       r'Indeks RIX & +0,7333 & 0,0158 & Silna korelacja dodatnia (istotna statystycznie) \\')
