import sys

def replace_in_file(path, old, new):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

p5 = '/Users/kupolak/Desktop/praca_inzynierska_tex/ch5_metryki.tex'
replace_in_file(p5, 'rys1_graf_raygora.jpg', 'rys1_graf_raygora.png')
replace_in_file(p5, 'rys2_graf_frya.jpg', 'rys2_graf_frya.png')

p7 = '/Users/kupolak/Desktop/praca_inzynierska_tex/ch7_testy.tex'
replace_in_file(p7, 'rys7_raygor_punkty.jpg', 'rys7_raygor_punkty.png')
replace_in_file(p7, 'rys8_fry_punkty.jpg', 'rys8_fry_punkty.png')

print("Updated .tex files.")
