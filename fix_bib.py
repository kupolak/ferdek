import sys

def r(path, old, new):
    with open(path, 'r', encoding='utf-8') as f:
        c = f.read()
    c = c.replace(old, new)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(c)

bib = '/Users/kupolak/Desktop/praca_inzynierska_tex/bibliografia.tex'
r(bib, r'\end{thebibliography}', r'\bibitem{bib58} Anderson, Jonathan (1983), „Lix and Rix: Variations on a little-known readability index”, Journal of Reading, 26 (6), s.~490–496, \url{https://www.jstor.org/stable/40031755}' + '\n\n' + r'\end{thebibliography}')
print("Bib fixed.")
